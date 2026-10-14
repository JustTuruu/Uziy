package mn.uziy.backend.insights;

import java.time.Clock;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Function;
import mn.uziy.backend.analytics.AgeBands;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.MongolianRegions;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.insights.InsightsDtos.AccessLogEntry;
import mn.uziy.backend.insights.InsightsDtos.Distribution;
import mn.uziy.backend.insights.InsightsDtos.Filter;
import mn.uziy.backend.insights.InsightsDtos.Overview;
import mn.uziy.backend.insights.InsightsDtos.QuestionSummary;
import mn.uziy.backend.insights.InsightsDtos.SegmentRow;
import mn.uziy.backend.insights.InsightsDtos.Segments;
import mn.uziy.backend.insights.InsightsRepository.Answer;
import mn.uziy.backend.insights.InsightsRepository.Person;
import mn.uziy.backend.insights.InsightsRepository.Question;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class InsightsServiceImpl implements InsightsService {

    /** How many access-log rows the admin page shows. */
    static final int ACCESS_LOG_LIMIT = 200;
    static final String GENDER_DIMENSION = "Хүйс";
    static final String AGE_DIMENSION = "Нас";

    private final InsightsRepository data;
    private final DataAccessLogRepository log;
    private final Clock clock;

    public InsightsServiceImpl(InsightsRepository data, DataAccessLogRepository log, Clock clock) {
        this.data = data;
        this.log = log;
        this.clock = clock;
    }

    @Override
    @Transactional
    public Overview overview(long adminId) {
        log.record(adminId, "VIEW_OVERVIEW", "");
        LocalDate today = LocalDate.now(clock);
        List<Person> people = data.consentingViewers();
        long viewers = data.viewers();
        long reportable = data.questionCounts().stream()
                .filter(q -> StatisticsPrivacyPolicy.reportable(q.respondents())).count();
        List<String> cities = new ArrayList<>(List.of(MongolianRegions.CAPITAL));
        cities.addAll(MongolianRegions.AIMAGS);
        return new Overview(
                StatisticsPrivacyPolicy.MIN_GROUP_SIZE,
                viewers,
                people.size(),
                StatisticsPrivacyPolicy.percent(people.size(), viewers),
                InsightsCalculator.groups(people, Person::gender,
                        List.of(InsightsCalculator.MALE, InsightsCalculator.FEMALE),
                        InsightsCalculator.GENDER_LABELS::get),
                InsightsCalculator.groups(people, p -> InsightsCalculator.ageBand(p, today), AgeBands.labels(),
                        Function.identity()),
                InsightsCalculator.groups(people, Person::city, cities, Function.identity()),
                reportable);
    }

    @Override
    @Transactional
    public List<QuestionSummary> questions(long adminId) {
        log.record(adminId, "VIEW_QUESTIONS", "");
        return data.questionCounts().stream()
                .map(q -> new QuestionSummary(q.id(), q.prompt(), q.type(), q.surveyTitle(), q.companyName(),
                        StatisticsPrivacyPolicy.roundedCount(q.respondents()),
                        StatisticsPrivacyPolicy.reportable(q.respondents())))
                .toList();
    }

    @Override
    @Transactional
    public Distribution distribution(long adminId, long questionId, Filter filter) {
        requireKnown(filter);
        Question q = statisticalQuestion(questionId);
        log.record(adminId, "VIEW_QUESTION", "question=" + questionId + " " + InsightsCalculator.describe(filter));
        LocalDate today = LocalDate.now(clock);
        List<Answer> all = data.answers(questionId);
        List<Answer> group = all.stream()
                .filter(a -> InsightsCalculator.matches(a.person(), filter, today))
                .toList();
        boolean show = StatisticsPrivacyPolicy.reportable(group.size(), all.size());
        return new Distribution(q.id(), q.prompt(), q.type(), filter, !show,
                show ? StatisticsPrivacyPolicy.roundedCount(group.size()) : null,
                show ? InsightsCalculator.shares(InsightsCalculator.options(q.optionsJson()), group) : List.of());
    }

    @Override
    @Transactional
    public Segments segments(long adminId, long questionId) {
        Question q = statisticalQuestion(questionId);
        log.record(adminId, "VIEW_SEGMENTS", "question=" + questionId);
        return buildSegments(q);
    }

    @Override
    @Transactional
    public String exportCsv(long adminId, long questionId) {
        Question q = statisticalQuestion(questionId);
        log.record(adminId, "EXPORT_CSV", "question=" + questionId);
        return SegmentsCsv.write(q.surveyTitle(), buildSegments(q));
    }

    @Override
    @Transactional
    public List<AccessLogEntry> accessLog(long adminId) {
        log.record(adminId, "VIEW_ACCESS_LOG", "");
        return log.recent(ACCESS_LOG_LIMIT);
    }

    private Segments buildSegments(Question q) {
        LocalDate today = LocalDate.now(clock);
        List<String> options = InsightsCalculator.options(q.optionsJson());
        List<Answer> answers = data.answers(q.id());
        List<SegmentRow> rows = new ArrayList<>();
        int all = answers.size();
        rows.add(row("Бүгд", "Бүх оролцогч", answers, all, options));
        for (String gender : List.of(InsightsCalculator.MALE, InsightsCalculator.FEMALE)) {
            rows.add(row(GENDER_DIMENSION, InsightsCalculator.GENDER_LABELS.get(gender),
                    answers.stream().filter(a -> gender.equals(a.person().gender())).toList(), all, options));
        }
        for (String band : AgeBands.labels()) {
            rows.add(row(AGE_DIMENSION, band,
                    answers.stream().filter(a -> band.equals(InsightsCalculator.ageBand(a.person(), today)))
                            .toList(), all, options));
        }
        return new Segments(q.id(), q.prompt(), options, rows);
    }

    private static SegmentRow row(String dimension, String label, List<Answer> group, int all,
                                  List<String> options) {
        boolean show = StatisticsPrivacyPolicy.reportable(group.size(), all);
        return new SegmentRow(dimension, label, !show,
                show ? StatisticsPrivacyPolicy.roundedCount(group.size()) : null,
                show ? InsightsCalculator.shares(options, group) : List.of());
    }

    private Question statisticalQuestion(long questionId) {
        Question q = data.question(questionId).orElseThrow(() -> new NotFoundException(QUESTION_NOT_FOUND));
        if (StatisticsPrivacyPolicy.TEXT_TYPE.equals(q.type())) {
            throw new BadRequestException(TEXT_NOT_ALLOWED);
        }
        return q;
    }

    private static void requireKnown(Filter f) {
        boolean genderOk = f.gender() == null || InsightsCalculator.GENDER_LABELS.containsKey(f.gender());
        boolean ageOk = f.ageBand() == null || AgeBands.labels().contains(f.ageBand());
        boolean cityOk = f.city() == null || MongolianRegions.isCity(f.city());
        if (!genderOk || !ageOk || !cityOk) {
            throw new BadRequestException(UNKNOWN_FILTER);
        }
    }
}
