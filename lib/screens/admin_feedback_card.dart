import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/tawla_ui.dart';

const _maxMessageLength = 2000;

/// Sends the provider a problem, idea or question. Shown to the admin in Settings, online only.
class FeedbackCard extends StatefulWidget {
  /// [send] replaces the store's sender in tests.
  const FeedbackCard({super.key, this.send});

  final Future<String?> Function({
    required String kind,
    required String message,
  })?
  send;

  @override
  State<FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<FeedbackCard> {
  final _message = TextEditingController();
  String _kind = 'problem';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) {
      setState(() => _error = context.l10n.feedbackEmpty);
      return;
    }
    final send = widget.send ?? context.read<CafeStore>().sendFeedback;
    final messenger = ScaffoldMessenger.of(context);
    final sentText = context.l10n.feedbackSent;
    setState(() {
      _sending = true;
      _error = null;
    });
    final failure = await send(kind: _kind, message: text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = failure == null ? null : _failureText(failure);
      if (failure == null) _message.clear();
    });
    if (failure == null) {
      messenger.showSnackBar(SnackBar(content: Text(sentText)));
    }
  }

  String _failureText(String failure) {
    final l10n = context.l10n;
    return switch (failure) {
      'too many today' => l10n.feedbackTooMany,
      'message required' => l10n.feedbackEmpty,
      'session expired, sign in again' => l10n.errorText(failure),
      _ => l10n.feedbackFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kinds = {
      'problem': l10n.feedbackKindProblem,
      'idea': l10n.feedbackKindIdea,
      'question': l10n.feedbackKindQuestion,
      'other': l10n.feedbackKindOther,
    };
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(l10n.feedbackTitle, size: 18),
          const SizedBox(height: 4),
          Text(
            l10n.feedbackHint,
            style: const TextStyle(color: TawlaTokens.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in kinds.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _kind == entry.key,
                  onSelected: _sending
                      ? null
                      : (_) => setState(() => _kind = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: l10n.feedbackMessageLabel,
            child: TextField(
              controller: _message,
              enabled: !_sending,
              minLines: 3,
              maxLines: 6,
              maxLength: _maxMessageLength,
              keyboardType: TextInputType.multiline,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: CafeColors.alert,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          NavyButton(
            label: l10n.feedbackSend,
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}
