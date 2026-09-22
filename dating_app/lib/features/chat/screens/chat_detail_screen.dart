import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/firebase/firebase_storage_uploader.dart';
import '../../../shared/widgets/report_sheet.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../discover/providers/discover_providers.dart';
import '../../safety/providers/moderation_providers.dart';
import '../../subscription/providers/subscription_providers.dart';
import '../providers/chat_providers.dart';
import '../widgets/voice_note_bubble.dart';

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
  Timer? _typingStopTimer;
  bool _isTypingSent = false;

  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isSendingRecording = false;
  Timer? _recordingTicker;
  Duration _recordingElapsed = Duration.zero;
  static const _maxRecordingDuration = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    _resolvedProfile = widget.profile;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
      ref.read(openConversationIdProvider.notifier).state = widget.conversationId;
    });
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
    if (ref.read(openConversationIdProvider) == widget.conversationId) {
      ref.read(openConversationIdProvider.notifier).state = null;
    }
    _typingStopTimer?.cancel();
    if (_isTypingSent) {
      // Best-effort, fire-and-forget — a widget mid-dispose can't await.
      ref.read(chatRepositoryProvider).setTyping(widget.conversationId, ref.read(currentUserIdProvider), false);
    }
    _recordingTicker?.cancel();
    if (_isRecording) _audioRecorder.cancel();
    _audioRecorder.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Debounced typing indicator (spec section 7): marks typing=true on the
  /// first keystroke after being idle, and typing=false either
  /// immediately when the field is cleared or after 3s of no further
  /// input — not on every keystroke, which would spam writes.
  void _onComposerChanged(String text) {
    _typingStopTimer?.cancel();
    final uid = ref.read(currentUserIdProvider);

    if (text.trim().isEmpty) {
      if (_isTypingSent) {
        _isTypingSent = false;
        ref.read(chatRepositoryProvider).setTyping(widget.conversationId, uid, false);
      }
      return;
    }

    if (!_isTypingSent) {
      _isTypingSent = true;
      ref.read(chatRepositoryProvider).setTyping(widget.conversationId, uid, true);
    }
    _typingStopTimer = Timer(const Duration(seconds: 3), () {
      _isTypingSent = false;
      ref.read(chatRepositoryProvider).setTyping(widget.conversationId, uid, false);
    });
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
    _typingStopTimer?.cancel();
    final uid = ref.read(currentUserIdProvider);
    if (_isTypingSent) {
      _isTypingSent = false;
      unawaited(ref.read(chatRepositoryProvider).setTyping(widget.conversationId, uid, false));
    }
    try {
      await ref.read(chatRepositoryProvider).sendText(widget.conversationId, uid, text);
      HapticFeedback.lightImpact();
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
      HapticFeedback.lightImpact();
      ref.read(analyticsRepositoryProvider).logEvent('message_sent', params: {'type': 'image'});
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Microphone permission is needed to send a voice note.')));
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() {
        _isRecording = true;
        _recordingElapsed = Duration.zero;
      });
      _recordingTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        setState(() => _recordingElapsed += const Duration(milliseconds: 200));
        // A voice note this long would be an odd chat message and an odd
        // Storage bill — cut it off rather than let it grow unbounded.
        if (_recordingElapsed >= _maxRecordingDuration) _stopAndSendRecording();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't start recording. Please try again.")));
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTicker?.cancel();
    try {
      await _audioRecorder.cancel();
    } catch (_) {
      // Best-effort — the goal (stop recording, discard it) is met either
      // way; nothing left to surface to the user over a cancel.
    }
    if (mounted) setState(() => _isRecording = false);
  }

  Future<void> _stopAndSendRecording() async {
    _recordingTicker?.cancel();
    final elapsed = _recordingElapsed;
    setState(() {
      _isRecording = false;
      _isSendingRecording = true;
    });
    try {
      final path = await _audioRecorder.stop();
      if (path == null || elapsed.inMilliseconds < 500) {
        // Too short to be a real voice note (e.g. an accidental tap) —
        // silently discard rather than send an empty/near-empty clip.
        return;
      }
      final uid = ref.read(currentUserIdProvider);
      final String audioUrl;
      if (kUseFirebase) {
        audioUrl = await FirebaseStorageUploader().uploadChatAudio(widget.conversationId, uid, File(path));
      } else {
        // No Firebase project connected — same "still a real recording,
        // just kept as a local file path" story as _pickPhoto's fallback
        // in create_profile_screen.dart.
        audioUrl = path;
      }
      await ref
          .read(chatRepositoryProvider)
          .sendAudio(widget.conversationId, uid, audioUrl, durationSec: elapsed.inSeconds.clamp(1, 999));
      HapticFeedback.lightImpact();
      ref.read(analyticsRepositoryProvider).logEvent('message_sent', params: {'type': 'audio'});
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Couldn't send that voice note. Please try again.")));
      }
    } finally {
      if (mounted) setState(() => _isSendingRecording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(chatUnlockedProvider);
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
                    style: TextStyle(
                      fontSize: 11,
                      color: typing ? AppColors.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
                ? Center(
                    child: Text('Say hi 👋', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))
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
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('typing…',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              ),
            ),
          if (_isRecording)
            _RecordingBar(elapsed: _recordingElapsed, onCancel: _cancelRecording, onSend: _stopAndSendRecording)
          else
            _Composer(
              controller: _textController,
              onSend: _sendText,
              onPickImage: _pickImage,
              onChanged: _onComposerChanged,
              onStartRecording: _isSendingRecording ? null : _startRecording,
              isSendingRecording: _isSendingRecording,
            ),
        ],
      ),
    );
  }

  void _handleMenu(String action, Profile profile) async {
    final uid = ref.read(currentUserIdProvider);
    if (action == 'block') {
      try {
        await ref.read(socialRepositoryProvider).block(uid, profile.id);
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } else if (action == 'report') {
      // showReportSheet has its own try/catch around onSubmit.
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
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = isMe ? AppColors.primary : colorScheme.surfaceContainerHighest;
    final textColor = isMe ? Colors.white : colorScheme.onSurface;

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
                : message.isAudio
                    ? VoiceNoteBubble(
                        audioUrl: message.audioUrl!,
                        durationSec: message.audioDurationSec ?? 0,
                        color: textColor,
                      )
                    : Text(message.text ?? '', style: TextStyle(color: textColor)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_formatTime(message.sentAt), style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10)),
                if (showReadReceipt) ...[
                  const SizedBox(width: 4),
                  Icon(message.read ? Icons.done_all : Icons.done,
                      size: 12, color: message.read ? AppColors.primary : colorScheme.onSurfaceVariant),
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
  final ValueChanged<String> onChanged;
  final VoidCallback? onStartRecording;
  final bool isSendingRecording;

  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    required this.onChanged,
    required this.onStartRecording,
    required this.isSendingRecording,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            IconButton(onPressed: onPickImage, icon: const Icon(Icons.image_outlined)),
            isSendingRecording
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(onPressed: onStartRecording, icon: const Icon(Icons.mic_none_outlined)),
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onChanged: onChanged,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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

/// Replaces [_Composer] while a voice note is being recorded — a live
/// timer plus cancel (discard) / send (stop & upload) actions, same shape
/// as WhatsApp/Bumble's own recording bar.
class _RecordingBar extends StatelessWidget {
  final Duration elapsed;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const _RecordingBar({required this.elapsed, required this.onCancel, required this.onSend});

  String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            IconButton(onPressed: onCancel, icon: const Icon(Icons.delete_outline), tooltip: 'Discard'),
            const SizedBox(width: 4),
            const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Recording… ${_format(elapsed)}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            IconButton.filled(onPressed: onSend, icon: const Icon(Icons.send), tooltip: 'Send'),
          ],
        ),
      ),
    );
  }
}
