import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/campaign.dart';
import '../../models/survey_question.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../services/viewer_service.dart';
import '../../theme/app_theme.dart';

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

  final Map<int, dynamic> _answers = {}; // questionId -> answer
  int _index = 0;
  bool _submitting = false;
  String? _submitError;

  int get _campaignId => int.tryParse(widget.campaignId) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
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

  SurveyQuestion get _current => _questions![_index];
  bool get _isLast => _index == (_questions?.length ?? 0) - 1;

  bool _canAdvance() {
    if (_questions == null) return false;
    final q = _current;
    if (!q.required) return true;
    final a = _answers[q.id];
    if (a == null) return false;
    if (a is String && a.trim().isEmpty) return false;
    if (a is List && a.isEmpty) return false;
    return true;
  }

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
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RewardSheet(reward: reward),
    ).then((_) {
      if (mounted) context.go(Routes.home);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go(Routes.home),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger)),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: _loadQuestions,
                    child: const Text('Дахин')),
              ],
            ),
          ),
        ),
      );
    }

    if (_questions == null) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
      );
    }

    final q = _current;
    return Scaffold(
      appBar: AppBar(
        title: Text('${_index + 1} / ${_questions!.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(Routes.home),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / _questions!.length,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 3,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      q.prompt,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(child: _buildAnswerInput(q)),
                  ],
                ),
              ),
            ),
            if (_submitError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _submitError!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 13),
                  ),
                ),
              ),
            SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  if (_index > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _index -= 1),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          side: const BorderSide(color: AppColors.divider),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          foregroundColor: AppColors.textPrimary,
                        ),
                        child: const Text('Буцах'),
                      ),
                    ),
                  if (_index > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: !_canAdvance() || _submitting
                          ? null
                          : () {
                              if (_isLast) {
                                _submit();
                              } else {
                                setState(() => _index += 1);
                              }
                            },
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.black),
                              ),
                            )
                          : Text(_isLast ? 'Илгээх ба урамшуулал авах' : 'Дараах'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerInput(SurveyQuestion q) {
    switch (q.type) {
      case QuestionType.singleChoice:
        return ListView.separated(
          itemCount: q.options.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final opt = q.options[i];
            final selected = _answers[q.id] == opt;
            return InkWell(
              onTap: () => setState(() => _answers[q.id] = opt),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withOpacity(0.12)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        selected ? AppColors.primary : AppColors.divider,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        opt,
                        style: TextStyle(
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

      case QuestionType.multipleChoice:
        return ListView.separated(
          itemCount: q.options.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final opt = q.options[i];
            final current = (_answers[q.id] as List<String>?) ?? [];
            final selected = current.contains(opt);
            return CheckboxListTile(
              value: selected,
              onChanged: (v) => setState(() {
                final list = List<String>.from(current);
                if (v == true) {
                  list.add(opt);
                } else {
                  list.remove(opt);
                }
                _answers[q.id] = list;
              }),
              title: Text(opt),
              activeColor: AppColors.primary,
              controlAffinity: ListTileControlAffinity.leading,
            );
          },
        );

      case QuestionType.text:
        return TextField(
          maxLines: 6,
          onChanged: (v) => setState(() => _answers[q.id] = v),
          decoration: const InputDecoration(
            hintText: 'Санал бодлоо бичээрэй...',
          ),
        );
    }
  }
}

class _RewardSheet extends StatelessWidget {
  const _RewardSheet({required this.reward});
  final double reward;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: AppColors.success, size: 42),
          ),
          const SizedBox(height: 20),
          const Text(
            'Урамшуулал таны хэтэвчинд орлоо',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '+ ${reward.toInt()} ₮',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Дараагийн видео үзэх'),
            ),
          ),
        ],
      ),
    );
  }
}
