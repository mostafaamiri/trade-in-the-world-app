import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'services/game_api.dart';
import 'ui.dart';

class CommandCenterPage extends StatefulWidget {
  const CommandCenterPage({super.key, required this.api});

  final GameApi api;

  @override
  State<CommandCenterPage> createState() => _CommandCenterPageState();
}

class _CommandCenterPageState extends State<CommandCenterPage> {
  final _token = TextEditingController();
  Future<List<CommandCenterQuestion>>? _questions;
  String? _answeringId;
  String? _tokenError;
  var _entered = false;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  void _enter() {
    if (_token.text.trim().isEmpty) {
      setState(() => _tokenError = 'برای ورود یک توکن وارد کن.');
      return;
    }
    setState(() {
      _tokenError = null;
      _entered = true;
      _questions = widget.api.commandCenterQuestions();
    });
  }

  Future<void> _refresh() async {
    final questions = widget.api.commandCenterQuestions();
    setState(() => _questions = questions);
    await questions;
  }

  Future<void> _answer(CommandCenterQuestion question, int optionIndex) async {
    if (_answeringId != null || question.answer != null) return;
    setState(() => _answeringId = question.id);
    try {
      final result = await widget.api.answerCommandCenterQuestion(
        question.id,
        optionIndex,
      );
      if (!mounted) return;
      final reward = _rewardText(result.coinsAwarded, result.tokensAwarded);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.alreadyAnswered
                ? 'پاسخ این سؤال قبلاً ثبت شده است.'
                : result.isCorrect
                ? reward.isEmpty
                      ? 'آفرین! پاسخ درست است.'
                      : 'آفرین! $reward به حسابت اضافه شد.'
                : 'پاسخ نادرست ثبت شد.',
          ),
        ),
      );
      await _refresh();
    } catch (error) {
      if (mounted) await showFailure(context, error);
    } finally {
      if (mounted) setState(() => _answeringId = null);
    }
  }

  Future<void> _openMedia(CommandCenterMedia media) async {
    final uri = Uri.tryParse(media.viewUrl.isEmpty ? media.url : media.viewUrl);
    if (uri == null || !uri.hasScheme) {
      if (mounted) await showFailure(context, 'نشانی رسانه معتبر نیست.');
      return;
    }
    try {
      final openedInApp = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      if (!openedInApp &&
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const GameApiException('باز کردن رسانه ممکن نشد.');
      }
    } catch (error) {
      if (mounted) await showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: appNavy,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/command_center_background.png',
          fit: BoxFit.cover,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x80020D1C), Color(0xCC020D1C)],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundActionButton(
                      tooltip: 'بازگشت',
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    if (_entered)
                      _RoundActionButton(
                        tooltip: 'بروزرسانی',
                        icon: Icons.refresh_rounded,
                        onPressed: _refresh,
                      ),
                  ],
                ),
                if (_entered) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'اتاق فرمان',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Color(0xB0000000), blurRadius: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'سؤال‌ها و محتوای میز کار ادمین',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xffB9ECFF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _questionsView()),
                ] else
                  Expanded(
                    child: _CommandCenterEntryForm(
                      controller: _token,
                      errorText: _tokenError,
                      onEntered: _enter,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _questionsView() {
    final questions = _questions;
    if (questions == null) return const SizedBox.shrink();
    return FutureBuilder<List<CommandCenterQuestion>>(
      future: questions,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('دریافت دوباره'),
            ),
          );
        }
        final items = snapshot.data ?? const <CommandCenterQuestion>[];
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'هنوز محتوایی در میز کار ادمین منتشر نشده است.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _CommandCenterQuestionCard(
              question: items[index],
              number: index + 1,
              answering: _answeringId == items[index].id,
              onAnswer: _answer,
              onOpenMedia: _openMedia,
            ),
          ),
        );
      },
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0x33000000),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      color: Colors.white,
      onPressed: onPressed,
      icon: Icon(icon),
    ),
  );
}

class _CommandCenterEntryForm extends StatelessWidget {
  const _CommandCenterEntryForm({
    required this.controller,
    required this.errorText,
    required this.onEntered,
  });

  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onEntered;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Card(
        color: const Color(0xEDFFFFFF),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.settings_input_component_rounded,
                color: Color(0xff1177b8),
                size: 42,
              ),
              const SizedBox(height: 12),
              const Text(
                'ورود به اتاق فرمان',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'توکن دستگاه را از پایین صفحهٔ پروفایل کپی و اینجا وارد کن.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xff526677)),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                autofocus: true,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onEntered(),
                decoration: InputDecoration(
                  labelText: 'توکن',
                  hintText: 'CMD-XXXXX-XXXXX-XXXXX-XXXXX',
                  errorText: errorText,
                  prefixIcon: const Icon(Icons.key_rounded),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onEntered,
                icon: const Icon(Icons.login_rounded),
                label: const Text('ورود'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CommandCenterQuestionCard extends StatelessWidget {
  const _CommandCenterQuestionCard({
    required this.question,
    required this.number,
    required this.answering,
    required this.onAnswer,
    required this.onOpenMedia,
  });

  final CommandCenterQuestion question;
  final int number;
  final bool answering;
  final void Function(CommandCenterQuestion question, int optionIndex) onAnswer;
  final Future<void> Function(CommandCenterMedia media) onOpenMedia;

  @override
  Widget build(BuildContext context) {
    final answer = question.answer;
    return Card(
      color: const Color(0xF7FFFFFF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xff1177b8),
                  foregroundColor: Colors.white,
                  child: Text('$number'),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'میز کار ادمین',
                    style: TextStyle(
                      color: appNavy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _RewardBadges(question: question),
              ],
            ),
            if (question.media case final media?) ...[
              const SizedBox(height: 14),
              _QuestionMedia(media: media, onOpen: onOpenMedia),
            ],
            if (question.prompt.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                question.prompt,
                style: const TextStyle(
                  color: appInk,
                  fontSize: 17,
                  height: 1.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (question.options.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (var index = 0; index < question.options.length; index++) ...[
                OutlinedButton(
                  onPressed: answer != null || answering
                      ? null
                      : () => onAnswer(question, index),
                  style: OutlinedButton.styleFrom(
                    alignment: AlignmentDirectional.centerStart,
                    foregroundColor: answer?.optionIndex == index
                        ? answer!.isCorrect
                              ? appGreen
                              : appRed
                        : appNavy,
                    side: BorderSide(
                      color: answer?.optionIndex == index
                          ? answer!.isCorrect
                                ? appGreen
                                : appRed
                          : const Color(0xff9db0c0),
                    ),
                  ),
                  child: Text('${index + 1}. ${question.options[index]}'),
                ),
                if (index < question.options.length - 1)
                  const SizedBox(height: 8),
              ],
              if (answering) ...[
                const SizedBox(height: 8),
                const Center(child: CircularProgressIndicator()),
              ],
              if (answer != null) ...[
                const SizedBox(height: 12),
                _AnswerFeedback(answer: answer),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RewardBadges extends StatelessWidget {
  const _RewardBadges({required this.question});

  final CommandCenterQuestion question;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    children: [
      if (question.coinReward > 0)
        _RewardBadge(
          icon: Icons.monetization_on_rounded,
          label: persianDigits(question.coinReward),
          color: appGold,
        ),
      if (question.tokenReward > 0)
        _RewardBadge(
          icon: Icons.toll_rounded,
          label: persianDigits(question.tokenReward),
          color: appGreen,
        ),
    ],
  );
}

class _RewardBadge extends StatelessWidget {
  const _RewardBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _QuestionMedia extends StatelessWidget {
  const _QuestionMedia({required this.media, required this.onOpen});

  final CommandCenterMedia media;
  final Future<void> Function(CommandCenterMedia media) onOpen;

  @override
  Widget build(BuildContext context) {
    final label = media.originalName.isEmpty
        ? 'رسانهٔ میز کار'
        : media.originalName;
    if (media.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            onOpen(media);
          },
          child: Image.network(
            media.url,
            height: 210,
            width: double.infinity,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const SizedBox(
                    height: 210,
                    child: Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (_, _, _) => const SizedBox(
              height: 130,
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: appRed,
                  size: 42,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: () {
        onOpen(media);
      },
      icon: Icon(_mediaIcon(media)),
      label: Text('باز کردن $label'),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({required this.answer});

  final CommandCenterAnswer answer;

  @override
  Widget build(BuildContext context) {
    final isCorrect = answer.isCorrect;
    final reward = _rewardText(answer.rewardCoins, answer.rewardTokens);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isCorrect ? appGreen : appRed).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isCorrect
            ? reward.isEmpty
                  ? 'آفرین! پاسخ شما درست است.'
                  : 'آفرین! پاسخ درست است و $reward دریافت کردی.'
            : 'پاسخ شما نادرست است.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isCorrect ? appGreen : appRed,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

IconData _mediaIcon(CommandCenterMedia media) {
  if (media.kind == 'video' || media.mimeType.startsWith('video/')) {
    return Icons.play_circle_outline_rounded;
  }
  if (media.kind == 'audio' || media.mimeType.startsWith('audio/')) {
    return Icons.audio_file_outlined;
  }
  if (media.kind == 'pdf' || media.mimeType == 'application/pdf') {
    return Icons.picture_as_pdf_outlined;
  }
  if (media.kind == 'html' || media.kind == 'javascript') {
    return Icons.code_rounded;
  }
  return Icons.open_in_new_rounded;
}

String _rewardText(int coins, int tokens) {
  final parts = <String>[];
  if (coins > 0) parts.add('${persianDigits(coins)} کوین');
  if (tokens > 0) parts.add('${persianDigits(tokens)} سکه');
  return parts.join(' و ');
}
