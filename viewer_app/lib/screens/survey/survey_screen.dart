import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/campaign.dart';
import '../../models/survey_question.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../services/viewer_service.dart';
import '../../widgets/ui.dart';
import 'survey_widgets.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({
    super.key,
    required this.campaignId,
    this.campaign,
  });
  final String campaignId;
  final Campaign? campaign;

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  List<SurveyQuestion>? _questions;
  String? _loadError;
  bool _retrying = false;

  final Map<int, dynamic> _answers = {}; // questionId -> answer

  // Free-text answers keep their controller so the typed text survives
  // navigating back and forth between questions.
  final Map<int, TextEditingController> _textControllers = {};
  int _index = 0;

  /// Direction of the last question change (drives the slide transition).
  bool _forward = true;
  bool _submitting = false;
  String? _submitError;

  int get _campaignId => int.tryParse(widget.campaignId) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final qs = await ViewerService.instance.questions(_campaignId);
      if (!mounted) return;
      setState(() {
        _questions = qs;
        _loadError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401 || e.statusCode == 403) {
        await AuthService.instance.logout();
        if (!mounted) return;
        context.go(Routes.login);
        return;
      }
      setState(() => _loadError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Асуулт ачаалж чадсангүй');
    }
  }

  /// Retry from the error state; only adds a loading state to the button.
  Future<void> _retryLoad() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await _loadQuestions();
    if (mounted) setState(() => _retrying = false);
  }

  SurveyQuestion get _current => _questions![_index];
  bool get _isLast => _index == (_questions?.length ?? 0) - 1;

  bool _canAdvance() {
    if (_questions == null) return false;
    final q = _current;
    return canAdvance(q, _answers[q.id]);
  }

  void _goTo(int index) {
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = index > _index;
      _index = index;
    });
  }

  void _next() {
    if (_isLast) {
      _submit();
    } else {
      _goTo(_index + 1);
    }
  }

  TextEditingController _textControllerFor(SurveyQuestion q) =>
      _textControllers.putIfAbsent(q.id, () {
        final existing = _answers[q.id];
        return TextEditingController(text: existing is String ? existing : '');
      });

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final res = await ViewerService.instance.submitSurvey(
        campaignId: _campaignId,
        answers: _answers,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      _showRewardSheet(res.rewardPaid);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = 'Илгээхэд алдаа гарлаа';
      });
    }
  }

  void _showRewardSheet(double reward) {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      // Sized by its content; scrolls instead of overflowing on short
      // screens / large text.
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
      // Let the confetti burst fly out over the scrim.
      clipBehavior: Clip.none,
      builder: (_) => _RewardSheet(reward: reward),
    ).then((_) {
      if (mounted) context.go(Routes.home);
    });
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final questions = _questions;
    final Widget body;
    if (_loadError != null) {
      body = _buildLoadError();
    } else if (questions == null) {
      body = _buildLoading();
    } else if (questions.isEmpty) {
      body = _buildNoQuestions();
    } else {
      body = _buildSurvey(questions);
    }

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: body),
      ),
    );
  }

  Widget _buildHeader({String? label}) {
    final reward = widget.campaign?.rewardPerUser;
    final company = widget.campaign?.companyName.trim() ?? '';

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: NavigationToolbar(
          middleSpacing: AppSpacing.md,
          leading: AppIconButton(
            icon: Icons.close_rounded,
            semanticLabel: 'Хаах',
            onPressed: () => context.go(Routes.home),
          ),
          middle: label == null
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (company.isNotEmpty) ...[
                      Text(
                        company.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.overline,
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleSmall.copyWith(
                        fontFeatures: AppTextStyles.tabular,
                      ),
                    ),
                  ],
                ),
          trailing: reward == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: RewardChip(
                    amount: reward,
                    size: RewardChipSize.small,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppLayout.screenPadding,
              AppSpacing.lg,
              AppLayout.screenPadding,
              AppSpacing.xxl,
            ),
            children: const [SurveySkeleton()],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadError() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                iconColor: AppColors.danger,
                title: 'Уучлаарай, алдаа гарлаа',
                message: _loadError,
                action: AppButton(
                  label: 'Дахин оролдох',
                  icon: Icons.refresh_rounded,
                  expand: false,
                  loading: _retrying,
                  haptic: true,
                  onPressed: _retryLoad,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoQuestions() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: EmptyState(
                icon: Icons.quiz_outlined,
                title: 'Асуулт олдсонгүй',
                message: 'Энэ судалгаанд одоогоор асуулт алга байна.',
                action: AppButton(
                  label: 'Нүүр хуудас руу буцах',
                  variant: AppButtonVariant.secondary,
                  expand: false,
                  onPressed: () => context.go(Routes.home),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSurvey(List<SurveyQuestion> questions) {
    final motion = AppMotion.duration(context, AppDurations.normal);

    return Column(
      children: [
        _buildHeader(label: questionProgressLabel(_index, questions.length)),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppLayout.screenPadding,
            AppSpacing.xs,
            AppLayout.screenPadding,
            0,
          ),
          child: SegmentedProgress(total: questions.length, current: _index),
        ),
        Expanded(child: ScrollEdgeFade(child: _buildQuestionSwitcher())),
        AnimatedSize(
          duration: motion,
          curve: AppMotion.standard,
          alignment: Alignment.topCenter,
          child: _submitError == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.screenPadding,
                    AppSpacing.sm,
                    AppLayout.screenPadding,
                    0,
                  ),
                  child: StatusBanner(message: _submitError!),
                ),
        ),
        _buildActionBar(motion),
      ],
    );
  }

  Widget _buildQuestionSwitcher() {
    final currentKey = ValueKey<int>(_index);
    final dir = _forward ? 1.0 : -1.0;

    return AnimatedSwitcher(
      duration: AppMotion.duration(context, AppDurations.medium),
      reverseDuration: AppMotion.duration(context, AppDurations.normal),
      // Incoming easing is applied below (after the fade-through delay).
      switchInCurve: Curves.linear,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) {
        // Incoming slides in from the direction of travel, outgoing leaves
        // the opposite way.
        final incoming = child.key == currentKey;
        final dx = incoming ? 0.08 * dir : -0.08 * dir;
        // Fade-through: the new question starts once the old one has
        // mostly faded, so the two never read on top of each other.
        final progress = incoming
            ? animation.drive(
                CurveTween(
                  curve: const Interval(0.35, 1, curve: AppMotion.standard),
                ),
              )
            : animation;
        return IgnorePointer(
          ignoring: !incoming,
          child: FadeTransition(
            opacity: progress,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(dx, 0),
                end: Offset.zero,
              ).animate(progress),
              child: child,
            ),
          ),
        );
      },
      child: KeyedSubtree(
        key: currentKey,
        child: _buildQuestion(_current),
      ),
    );
  }

  Widget _buildQuestion(SurveyQuestion q) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppLayout.screenPadding,
        AppSpacing.xxl,
        AppLayout.screenPadding,
        AppSpacing.xxl,
      ),
      children: [
        QuestionHeading(number: _index + 1, question: q),
        const SizedBox(height: AppSpacing.xxl),
        ..._buildAnswerInput(q),
      ],
    );
  }

  List<Widget> _buildAnswerInput(SurveyQuestion q) {
    switch (q.type) {
      case QuestionType.singleChoice:
        return [
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FadeSlideIn(
                index: i,
                offset: 12,
                child: OptionTile(
                  label: q.options[i],
                  index: i,
                  selected: _answers[q.id] == q.options[i],
                  onTap: () => setState(() => _answers[q.id] = q.options[i]),
                ),
              ),
            ),
        ];

      case QuestionType.multipleChoice:
        final current = (_answers[q.id] as List<String>?) ?? [];
        return [
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FadeSlideIn(
                index: i,
                offset: 12,
                child: OptionTile(
                  label: q.options[i],
                  index: i,
                  multiple: true,
                  selected: current.contains(q.options[i]),
                  onTap: () => setState(() {
                    final opt = q.options[i];
                    final list = List<String>.from(current);
                    if (!current.contains(opt)) {
                      list.add(opt);
                    } else {
                      list.remove(opt);
                    }
                    _answers[q.id] = list;
                  }),
                ),
              ),
            ),
        ];

      case QuestionType.text:
        return [
          FadeSlideIn(
            offset: 12,
            child: SurveyTextField(
              controller: _textControllerFor(q),
              onChanged: (v) => setState(() => _answers[q.id] = v),
            ),
          ),
        ];
    }
  }

  Widget _buildActionBar(Duration motion) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.screenPadding,
        AppSpacing.md,
        AppLayout.screenPadding,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          AnimatedSize(
            duration: motion,
            curve: AppMotion.standard,
            child: _index > 0
                ? Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: StepBackButton(onPressed: () => _goTo(_index - 1)),
                  )
                : const SizedBox(height: StepBackButton.size),
          ),
          Expanded(
            child: AdaptiveCtaButton(
              label: _isLast ? 'Илгээх ба урамшуулал авах' : 'Дараах',
              // Only used when the full label would be cut off (narrow
              // phones with large text).
              compactLabel: _isLast ? 'Илгээх' : null,
              haptic: true,
              loading: _submitting,
              onPressed: _canAdvance() ? _next : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardSheet extends StatelessWidget {
  const _RewardSheet({required this.reward});
  final double reward;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      clipBehavior: Clip.none,
      child: RewardCelebration(
        reward: reward,
        onContinue: () => Navigator.of(context).pop(),
      ),
    );
  }
}
