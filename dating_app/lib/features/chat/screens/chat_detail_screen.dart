import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/subscription_models.dart';
import '../../../shared/widgets/report_sheet.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../discover/providers/discover_providers.dart';
import '../../safety/providers/moderation_providers.dart';
import '../../subscription/providers/subscription_providers.dart';
import '../providers/chat_providers.dart';

const _sampleImageUrls = [
  'https://images.unsplash.com/photo-1552168324-d612d77725e3?w=600',
  'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=600',
  'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=600',
];

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final Profile? profile;

  const ChatDetailScreen({super.key, required this.conversationId, this.profile});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  Profile? _resolvedProfile;

  @override
  void initState() {
    super.initState();
    _resolvedProfile = widget.profile;
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final uid = ref.read(currentUserIdProvider);
    await ref.read(chatRepositoryProvider).markRead(widget.conversationId, uid);

    if (_resolvedProfile == null) {
      final ids = widget.conversationId.split('_');
      final otherId = ids.first == uid ? ids.last : ids.first;
      final profile = await ref.read(profileRepositoryProvider).fetchProfileById(otherId);
      if (mounted) setState(() => _resolvedProfile = profile);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    final moderation = await ref.read(moderationRepositoryProvider).moderateText(text);
    if (!moderation.allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(moderation.reason!)));
      }
      return;
    }

    _textController.clear();
    final uid = ref.read(currentUserIdProvider);
    try {
      await ref.read(chatRepositoryProvider).sendText(widget.conversationId, uid, text);
      ref.read(analyticsRepositoryProvider).logEvent('message_sent', params: {'type': 'text'});
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _pickImage() async {
    final url = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _sampleImageUrls.map((url) {
              return GestureDetector(
                onTap: () => Navigator.pop(context, url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(url, width: 90, height: 90, fit: BoxFit.cover),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
    if (url == null) return;
    final uid = ref.read(currentUserIdProvider);
    try {
      await ref.read(chatRepositoryProvider).sendImage(widget.conversationId, uid, url);
      ref.read(analyticsRepositoryProvider).logEvent('message_sent', params: {'type': 'image'});
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(subscriptionTierProvider) == SubscriptionTier.premium;
    final profile = _resolvedProfile;
    final uid = ref.watch(currentUserIdProvider);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!isPremium) {
      return Scaffold(
        appBar: AppBar(title: Text(profile.name)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: AppColors.primary),
                const SizedBox(height: 12),
                Text('Chat with ${profile.name} is a Premium feature', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/paywall'),
                  child: const Text('Upgrade to Premium'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final messages = ref.watch(chatMessagesProvider(widget.conversationId));
    final typing = ref.watch(isOtherUserTypingProvider((conversationId: widget.conversationId, otherUserId: profile.id)));
    if (messages.isNotEmpty) _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedNetworkImage(
                imageUrl: profile.photoUrls.isNotEmpty ? profile.photoUrls.first : '',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(width: 36, height: 36, color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(profile.name, style: const TextStyle(fontSize: 15)),
                  Text(
                    typing ? 'typing…' : (profile.isOnline ? 'Online' : 'Offline'),
                    style: TextStyle(fontSize: 11, color: typing ? AppColors.primary : AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) => _handleMenu(action, profile),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'block', child: Text('Block')),
              PopupMenuItem(value: 'report', child: Text('Report')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('Say hi 👋', style: TextStyle(color: AppColors.textMuted)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == uid;
                      final isLastMine = isMe && index == messages.length - 1;
                      return _MessageBubble(message: message, isMe: isMe, showReadReceipt: isLastMine);
                    },
                  ),
          ),
          if (typing)
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 4),
              child: Align(alignment: Alignment.centerLeft, child: Text('typing…', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
            ),
          _Composer(controller: _textController, onSend: _sendText, onPickImage: _pickImage),
        ],
      ),
    );
  }

  void _handleMenu(String action, Profile profile) async {
    final uid = ref.read(currentUserIdProvider);
    if (action == 'block') {
      await ref.read(socialRepositoryProvider).block(uid, profile.id);
      if (mounted) Navigator.of(context).pop();
    } else if (action == 'report') {
      await showReportSheet(
        context,
        targetName: profile.name,
        onSubmit: (reason, details) =>
            ref.read(socialRepositoryProvider).report(uid, profile.id, reason: reason, details: details),
      );
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showReadReceipt;

  const _MessageBubble({required this.message, required this.isMe, required this.showReadReceipt});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? AppColors.primary : Colors.grey.shade200;
    final textColor = isMe ? Colors.white : AppColors.textDark;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            padding: message.isImage ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(18)),
            child: message.isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(message.imageUrl!, width: 180, height: 180, fit: BoxFit.cover),
                  )
                : Text(message.text ?? '', style: TextStyle(color: textColor)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_formatTime(message.sentAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                if (showReadReceipt) ...[
                  const SizedBox(width: 4),
                  Icon(message.read ? Icons.done_all : Icons.done, size: 12, color: message.read ? AppColors.primary : AppColors.textMuted),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  const _Composer({required this.controller, required this.onSend, required this.onPickImage});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            IconButton(onPressed: onPickImage, icon: const Icon(Icons.image_outlined)),
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: onSend, icon: const Icon(Icons.send)),
          ],
        ),
      ),
    );
  }
}
