import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../access/access_repository.dart';
import '../patient/patient_repository.dart';

/// Which conversation: the patient's own assistant, or the doctor's (optionally about one patient).
class ChatScope {
  const ChatScope.patient()
      : doctor = false,
        patientId = null;
  const ChatScope.doctor({this.patientId}) : doctor = true;

  final bool doctor;
  final String? patientId;

  @override
  bool operator ==(Object other) =>
      other is ChatScope && other.doctor == doctor && other.patientId == patientId;

  @override
  int get hashCode => Object.hash(doctor, patientId);
}

class ChatMessage {
  ChatMessage({
    required this.mine,
    required this.text,
    this.fromRecords = true,
    this.sourceIds = const [],
    this.animate = false,
  });

  final bool mine;
  final String text;
  final bool fromRecords;
  final List<String> sourceIds;

  /// Reveal the text word by word (the newest assistant reply only).
  final bool animate;

  ChatMessage settled() => ChatMessage(
        mine: mine,
        text: text,
        fromRecords: fromRecords,
        sourceIds: sourceIds,
      );
}

class ChatState {
  const ChatState({this.messages = const [], this.thinking = false});
  final List<ChatMessage> messages;
  final bool thinking;

  ChatState copy({List<ChatMessage>? messages, bool? thinking}) =>
      ChatState(messages: messages ?? this.messages, thinking: thinking ?? this.thinking);
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref, this.scope) : super(const ChatState());

  final Ref _ref;
  final ChatScope scope;

  Future<void> send(String question) async {
    final q = question.trim();
    if (q.length < 2 || state.thinking) return;
    final settled = [for (final m in state.messages) m.settled()];
    state = state.copy(messages: [...settled, ChatMessage(mine: true, text: q)], thinking: true);
    ChatMessage reply;
    try {
      if (scope.doctor) {
        final a = await _ref
            .read(accessRepositoryProvider)
            .assistantAsk(q, patientId: scope.patientId);
        reply = ChatMessage(
          mine: false,
          text: a.answer,
          fromRecords: a.answeredFromRecords,
          sourceIds: a.sourceRecordIds,
          animate: true,
        );
      } else {
        final a = await _ref.read(patientRepositoryProvider).ask(q);
        reply = ChatMessage(
          mine: false,
          text: a.answer,
          fromRecords: a.fromRecords,
          animate: true,
        );
      }
    } catch (_) {
      reply = ChatMessage(
        mine: false,
        text: 'Sorry — I could not reach the assistant just now. Please try again.',
        fromRecords: false,
      );
    }
    if (!mounted) return;
    state = state.copy(messages: [...state.messages, reply], thinking: false);
  }

  void clear() => state = const ChatState();
}

final chatProvider =
    StateNotifierProvider.family<ChatController, ChatState, ChatScope>((ref, scope) {
  return ChatController(ref, scope);
});
