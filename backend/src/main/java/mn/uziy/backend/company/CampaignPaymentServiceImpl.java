package mn.uziy.backend.company;

import static mn.uziy.backend.company.CompanyMessages.NOT_PAYABLE_MESSAGE;
import static mn.uziy.backend.company.CompanyMessages.PAYMENTS_UNAVAILABLE_MESSAGE;

import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.UnavailableException;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignPaymentEntity;
import mn.uziy.backend.domain.CampaignPaymentRepository;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.PaymentStatus;
import mn.uziy.backend.payment.ChargeRequest;
import mn.uziy.backend.payment.ChargeResult;
import mn.uziy.backend.payment.PaymentGateway;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CampaignPaymentServiceImpl implements CampaignPaymentService {

    private final CampaignRepository campaigns;
    private final CampaignPaymentRepository payments;
    private final List<PaymentGateway> gateways;

    public CampaignPaymentServiceImpl(CampaignRepository campaigns,
                                      CampaignPaymentRepository payments,
                                      List<PaymentGateway> gateways) {
        this.campaigns = campaigns;
        this.payments = payments;
        this.gateways = gateways;
    }

    @Override
    @Transactional
    public PayCampaignResponse pay(long companyId, long campaignId) {
        CampaignEntity c = OwnedCampaigns.owned(campaigns, companyId, campaignId);
        if (c.getStatus() != CampaignStatus.AWAITING_PAYMENT) {
            throw new ConflictException(NOT_PAYABLE_MESSAGE);
        }
        PaymentGateway gateway = gateways.stream()
                .filter(PaymentGateway::isAvailable)
                .findFirst()
                .orElseThrow(() -> new UnavailableException(PAYMENTS_UNAVAILABLE_MESSAGE));

        OffsetDateTime paidAt = CompanyClock.now();
        if (campaigns.tryMarkPaid(campaignId, paidAt) == 0) {
            throw new ConflictException(NOT_PAYABLE_MESSAGE);
        }

        ChargeResult charge = gateway.charge(
                new ChargeRequest(campaignId, c.getCompanyId(), c.getTotalBudget(), paidAt));
        CampaignPaymentEntity entity = new CampaignPaymentEntity();
        entity.setCampaignId(campaignId);
        entity.setCompanyId(c.getCompanyId());
        entity.setAmount(c.getTotalBudget());
        entity.setProvider(gateway.getProvider());
        entity.setStatus(PaymentStatus.PAID);
        entity.setReference(charge.reference());
        entity.setCreatedAt(paidAt);
        entity.setPaidAt(paidAt);

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
        return new PayCampaignResponse(CampaignDto.of(c), PaymentDto.of(payment, c.getTitle()));
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
                .map(p -> PaymentDto.of(p, titles.getOrDefault(p.getCampaignId(), "")))
                .toList();
    }
}
