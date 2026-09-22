import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Playback control for a received/sent voice note — play/pause button,
/// a thin progress bar, and the clip's length (the sender's declared
/// [durationSec] until playback starts, then the player's own position).
class VoiceNoteBubble extends StatefulWidget {
  final String audioUrl;
  final int durationSec;
  final Color color;

  const VoiceNoteBubble({super.key, required this.audioUrl, required this.durationSec, required this.color});

  @override
  State<VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<VoiceNoteBubble> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    // Reaching the end doesn't fire onPlayerStateChanged with `.playing`
    // false on every platform — reset explicitly so the button doesn't
    // stay stuck showing "pause" after a clip finishes.
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.audioUrl));
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration ?? Duration(seconds: widget.durationSec);
    final progress = total.inMilliseconds == 0 ? 0.0 : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return SizedBox(
      width: 160,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: widget.color, size: 32),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: widget.color.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation(widget.color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _format(_isPlaying || _position > Duration.zero ? _position : total),
                  style: TextStyle(color: widget.color, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
