import 'package:flutter_test/flutter_test.dart';

import 'package:connect_dating_app/data/models/chat_message.dart';
import 'package:connect_dating_app/data/repositories/chat_repository.dart';

void main() {
  group('ChatMessage.isAudio', () {
    final now = DateTime.now();

    test('true only when audioUrl is set', () {
      final audio = ChatMessage(id: '1', senderId: 'a', audioUrl: 'https://x/y.m4a', sentAt: now);
      expect(audio.isAudio, isTrue);
      expect(audio.isImage, isFalse);

      final text = ChatMessage(id: '2', senderId: 'a', text: 'hi', sentAt: now);
      expect(text.isAudio, isFalse);

      final image = ChatMessage(id: '3', senderId: 'a', imageUrl: 'https://x/y.jpg', sentAt: now);
      expect(image.isAudio, isFalse);
    });

    test('copyWith preserves audioUrl/audioDurationSec while flipping read', () {
      final audio = ChatMessage(id: '1', senderId: 'a', audioUrl: 'https://x/y.m4a', audioDurationSec: 12, sentAt: now);
      final read = audio.copyWith(read: true);
      expect(read.audioUrl, audio.audioUrl);
      expect(read.audioDurationSec, 12);
      expect(read.read, isTrue);
    });
  });

  group('MockChatRepository.sendAudio', () {
    test('appends an audio message with the given duration', () async {
      final chat = MockChatRepository();
      const convo = 'a_b';
      await chat.sendAudio(convo, 'a', 'file:///tmp/note.m4a', durationSec: 7);

      final messages = chat.messages(convo);
      expect(messages, hasLength(1));
      expect(messages.single.isAudio, isTrue);
      expect(messages.single.audioUrl, 'file:///tmp/note.m4a');
      expect(messages.single.audioDurationSec, 7);
      expect(messages.single.isImage, isFalse);
    });

    test('an unread audio message from the other person counts toward unreadCount', () async {
      final chat = MockChatRepository();
      const convo = 'a_b';
      await chat.sendAudio(convo, 'b', 'file:///tmp/note.m4a', durationSec: 3);
      expect(chat.unreadCount(convo, 'a'), 1);

      await chat.markRead(convo, 'a');
      expect(chat.unreadCount(convo, 'a'), 0);
    });
  });
}
