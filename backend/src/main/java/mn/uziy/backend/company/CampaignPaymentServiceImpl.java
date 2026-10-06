package mn.uziy.backend.company;

import static mn.uziy.backend.company.CompanyMessages.NOT_PAYABLE_MESSAGE;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.CampaignActor;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignPaymentEntity;
import mn.uziy.backend.domain.CampaignPaymentRepository;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.payment.ChargeRequest;
import mn.uziy.backend.payment.ChargeResult;
import mn.uziy.backend.payment.PaymentGateway;
import mn.uziy.backend.payment.PaymentGatewaySelector;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Pattern: State — payability is {@code AWAITING_PAYMENT → PENDING} for the SYSTEM actor. */
@Service
public class CampaignPaymentServiceImpl implements CampaignPaymentService {

    private final CampaignRepository campaigns;
    private final CampaignPaymentRepository payments;
    private final PaymentGatewaySelector gateways;
    private final CampaignFactory factory;
    private final CampaignMapper campaignMapper;
    private final PaymentMapper paymentMapper;
    private final DomainEventPublisher events;
    private final Clock clock;

    public CampaignPaymentServiceImpl(CampaignRepository campaigns,
                                      CampaignPaymentRepository payments,
                                      PaymentGatewaySelector gateways,
                                      CampaignFactory factory,
                                      CampaignMapper campaignMapper,
                                      PaymentMapper paymentMapper,
                                      DomainEventPublisher events,
                                      Clock clock) {
        this.campaigns = campaigns;
        this.payments = payments;
        this.gateways = gateways;
        this.factory = factory;
        this.campaignMapper = campaignMapper;
        this.paymentMapper = paymentMapper;
        this.events = events;
        this.clock = clock;
    }

    @Override
    @Transactional
    public PayCampaignResponse pay(long companyId, long campaignId) {
        CampaignEntity c = OwnedCampaigns.owned(campaigns, companyId, campaignId);
        CampaignStatus from = c.getStatus();
        if (!from.canTransitionTo(CampaignStatus.PENDING, CampaignActor.SYSTEM)) {
            throw new ConflictException(NOT_PAYABLE_MESSAGE);
        }
        PaymentGateway gateway = gateways.select();

        OffsetDateTime paidAt = OffsetDateTime.now(clock).truncatedTo(ChronoUnit.MICROS);
        if (campaigns.tryMarkPaid(campaignId, paidAt) == 0) {
            throw new ConflictException(NOT_PAYABLE_MESSAGE);
        }

        ChargeResult charge = gateway.charge(
                new ChargeRequest(campaignId, c.getCompanyId(), c.getTotalBudget(), paidAt));
        CampaignPaymentEntity entity = factory.newPaidPayment(c, gateway.getProvider(), charge.reference(), paidAt);

        CampaignPaymentEntity payment;
        try {
            payment = payments.saveAndFlush(entity);
        } catch (DataIntegrityViolationException e) {
            // Another PAID row already exists — the whole tx rolls back.
            throw new ConflictException(NOT_PAYABLE_MESSAGE);
        }

        // `c` was detached by tryMarkPaid (clearAutomatically), so these
        // assignments only shape the response — they are not written back.
        c.setStatus(CampaignStatus.PENDING);
        c.setPaidAt(paidAt);
        c.setUpdatedAt(paidAt);
        events.publish(new CampaignPaid(campaignId, c.getCompanyId(), c.getTotalBudget(), payment.getReference()));
        events.publish(new CampaignStatusChanged(campaignId, from, CampaignStatus.PENDING, CampaignActor.SYSTEM));
        return new PayCampaignResponse(campaignMapper.toDto(c), paymentMapper.toDto(payment, c.getTitle()));
    }

    @Override
    public List<PaymentDto> list(long companyId) {
        List<CampaignPaymentEntity> list = payments.findAllByCompanyIdOrderByCreatedAtDescIdDesc(companyId);
        List<Long> ids = list.stream().map(CampaignPaymentEntity::getCampaignId).distinct().toList();
        Map<Long, String> titles = new HashMap<>();
        for (CampaignEntity c : campaigns.findAllById(ids)) {
            titles.put(c.getId(), c.getTitle());
        }
        return list.stream()
                .map(p -> paymentMapper.toDto(p, titles.getOrDefault(p.getCampaignId(), "")))
                .toList();
    }
}
