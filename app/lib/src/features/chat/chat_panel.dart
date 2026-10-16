import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/language.dart';
import '../../core/voice_input.dart';
import '../../theme.dart';
import 'chat_controller.dart';

const _violet = Color(0xFF5B3FD0);

/// A friendly chat with the AI assistant: suggested questions, a typing indicator,
/// answers that "write themselves", source chips and a mic. Used by the patient app
/// and by the doctor's dashboard.
class ChatPanel extends ConsumerStatefulWidget {
  const ChatPanel({
    super.key,
    required this.scope,
    required this.title,
    required this.subtitle,
    required this.welcome,
    required this.suggestions,
    this.height,
    this.onSourceTap,
    this.accent = MediCardColors.primary,
    this.showHeader = true,
    this.onClose,
  });

  final ChatScope scope;
  final String title;
  final String subtitle;
  final String welcome;
  final List<String> suggestions;

  /// Fixed height for an inline card; null = fill the parent (sheets).
  final double? height;
  final void Function(String recordId)? onSourceTap;
  final Color accent;
  final bool showHeader;
  final VoidCallback? onClose;

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _voice = VoiceInput();

  @override
  void initState() {
    super.initState();
    _voice.addListener(() => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _voice.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? q]) async {
    final question = (q ?? _text.text).trim();
    if (question.length < 2) return;
    _text.clear();
    final ctl = ref.read(chatProvider(widget.scope).notifier);
    final f = ctl.send(question);
    _toBottom();
    await f;
    _toBottom();
  }

  Future<void> _mic() async {
    if (_voice.listening) {
      await _voice.stop();
      if (_text.text.trim().length >= 2) _send();
      return;
    }
    await _voice.start(
      urdu: ref.read(urduProvider),
      onText: (t, isFinal) {
        _text.text = t;
        _text.selection = TextSelection.collapsed(offset: t.length);
        if (isFinal && t.trim().length >= 2) _send();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider(widget.scope));
    final listening = _voice.listening;
    final empty = chat.messages.isEmpty;

    final body = Column(children: [
      if (widget.showHeader) _header(chat),
      Expanded(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          children: [
            _Bubble(
              mine: false,
              accent: widget.accent,
              child: Text(widget.welcome, style: const TextStyle(fontSize: 14.5, height: 1.5)),
            ),
            if (empty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 40, bottom: 6),
                child: Text('Tap a question, or type your own',
                    style: TextStyle(
                        fontSize: 12, color: MediCardColors.muted.withOpacity(0.9))),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final q in widget.suggestions) _SuggestionChip(q, widget.accent, _send),
                ]),
              ),
            ],
            for (final m in chat.messages)
              _Bubble(
                mine: m.mine,
                accent: widget.accent,
                child: m.mine
                    ? Text(m.text,
                        style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.45))
                    : _Answer(
                        message: m,
                        accent: widget.accent,
                        onSourceTap: widget.onSourceTap,
                        onTick: _toBottom,
                      ),
              ),
            if (chat.thinking) _Bubble(mine: false, accent: widget.accent, child: const _Dots()),
            if (!empty && !chat.thinking) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final q in _remaining(chat)) _SuggestionChip(q, widget.accent, _send),
                ]),
              ),
            ],
          ],
        ),
      ),
      _inputBar(listening),
    ]);

    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MediCardColors.border),
        boxShadow: [
          BoxShadow(
              color: MediCardColors.ink.withOpacity(0.05),
              blurRadius: 22,
              offset: const Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: body,
    );
    return widget.height == null ? card : SizedBox(height: widget.height, child: card);
  }

  /// Suggestions not asked yet (max 3), shown under the latest answer.
  List<String> _remaining(ChatState chat) {
    final asked = chat.messages.where((m) => m.mine).map((m) => m.text).toSet();
    return widget.suggestions.where((q) => !asked.contains(q)).take(3).toList();
  }

  Widget _header(ChatState chat) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [widget.accent, Color.lerp(widget.accent, Colors.black, 0.25)!]),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800)),
              Row(children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(color: Color(0xFF7CF0D6), shape: BoxShape.circle),
                ),
                Flexible(
                  child: Text(widget.subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                ),
              ]),
            ]),
          ),
          if (chat.messages.isNotEmpty)
            IconButton(
              tooltip: 'New chat',
              onPressed: () => ref.read(chatProvider(widget.scope).notifier).clear(),
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          if (widget.onClose != null)
            IconButton(
              tooltip: 'Close',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
        ]),
      );

  Widget _inputBar(bool listening) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: MediCardColors.border)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: Container(
                height: 50,
                padding: const EdgeInsets.only(left: 14, right: 4),
                decoration: BoxDecoration(
                  color: MediCardColors.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: listening ? MediCardColors.danger : MediCardColors.border),
                ),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: listening ? 'Listening…' : 'Type your question…',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: listening ? 'Stop' : 'Speak',
                    onPressed: _mic,
                    icon: Icon(listening ? Icons.stop_circle : Icons.mic_none,
                        color: listening ? MediCardColors.danger : MediCardColors.muted),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _send,
              customBorder: const CircleBorder(),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: widget.accent, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            widget.scope.doctor
                ? 'Advisory only — answers come from the shared records. You decide.'
                : 'Answers come only from your own records. For emergencies, call your doctor.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: MediCardColors.muted),
          ),
        ]),
      );
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip(this.text, this.accent, this.onTap);
  final String text;
  final Color accent;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onTap(text),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withOpacity(0.30)),
          ),
          child: Text(text,
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: Color.lerp(accent, Colors.black, 0.25))),
        ),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.mine, required this.child, required this.accent});
  final bool mine;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mine) ...[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: accent.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(Icons.auto_awesome, size: 15, color: accent),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: mine ? accent : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 18),
                  ),
                ),
                child: child,
              ),
            ),
          ],
        ),
      );
}

/// An assistant answer: types itself out once, then shows its sources.
class _Answer extends StatefulWidget {
  const _Answer({required this.message, required this.accent, this.onSourceTap, this.onTick});
  final ChatMessage message;
  final Color accent;
  final void Function(String)? onSourceTap;
  final VoidCallback? onTick;

  @override
  State<_Answer> createState() => _AnswerState();
}

class _AnswerState extends State<_Answer> {
  Timer? _t;
  late int _shown = widget.message.animate ? 0 : widget.message.text.length;

  @override
  void initState() {
    super.initState();
    if (widget.message.animate) {
      _t = Timer.periodic(const Duration(milliseconds: 16), (t) {
        if (!mounted) return;
        setState(() => _shown = (_shown + 3).clamp(0, widget.message.text.length));
        widget.onTick?.call();
        if (_shown >= widget.message.text.length) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final done = _shown >= m.text.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(m.text.substring(0, _shown), style: const TextStyle(fontSize: 14.5, height: 1.5)),
      if (done && !m.fromRecords)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Not found in the records',
              style: TextStyle(
                  fontSize: 11.5, fontStyle: FontStyle.italic, color: MediCardColors.unverified)),
        ),
      if (done && m.sourceIds.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final id in m.sourceIds)
            InkWell(
              onTap: widget.onSourceTap == null ? null : () => widget.onSourceTap!(id),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.accent.withOpacity(0.35)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.article_outlined, size: 13, color: widget.accent),
                  const SizedBox(width: 4),
                  Text(_label(id),
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700, color: widget.accent)),
                ]),
              ),
            ),
        ]),
      ],
    ]);
  }

  String _label(String id) => id.length > 10 ? 'record ${id.substring(0, 6)}' : 'Source · $id';
}

class _Dots extends StatefulWidget {
  const _Dots();

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 20,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MediCardColors.muted
                      .withOpacity(0.25 + 0.55 * (((_c.value * 3) - i).clamp(0.0, 1.0) * (1 - ((_c.value * 3) - i - 1).clamp(0.0, 1.0)))),
                ),
              ),
          ]),
        ),
      );
}

/// Opens the chat as a bottom sheet (phone) or a side panel (desktop).
Future<void> showChat(
  BuildContext context, {
  required ChatScope scope,
  required String title,
  required String subtitle,
  required String welcome,
  required List<String> suggestions,
  String? firstQuestion,
  void Function(String recordId)? onSourceTap,
  Color accent = MediCardColors.primary,
}) {
  final wide = MediaQuery.of(context).size.width >= 900;
  Widget panel(BuildContext c) => _SheetBody(
        scope: scope,
        title: title,
        subtitle: subtitle,
        welcome: welcome,
        suggestions: suggestions,
        firstQuestion: firstQuestion,
        accent: accent,
        onSourceTap: onSourceTap == null
            ? null
            : (id) {
                Navigator.of(c).pop();
                onSourceTap(id);
              },
      );
  if (wide) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (c, _, __) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(width: 460, height: double.infinity, child: panel(c)),
          ),
        ),
      ),
      transitionBuilder: (c, a, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0.2, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: a, child: child),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (c) => Padding(
      padding: EdgeInsets.only(top: 40, bottom: MediaQuery.of(c).viewInsets.bottom),
      child: panel(c),
    ),
  );
}

class _SheetBody extends ConsumerStatefulWidget {
  const _SheetBody({
    required this.scope,
    required this.title,
    required this.subtitle,
    required this.welcome,
    required this.suggestions,
    required this.accent,
    this.firstQuestion,
    this.onSourceTap,
  });

  final ChatScope scope;
  final String title;
  final String subtitle;
  final String welcome;
  final List<String> suggestions;
  final String? firstQuestion;
  final Color accent;
  final void Function(String)? onSourceTap;

  @override
  ConsumerState<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends ConsumerState<_SheetBody> {
  @override
  void initState() {
    super.initState();
    final q = widget.firstQuestion;
    if (q != null && q.isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => ref.read(chatProvider(widget.scope).notifier).send(q));
    }
  }

  @override
  Widget build(BuildContext context) => ChatPanel(
        scope: widget.scope,
        title: widget.title,
        subtitle: widget.subtitle,
        welcome: widget.welcome,
        suggestions: widget.suggestions,
        accent: widget.accent,
        onSourceTap: widget.onSourceTap,
        onClose: () => Navigator.of(context).pop(),
      );
}

/// Floating "Ask AI" button.
class AskAiFab extends StatelessWidget {
  const AskAiFab({super.key, required this.onPressed, this.accent = MediCardColors.primary});
  final VoidCallback onPressed;
  final Color accent;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        heroTag: 'ask-ai-fab',
        onPressed: onPressed,
        backgroundColor: accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Ask AI', style: TextStyle(fontWeight: FontWeight.w800)),
      );
}

// Used by screens that need a route-aware opener.
void openRecordFromChat(BuildContext context, String patientId, String recordId) =>
    context.go('/doctor/patients/$patientId/records/$recordId');

const doctorAccent = _violet;
