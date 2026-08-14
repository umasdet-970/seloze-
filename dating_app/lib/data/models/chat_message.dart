/// One message in a conversation (spec section 7: text, image, timestamp,
/// read/unread).
class ChatMessage {
  final String id;
  final String senderId;
  final String? text;
  final String? imageUrl;
  final DateTime sentAt;
  final bool read;

  const ChatMessage({
    required this.id,
    required this.senderId,
    this.text,
    this.imageUrl,
    required this.sentAt,
    this.read = false,
  });

  bool get isImage => imageUrl != null;

  ChatMessage copyWith({bool? read}) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      text: text,
      imageUrl: imageUrl,
      sentAt: sentAt,
      read: read ?? this.read,
    );
  }
}
