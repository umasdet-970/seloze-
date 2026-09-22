/// One message in a conversation (spec section 7: text, image, voice note,
/// timestamp, read/unread).
class ChatMessage {
  final String id;
  final String senderId;
  final String? text;
  final String? imageUrl;
  final String? audioUrl;
  final int? audioDurationSec;
  final DateTime sentAt;
  final bool read;

  const ChatMessage({
    required this.id,
    required this.senderId,
    this.text,
    this.imageUrl,
    this.audioUrl,
    this.audioDurationSec,
    required this.sentAt,
    this.read = false,
  });

  bool get isImage => imageUrl != null;
  bool get isAudio => audioUrl != null;

  ChatMessage copyWith({bool? read}) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      text: text,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      audioDurationSec: audioDurationSec,
      sentAt: sentAt,
      read: read ?? this.read,
    );
  }
}
