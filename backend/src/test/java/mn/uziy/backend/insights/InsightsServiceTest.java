package mn.uziy.backend.insights;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.insights.InsightsDtos.Distribution;
import mn.uziy.backend.insights.InsightsDtos.Filter;
import mn.uziy.backend.insights.InsightsDtos.SegmentRow;
import mn.uziy.backend.insights.InsightsRepository.Answer;
import mn.uziy.backend.insights.InsightsRepository.Person;
import mn.uziy.backend.insights.InsightsRepository.Question;
import org.junit.jupiter.api.Test;

class InsightsServiceTest {

    private static final long ADMIN = 1L;
    private static final long Q = 12L;
    private static final LocalDate TODAY = LocalDate.of(2026, 10, 14);
    private static final Filter ANY = new Filter(null, null, null);

    private final InsightsRepository data = mock(InsightsRepository.class);
    private final DataAccessLogRepository log = mock(DataAccessLogRepository.class);
    private final InsightsServiceImpl service = new InsightsServiceImpl(data, log,
            Clock.fixed(Instant.parse("2026-10-14T04:00:00Z"), ZoneOffset.UTC));

    private void choiceQuestion() {
        when(data.question(Q)).thenReturn(Optional.of(
                new Question(Q, "Тийм үү?", "SINGLE_CHOICE", "[\"Тийм\",\"Үгүй\"]", "Судалгаа", "MobiCom")));
    }

    private static List<Answer> answers(int women, int men) {
        List<Answer> out = new ArrayList<>();
        for (int i = 0; i < women; i++) {
            out.add(new Answer("\"Тийм\"", new Person("FEMALE", TODAY.minusYears(30), "Ховд")));
        }
        for (int i = 0; i < men; i++) {
            out.add(new Answer("\"Үгүй\"", new Person("MALE", TODAY.minusYears(20), "Увс")));
        }
        return out;
    }

    @Test
    void aBigEnoughGroupGetsRoundedPeopleAndShares() {
        choiceQuestion();
        when(data.answers(Q)).thenReturn(answers(60, 63));

        Distribution d = service.distribution(ADMIN, Q, ANY);

        assertThat(d.suppressed()).isFalse();
        assertThat(d.people()).isEqualTo(120L);
        assertThat(d.shares()).extracting(InsightsDtos.OptionShare::percent).containsExactly(49, 51);
    }

    @Test
    void aSmallGroupShowsNothingButStillLeavesATrace() {
        choiceQuestion();
        when(data.answers(Q)).thenReturn(answers(30, 0));

        Distribution d = service.distribution(ADMIN, Q, ANY);

        assertThat(d.suppressed()).isTrue();
        assertThat(d.people()).isNull();
        assertThat(d.shares()).isEmpty();
        verify(log).record(eq(ADMIN), eq("VIEW_QUESTION"), anyString());
    }

    @Test
    void aFilterLeavingAFewPeopleOutsideIsHiddenToo() {
        choiceQuestion();
        when(data.answers(Q)).thenReturn(answers(60, 5));

        assertThat(service.distribution(ADMIN, Q, new Filter("FEMALE", null, null)).suppressed()).isTrue();
    }

    @Test
    void freeTextIsNeverAStatistic() {
        when(data.question(Q)).thenReturn(Optional.of(
                new Question(Q, "Санал?", "TEXT", "[]", "Судалгаа", "MobiCom")));

        assertThatThrownBy(() -> service.distribution(ADMIN, Q, ANY))
                .isInstanceOf(BadRequestException.class).hasMessage(InsightsService.TEXT_NOT_ALLOWED);
        assertThatThrownBy(() -> service.exportCsv(ADMIN, Q)).isInstanceOf(BadRequestException.class);
        verify(data, never()).answers(Q);
    }

    @Test
    void unknownFilterValuesAreRefused() {
        assertThatThrownBy(() -> service.distribution(ADMIN, Q, new Filter("OTHER", null, null)))
                .hasMessage(InsightsService.UNKNOWN_FILTER);
        assertThatThrownBy(() -> service.distribution(ADMIN, Q, new Filter(null, "20–29", null)))
                .hasMessage(InsightsService.UNKNOWN_FILTER);
        assertThatThrownBy(() -> service.distribution(ADMIN, Q, new Filter(null, null, "Дархан")))
                .hasMessage(InsightsService.UNKNOWN_FILTER);
    }

    @Test
    void anUnknownQuestionIs404() {
        when(data.question(Q)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.segments(ADMIN, Q)).isInstanceOf(NotFoundException.class);
    }

    @Test
    void segmentsHideSmallGroupsAndKeepTheOthers() {
        choiceQuestion();
        when(data.answers(Q)).thenReturn(answers(60, 60));

        List<SegmentRow> rows = service.segments(ADMIN, Q).rows();

        assertThat(rows.get(0).label()).isEqualTo("Бүх оролцогч");
        assertThat(rows.get(0).suppressed()).isFalse();
        assertThat(rows).filteredOn(r -> r.label().equals("Эмэгтэй")).first()
                .satisfies(r -> assertThat(r.shares().get(0).percent()).isEqualTo(100));
        // Nobody is 13–17 here: that row is empty, so hidden.
        assertThat(rows).filteredOn(r -> r.label().equals("13–17")).first()
                .satisfies(r -> assertThat(r.suppressed()).isTrue());
    }

    @Test
    void everyEntryPointIsRecorded() {
        choiceQuestion();
        when(data.answers(Q)).thenReturn(answers(60, 60));

        service.overview(ADMIN);
        service.questions(ADMIN);
        service.segments(ADMIN, Q);
        service.exportCsv(ADMIN, Q);
        service.accessLog(ADMIN);

        verify(log).record(ADMIN, "VIEW_OVERVIEW", "");
        verify(log).record(ADMIN, "VIEW_QUESTIONS", "");
        verify(log).record(ADMIN, "VIEW_SEGMENTS", "question=12");
        verify(log).record(ADMIN, "EXPORT_CSV", "question=12");
        verify(log).record(ADMIN, "VIEW_ACCESS_LOG", "");
    }
}
