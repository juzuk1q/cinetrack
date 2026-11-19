// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

import '../../../models/watch_room.dart';
import '../../../services/video_balancer_service.dart';

/// Disables or enables pointer events and visibility on all iframes & platform views to prevent them from intercepting clicks when dialogs open.
void setAllIframesPointerEvents(bool enabled) {
  try {
    void visit(html.Node root) {
      if (root is html.Element) {
        final tag = root.tagName.toLowerCase();
        if (tag == 'iframe' || tag == 'flt-platform-view' || tag == 'video') {
          root.style.pointerEvents = enabled ? 'auto' : 'none';
        }
        final shadow = root.shadowRoot;
        if (shadow != null) {
          visit(shadow);
        }
      }
      for (final child in root.childNodes) {
        visit(child);
      }
    }

    final body = html.document.body;
    if (body != null) visit(body);
    final docEl = html.document.documentElement;
    if (docEl != null) visit(docEl);
  } catch (e) {
    debugPrint('Error setting iframe pointer events: $e');
  }
}

class RoomSyncPlayer extends StatefulWidget {
  final WatchRoom room;
  final bool isHost;
  final VoidCallback? onChangeSourceRequested;
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;
  final bool isDialogOpen;
  final void Function({
    required String action,
    String? state,
    double? position,
    int? sentAt,
    String? sourceType,
    String? url,
    String? fileName,
    String? movieTitle,
    String? moviePoster,
    int? kinopoiskId,
  }) onBroadcastSync;

  const RoomSyncPlayer({
    super.key,
    required this.room,
    required this.isHost,
    required this.onBroadcastSync,
    this.onChangeSourceRequested,
    this.onToggleFullscreen,
    this.isFullscreen = false,
    this.isDialogOpen = false,
  });

  @override
  State<RoomSyncPlayer> createState() => RoomSyncPlayerState();
}

class RoomSyncPlayerState extends State<RoomSyncPlayer> {
  late String _sourceType; // 'catalog', 'kodik', 'vk', 'youtube', 'url', 'file', 'none'
  String? _videoUrl;
  String? _localFileName;

  // HTML Elements for Video and Iframes
  late String _videoViewId;
  late String _iframeViewId;
  html.VideoElement? _videoElement;
  html.IFrameElement? _iframeElement;

  // Video State
  bool _isPlaying = false;
  double _currentTime = 0.0;
  double _duration = 0.0;
  bool _isMuted = false;
  bool _isDraggingSlider = false;
  bool _isApplyingRemoteSync = false;

  bool get isPlaying => _isPlaying;

  final _urlController = TextEditingController();
  StreamSubscription? _msgSub;
  Timer? _heartbeatTimer;

  String _selectedBalancerId = 'primary_balancer';

  bool get canControl => widget.isHost || widget.room.allowGuestControl;

  List<BalancerSource> get _availableBalancers {
    final kpId = widget.room.kinopoiskId ?? 301;
    final isDirect = _sourceType == 'url' || _sourceType == 'hls';
    return VideoBalancerService.getSources(
      kpId: kpId,
      customDirectUrl: isDirect ? _videoUrl : null,
    );
  }

  void _selectBalancer(BalancerSource balancer) {
    if (!canControl) return;
    setState(() {
      _selectedBalancerId = balancer.id;
      if (balancer.isDirectStream) {
        _sourceType = balancer.type == BalancerType.hls ? 'hls' : 'url';
        _videoUrl = balancer.url;
      } else {
        _sourceType = 'catalog';
        _videoUrl = balancer.url;
      }
    });

    _updateElementsSrc();

    widget.onBroadcastSync(
      action: 'SOURCE_CHANGE',
      sourceType: _sourceType,
      url: balancer.url,
      kinopoiskId: widget.room.kinopoiskId,
    );
  }

  void _switchOnlinePlayer(int index) {
    final balancers = _availableBalancers;
    if (index >= 0 && index < balancers.length) {
      _selectBalancer(balancers[index]);
    }
  }

  @override
  void initState() {
    super.initState();
    _sourceType = widget.room.videoSourceType;
    if (_sourceType == 'kinopoisk' ||
        (_sourceType == 'none' && widget.room.kinopoiskId != null)) {
      _sourceType = 'catalog';
    }
    _videoUrl = widget.room.videoUrl;
    _localFileName = widget.room.videoFileName;
    _currentTime = widget.room.currentPosition;
    _isPlaying = widget.room.isPlaying;

    if (_videoUrl != null) {
      _urlController.text = _videoUrl!;
    }

    final uniqueSuffix = DateTime.now().microsecondsSinceEpoch.toString();
    _videoViewId = 'cinetrack-video-$uniqueSuffix';
    _iframeViewId = 'cinetrack-iframe-$uniqueSuffix';

    _initVideoElement();
    _initIframeElement();
    _listenIframeMessages();

    if (widget.isHost) {
      _startHeartbeat();
    }
  }

  @override
  void didUpdateWidget(covariant RoomSyncPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDialogOpen != widget.isDialogOpen) {
      final pe = widget.isDialogOpen ? 'none' : 'auto';
      _iframeElement?.style.pointerEvents = pe;
      _videoElement?.style.pointerEvents = pe;
    }

    if (oldWidget.room.videoSourceType != widget.room.videoSourceType ||
        oldWidget.room.videoUrl != widget.room.videoUrl ||
        oldWidget.room.kinopoiskId != widget.room.kinopoiskId) {
      setState(() {
        _sourceType = widget.room.videoSourceType;
        _videoUrl = widget.room.videoUrl;
        _localFileName = widget.room.videoFileName;
        if (_videoUrl != null) {
          _urlController.text = _videoUrl!;
        }
      });
      _updateElementsSrc();
    }
  }

  void _updateElementsSrc() {
    if (_isIframeSource) {
      _videoElement?.pause();
      final src = _determineIframeSrc();
      if (_iframeElement != null && src.isNotEmpty) {
        _iframeElement!.referrerPolicy = 'strict-origin-when-cross-origin';
        _iframeElement!.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
        _iframeElement!.src = src;
      }
    } else if (_isVideoElementSource) {
      if (_iframeElement != null) {
        _iframeElement!.src = 'about:blank';
      }
      if (_videoElement != null && _videoUrl != null && _videoUrl!.isNotEmpty) {
        if (VideoBalancerService.isHlsUrl(_videoUrl)) {
          try {
            js.context.callMethod('attachHlsToVideo', [_videoElement, _videoUrl]);
          } catch (_) {
            _videoElement!.src = _videoUrl!;
          }
        } else {
          if (_videoElement!.src != _videoUrl) {
            _videoElement!.src = _videoUrl!;
            _videoElement!.load();
          }
        }
      }
    }
  }

  bool get _isIframeSource =>
      _sourceType == 'catalog' ||
      _sourceType == 'kodik' ||
      _sourceType == 'vk' ||
      _sourceType == 'youtube';

  bool get _isVideoElementSource =>
      _sourceType == 'url' || _sourceType == 'file' || _sourceType == 'hls';

  String _determineIframeSrc() {
    if (_sourceType == 'catalog' || _sourceType == 'kodik') {
      final balancers = _availableBalancers;
      final selected = balancers.firstWhere(
        (b) => b.id == _selectedBalancerId,
        orElse: () => balancers.firstWhere((b) => !b.isDirectStream, orElse: () => balancers.first),
      );
      return selected.url;
    }
    if (_sourceType == 'youtube') {
      var url = _videoUrl ?? '';
      if (!url.contains('enablejsapi=1')) {
        final sep = url.contains('?') ? '&' : '?';
        url =
            '$url${sep}enablejsapi=1&origin=${html.window.location.origin}&playsinline=1&controls=1&rel=0';
      }
      return url;
    }
    return _videoUrl ?? '';
  }

  void _initVideoElement() {
    _videoElement = html.VideoElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#0A0A14'
      ..style.objectFit = 'contain'
      ..autoplay = false
      ..controls = false
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true');

    if (_videoUrl != null && _videoUrl!.isNotEmpty && _isVideoElementSource) {
      if (VideoBalancerService.isHlsUrl(_videoUrl)) {
        try {
          js.context.callMethod('attachHlsToVideo', [_videoElement, _videoUrl]);
        } catch (_) {
          _videoElement!.src = _videoUrl!;
        }
      } else {
        _videoElement!.src = _videoUrl!;
      }
    }

    _videoElement!.onLoadedMetadata.listen((_) {
      if (mounted) {
        setState(() {
          _duration = _videoElement!.duration.toDouble();
        });
        if (_currentTime > 0) {
          _videoElement!.currentTime = _currentTime;
        }
        if (_isPlaying) {
          _videoElement!.play();
        }
      }
    });

    _videoElement!.onTimeUpdate.listen((_) {
      if (!_isDraggingSlider && mounted) {
        setState(() {
          _currentTime = _videoElement!.currentTime.toDouble();
        });
      }
    });

    _videoElement!.onPlay.listen((_) {
      if (mounted) setState(() => _isPlaying = true);
      if (_isApplyingRemoteSync) return;
      if (canControl) {
        widget.onBroadcastSync(
          action: 'PLAY',
          state: 'play',
          position: _videoElement!.currentTime.toDouble(),
        );
      }
    });

    _videoElement!.onPause.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
      if (_isApplyingRemoteSync) return;
      if (canControl) {
        widget.onBroadcastSync(
          action: 'PAUSE',
          state: 'pause',
          position: _videoElement!.currentTime.toDouble(),
        );
      }
    });

    _videoElement!.onSeeked.listen((_) {
      if (_isApplyingRemoteSync) return;
      if (canControl) {
        widget.onBroadcastSync(
          action: 'SEEK',
          position: _videoElement!.currentTime.toDouble(),
        );
      }
    });

    ui_web.platformViewRegistry.registerViewFactory(
      _videoViewId,
      (int viewId) => _videoElement!,
    );
  }

  void _initIframeElement() {
    final iframeSrc = _determineIframeSrc();

    _iframeElement = html.IFrameElement()
      ..src = iframeSrc
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#0A0A14'
      ..allow =
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share; fullscreen'
      ..referrerPolicy = 'strict-origin-when-cross-origin'
      ..setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');

    ui_web.platformViewRegistry.registerViewFactory(
      _iframeViewId,
      (int viewId) => _iframeElement!,
    );
  }

  void _listenIframeMessages() {
    _msgSub = html.window.onMessage.listen((event) {
      if (_isApplyingRemoteSync) return;
      if (!canControl) return;

      // 1. Kodik Player API
      if (event.data is Map && event.data['key'] == 'kodik_player_api') {
        final val = event.data['value'];
        if (val is Map) {
          final action = val['action'] as String?;
          final time = (val['time'] as num?)?.toDouble() ?? 0.0;
          _currentTime = time;

          if (action == 'kodik_player_play') {
            _isPlaying = true;
            widget.onBroadcastSync(action: 'PLAY', state: 'play', position: time);
          } else if (action == 'kodik_player_pause') {
            _isPlaying = false;
            widget.onBroadcastSync(action: 'PAUSE', state: 'pause', position: time);
          } else if (action == 'kodik_player_seek') {
            widget.onBroadcastSync(action: 'SEEK', position: time);
          } else if (action == 'kodik_player_time_update') {
            _currentTime = time;
          }
        }
      }

      // 2. YouTube IFrame Player API (postMessage)
      if (_sourceType == 'youtube') {
        try {
          dynamic data = event.data;
          if (data is String && data.startsWith('{') && data.contains('event')) {
            data = jsonDecode(data);
          }
          if (data is Map) {
            final ev = data['event'];
            if (ev == 'infoDelivery' && data['info'] is Map) {
              final info = data['info'] as Map;
              if (info['currentTime'] is num) {
                _currentTime = (info['currentTime'] as num).toDouble();
              }
              if (info['duration'] is num) {
                _duration = (info['duration'] as num).toDouble();
              }
              if (info['playerState'] is int) {
                final state = info['playerState'] as int;
                if (state == 1 && !_isPlaying) {
                  _isPlaying = true;
                  widget.onBroadcastSync(action: 'PLAY', state: 'play', position: _currentTime);
                } else if (state == 2 && _isPlaying) {
                  _isPlaying = false;
                  widget.onBroadcastSync(action: 'PAUSE', state: 'pause', position: _currentTime);
                }
              }
            } else if (ev == 'onStateChange' && data['data'] is int) {
              final state = data['data'] as int;
              if (state == 1 && !_isPlaying) {
                _isPlaying = true;
                widget.onBroadcastSync(action: 'PLAY', state: 'play', position: _currentTime);
              } else if (state == 2 && _isPlaying) {
                _isPlaying = false;
                widget.onBroadcastSync(action: 'PAUSE', state: 'pause', position: _currentTime);
              }
            }
          }
        } catch (_) {}
      }
    });
  }

  double _getCurrentTime() {
    if (_isVideoElementSource && _videoElement != null) {
      return _videoElement!.currentTime.toDouble();
    }
    return _currentTime;
  }

  void _sendYoutubeCommand(String func, [dynamic args = '']) {
    try {
      final msg = jsonEncode({
        'event': 'command',
        'func': func,
        'args': args is List ? args : [args],
      });
      _iframeElement?.contentWindow?.postMessage(msg, '*');
    } catch (e) {
      debugPrint('Error sending YouTube command: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!widget.isHost || !mounted) return;
      widget.onBroadcastSync(
        action: 'HEARTBEAT',
        state: _isPlaying ? 'play' : 'pause',
        position: _getCurrentTime(),
      );
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _msgSub?.cancel();
    _urlController.dispose();
    _videoElement?.pause();
    _videoElement?.src = '';
    super.dispose();
  }

  /// Called from room_detail_screen when a remote Supabase broadcast arrives
  void applyRemoteSync({
    required String action,
    String? state,
    double? position,
    int? sentAt,
    String? sourceType,
    String? url,
    String? fileName,
  }) {
    if (!mounted) return;

    if (action == 'SOURCE_CHANGE') {
      if (sourceType != null) {
        setState(() {
          _sourceType = sourceType;
          if (url != null) {
            _videoUrl = url;
            _urlController.text = url;
          }
          if (fileName != null) {
            _localFileName = fileName;
          }
        });

        if (_isVideoElementSource && url != null && _videoElement != null) {
          _videoElement!.src = url;
          _videoElement!.load();
        } else if (_isIframeSource && _iframeElement != null) {
          _iframeElement!.src = _determineIframeSrc();
        }
      }
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final latencySec =
        sentAt != null ? ((now - sentAt).clamp(0, 10000)) / 1000.0 : 0.0;
    double targetPos = position ?? _getCurrentTime();
    if (action == 'PLAY' || state == 'play') {
      targetPos += latencySec;
    }

    // --- YouTube Sync ---
    if (_sourceType == 'youtube') {
      _isApplyingRemoteSync = true;
      if (action == 'PLAY') {
        if (targetPos > 0) {
          final diff = (_currentTime - targetPos).abs();
          if (diff > 0.6) {
            _sendYoutubeCommand('seekTo', [targetPos, true]);
            _currentTime = targetPos;
          }
        }
        _sendYoutubeCommand('playVideo');
        _isPlaying = true;
      } else if (action == 'PAUSE') {
        if (position != null) {
          final diff = (_currentTime - position).abs();
          if (diff > 0.6) {
            _sendYoutubeCommand('seekTo', [position, true]);
            _currentTime = position;
          }
        }
        _sendYoutubeCommand('pauseVideo');
        _isPlaying = false;
      } else if (action == 'SEEK' && position != null) {
        _sendYoutubeCommand('seekTo', [position, true]);
        _currentTime = position;
      } else if (action == 'HEARTBEAT' && position != null) {
        final expected = position + (state == 'play' ? latencySec : 0.0);
        final diff = (_currentTime - expected).abs();
        if (diff > 1.8) {
          _sendYoutubeCommand('seekTo', [expected, true]);
          _currentTime = expected;
        }
        if (state == 'play' && !_isPlaying) {
          _sendYoutubeCommand('playVideo');
          _isPlaying = true;
        } else if (state == 'pause' && _isPlaying) {
          _sendYoutubeCommand('pauseVideo');
          _isPlaying = false;
        }
      }
      setState(() {});
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _isApplyingRemoteSync = false;
      });
      return;
    }

    // --- Kodik / Catalog Sync ---
    if (_sourceType == 'catalog' || _sourceType == 'kodik') {
      _isApplyingRemoteSync = true;
      if (action == 'PLAY') {
        if (targetPos > 0) {
          final diff = (_currentTime - targetPos).abs();
          if (diff > 0.6) {
            _sendIframeCommand('seek', targetPos);
            _currentTime = targetPos;
          }
        }
        _sendIframeCommand('play');
        _isPlaying = true;
      } else if (action == 'PAUSE') {
        if (position != null) {
          final diff = (_currentTime - position).abs();
          if (diff > 0.6) {
            _sendIframeCommand('seek', position);
            _currentTime = position;
          }
        }
        _sendIframeCommand('pause');
        _isPlaying = false;
      } else if (action == 'SEEK' && position != null) {
        _sendIframeCommand('seek', position);
        _currentTime = position;
      } else if (action == 'HEARTBEAT' && position != null) {
        final expected = position + (state == 'play' ? latencySec : 0.0);
        final diff = (_currentTime - expected).abs();
        if (diff > 2.0) {
          _sendIframeCommand('seek', expected);
          _currentTime = expected;
        }
        if (state == 'play' && !_isPlaying) {
          _sendIframeCommand('play');
          _isPlaying = true;
        } else if (state == 'pause' && _isPlaying) {
          _sendIframeCommand('pause');
          _isPlaying = false;
        }
      }
      setState(() {});
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _isApplyingRemoteSync = false;
      });
      return;
    }

    // --- HTML5 Video Sync ---
    if (_videoElement == null) return;
    _isApplyingRemoteSync = true;
    switch (action) {
      case 'PLAY':
        if (targetPos > 0) {
          final diff = (_videoElement!.currentTime - targetPos).abs();
          if (diff > 0.5) _videoElement!.currentTime = targetPos;
        }
        _videoElement!.play();
        setState(() => _isPlaying = true);
        break;

      case 'PAUSE':
        if (position != null) {
          final diff = (_videoElement!.currentTime - position).abs();
          if (diff > 0.5) _videoElement!.currentTime = position;
        }
        _videoElement!.pause();
        setState(() => _isPlaying = false);
        break;

      case 'SEEK':
        if (position != null) {
          _videoElement!.currentTime = position;
        }
        break;

      case 'HEARTBEAT':
        if (position != null) {
          final expected = position + (state == 'play' ? latencySec : 0.0);
          final diff = (_videoElement!.currentTime - expected).abs();
          if (diff > 1.5) {
            _videoElement!.currentTime = expected;
          }
          if (state == 'play' && !_isPlaying) {
            _videoElement!.play();
            setState(() => _isPlaying = true);
          } else if (state == 'pause' && _isPlaying) {
            _videoElement!.pause();
            setState(() => _isPlaying = false);
          }
        }
        break;
    }
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _isApplyingRemoteSync = false;
    });
  }

  void _sendIframeCommand(String action, [double? time]) {
    _iframeElement?.contentWindow?.postMessage(
      {
        'key': 'kodik_player_api',
        'value': {
          'action': action,
          if (time != null) 'time': time,
        }
      },
      '*',
    );
  }

  void _pickLocalFile() {
    final uploadInput = html.FileUploadInputElement()
      ..accept = 'video/*,video/mp4,video/webm,video/x-matroska';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final blobUrl = html.Url.createObjectUrl(file);

        setState(() {
          _videoUrl = blobUrl;
          _localFileName = file.name;
          _sourceType = 'file';
        });

        if (_videoElement != null) {
          _videoElement!.src = blobUrl;
          _videoElement!.load();
          _videoElement!.play();
        }

        widget.onBroadcastSync(
          action: 'SOURCE_CHANGE',
          sourceType: 'file',
          fileName: file.name,
        );
      }
    });
  }

  void _togglePlayPause() {
    if (!canControl) return;

    if (_sourceType == 'youtube') {
      if (_isPlaying) {
        _sendYoutubeCommand('pauseVideo');
        _isPlaying = false;
        widget.onBroadcastSync(
          action: 'PAUSE',
          state: 'pause',
          position: _currentTime,
        );
      } else {
        _sendYoutubeCommand('playVideo');
        _isPlaying = true;
        widget.onBroadcastSync(
          action: 'PLAY',
          state: 'play',
          position: _currentTime,
        );
      }
      setState(() {});
      return;
    }

    if (_sourceType == 'catalog' || _sourceType == 'kodik') {
      _sendIframeCommand(_isPlaying ? 'pause' : 'play');
      setState(() => _isPlaying = !_isPlaying);
      widget.onBroadcastSync(
        action: _isPlaying ? 'PLAY' : 'PAUSE',
        state: _isPlaying ? 'play' : 'pause',
        position: _currentTime,
      );
      return;
    }

    if (_videoElement == null) return;
    if (_isPlaying) {
      _videoElement!.pause();
    } else {
      _videoElement!.play();
    }
  }

  void _seekBy(double deltaSeconds) {
    if (!canControl) return;

    if (_sourceType == 'youtube') {
      final target = (_currentTime + deltaSeconds)
          .clamp(0.0, _duration > 0 ? _duration : 10000.0);
      _sendYoutubeCommand('seekTo', [target, true]);
      _currentTime = target;
      widget.onBroadcastSync(action: 'SEEK', position: target);
      setState(() {});
      return;
    }

    if (_sourceType == 'catalog' || _sourceType == 'kodik') {
      final target = (_currentTime + deltaSeconds)
          .clamp(0.0, _duration > 0 ? _duration : 10000.0);
      _sendIframeCommand('seek', target);
      _currentTime = target;
      widget.onBroadcastSync(action: 'SEEK', position: target);
      setState(() {});
      return;
    }

    if (_videoElement == null) return;
    final target =
        (_videoElement!.currentTime + deltaSeconds).clamp(0.0, _duration);
    _videoElement!.currentTime = target;
  }

  void _toggleMute() {
    if (_videoElement == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _videoElement!.muted = _isMuted;
    });
  }

  void _toggleFullscreen() {
    if (widget.onToggleFullscreen != null) {
      widget.onToggleFullscreen!();
      return;
    }
    if (html.document.fullscreenElement == null) {
      _videoElement?.requestFullscreen();
    } else {
      html.document.exitFullscreen();
    }
  }

  String _formatDuration(double seconds) {
    final total = seconds.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tabs for Catalog / Online player (Lordfilm style)
        if (_sourceType == 'catalog' || _sourceType == 'kodik') ...[
          _buildLordfilmPlayerTabs(),
          const SizedBox(height: 8),
          _buildAdNoticeBadge(),
          const SizedBox(height: 10),
        ],

        // Source notification banner for VK and YouTube
        if (_sourceType == 'vk') ...[
          _buildSourceBanner(
            icon: Icons.play_circle_fill_rounded,
            iconColor: const Color(0xFF0077FF),
            title: 'VK Видео',
            subtitle:
                'Воспроизведение через официальный плеер ВКонтакте (без ограничений в РФ)',
          ),
          const SizedBox(height: 10),
        ],

        if (_sourceType == 'youtube') ...[
          _buildSourceBanner(
            icon: Icons.smart_display_rounded,
            iconColor: const Color(0xFFEF4444),
            title: 'YouTube (IFrame Player API)',
            subtitle:
                'Синхронизация через postMessage API. Полный контроль воспроизведения и перемотки без рекламы.',
          ),
          const SizedBox(height: 10),
        ],

        // Video Player Container (Compact centered width in normal mode, full width in fullscreen)
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.isFullscreen ? double.infinity : 980,
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: const Color(0xFF0A0A14),
                  child: Stack(
                    children: [
                      // 1. The Player View (Permanently mounted so iframe never reloads on modal dialogs)
                      Positioned.fill(
                        child: _isIframeSource
                            ? HtmlElementView(
                                key: ValueKey('iframe-$_iframeViewId'),
                                viewType: _iframeViewId,
                              )
                            : (_videoUrl != null && _videoUrl!.isNotEmpty)
                                ? HtmlElementView(
                                    key: ValueKey('video-$_videoViewId'),
                                    viewType: _videoViewId,
                                  )
                                : _buildEmptyFilePlaceholder(),
                      ),

                      // Transparent barrier overlay when dialog is open
                      if (widget.isDialogOpen)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                        ),

                      // 2. Custom Controls Overlay
                      if (!widget.isDialogOpen &&
                          ((_isVideoElementSource &&
                                  _videoUrl != null &&
                                  _videoUrl!.isNotEmpty) ||
                              _sourceType == 'youtube' ||
                              _sourceType == 'catalog' ||
                              _sourceType == 'kodik'))
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _buildControlsBar(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Fallback helper bar for online players when movie is locked or blocked
        if (_sourceType == 'catalog' || _sourceType == 'kodik') ...[
          const SizedBox(height: 10),
          _buildFallbackBar(),
        ],

        const SizedBox(height: 12),

        // File notice for local files
        if (_sourceType == 'file') _buildFileNoticeBar(),
      ],
    );
  }

  Widget _buildFallbackBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E34),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.help_outline_rounded,
                    color: Color(0xFFF59E0B), size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Видео недоступно или заблокировано?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (canControl) ...[
                InkWell(
                  onTap: () => _switchOnlinePlayer(1),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded,
                            size: 13, color: Color(0xFFA78BFA)),
                        SizedBox(width: 4),
                        Text(
                          'Плеер VideoCDN',
                          style: TextStyle(
                            color: Color(0xFFA78BFA),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _switchOnlinePlayer(2),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded,
                            size: 13, color: Color(0xFF34D399)),
                        SizedBox(width: 4),
                        Text(
                          'Плеер Yohoho',
                          style: TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (widget.onChangeSourceRequested != null && canControl)
                InkWell(
                  onTap: widget.onChangeSourceRequested,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0077FF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF0077FF).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_rounded,
                            size: 13, color: Color(0xFF60A5FA)),
                        SizedBox(width: 4),
                        Text(
                          'Найти в VK / YouTube',
                          style: TextStyle(
                            color: Color(0xFF60A5FA),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdNoticeBadge() {
    if (_isVideoElementSource) {
      final isHls = VideoBalancerService.isHlsUrl(_videoUrl);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isHls
                    ? 'Прямой HLS стрим: нативное воспроизведение через движок HLS.js без рекламы с точной синхронизацией!'
                    : 'Прямой MP4 поток: нативный HTML5 плеер, 0 сторонней рекламы и субмиллисекундная синхронизация!',
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 14, color: Color(0xFFF59E0B)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Внешний балансер: реклама встроена сторонним агрегатором. Для чистого видео используйте Прямой HLS или YouTube.',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBanner({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 12, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.white60),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _toggleFullscreen,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: widget.isFullscreen
                    ? const Color(0xFF7C3AED)
                    : Colors.white12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isFullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.isFullscreen ? 'Свернуть' : 'На весь экран',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLordfilmPlayerTabs() {
    final balancers = _availableBalancers;
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: balancers.map((b) {
                final isSel = (_selectedBalancerId == b.id) ||
                    (b.isDirectStream && (_sourceType == 'url' || _sourceType == 'hls')) ||
                    (!b.isDirectStream && _sourceType == 'catalog' && _videoUrl == b.url);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: canControl ? () => _selectBalancer(b) : null,
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSel
                            ? b.accentColor.withValues(alpha: 0.22)
                            : const Color(0xFF1E1E34),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? b.accentColor : Colors.white12,
                          width: isSel ? 1.5 : 0.8,
                        ),
                        boxShadow: isSel
                            ? [
                                BoxShadow(
                                  color: b.accentColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(b.icon, size: 14, color: isSel ? b.accentColor : Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            b.name,
                            style: TextStyle(
                              color: isSel ? Colors.white : Colors.white70,
                              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? b.accentColor.withValues(alpha: 0.35)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              b.badge,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isSel ? Colors.white : Colors.white60,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Remote control indicator pill safely placed outside player viewport
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E34),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isHost
                  ? const Color(0xFF9F67FF).withValues(alpha: 0.5)
                  : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isHost
                    ? Icons.verified_user_rounded
                    : (canControl
                        ? Icons.group_outlined
                        : Icons.lock_outline_rounded),
                color: widget.isHost
                    ? const Color(0xFF9F67FF)
                    : (canControl ? const Color(0xFF10B981) : Colors.white70),
                size: 13,
              ),
              const SizedBox(width: 6),
              Text(
                widget.isHost
                    ? 'Пульт у вас'
                    : (canControl ? 'Пульт у всех' : 'Синхронизировано'),
                style: TextStyle(
                  color: widget.isHost
                      ? const Color(0xFF9F67FF)
                      : (canControl ? const Color(0xFF10B981) : Colors.white70),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Fullscreen toggle button
        InkWell(
          onTap: _toggleFullscreen,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isFullscreen
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFF7C3AED).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF9F67FF),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 5),
                Text(
                  widget.isFullscreen ? 'Обычный' : 'Во весь экран',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFilePlaceholder() {
    return Container(
      color: const Color(0xFF121224),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.video_library_rounded,
                size: 42,
                color: Color(0xFF9F67FF),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Локальный видеофайл не выбран',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isHost
                  ? 'Выберите фильм с вашего компьютера (.mp4, .webm). Видео воспроизводится мгновенно.'
                  : 'Ожидание, пока ведущий выберет видеофайл...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.white60),
            ),
            const SizedBox(height: 20),
            if (widget.isHost)
              ElevatedButton.icon(
                onPressed: _pickLocalFile,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Выбрать видео с компьютера'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileNoticeBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF18182E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF9F67FF), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _localFileName != null
                      ? 'Текущий файл: $_localFileName'
                      : 'Файл еще не выбран',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  widget.isHost
                      ? 'Вы можете сменить файл в любой момент нажатием кнопки справа.'
                      : 'Если у вас есть этот же файл на ПК, нажмите «Выбрать файл», чтобы смотреть без задержек синхронно с ведущим.',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _pickLocalFile,
            icon: const Icon(Icons.file_upload_outlined, size: 16),
            label: Text(widget.isHost ? 'Сменить файл' : 'Выбрать файл у себя'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF7C3AED)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.9),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slider
          if (_duration > 0)
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: const Color(0xFF9F67FF),
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _currentTime.clamp(0.0, _duration),
                max: _duration,
                onChanged: canControl
                    ? (val) {
                        setState(() {
                          _isDraggingSlider = true;
                          _currentTime = val;
                        });
                      }
                    : null,
                onChangeEnd: canControl
                    ? (val) {
                        _isDraggingSlider = false;
                        _currentTime = val;
                        if (_videoElement != null) {
                          _videoElement!.currentTime = val;
                        } else if (_sourceType == 'youtube') {
                          _sendYoutubeCommand('seekTo', [val, true]);
                        } else if (_sourceType == 'catalog' ||
                            _sourceType == 'kodik') {
                          _sendIframeCommand('seek', val);
                        }
                        widget.onBroadcastSync(action: 'SEEK', position: val);
                      }
                    : null,
              ),
            ),

          // Buttons Row
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: canControl ? _togglePlayPause : null,
              ),
              IconButton(
                icon: const Icon(Icons.replay_10_rounded,
                    color: Colors.white70, size: 20),
                onPressed: canControl ? () => _seekBy(-10) : null,
              ),
              IconButton(
                icon: const Icon(Icons.forward_10_rounded,
                    color: Colors.white70, size: 20),
                onPressed: canControl ? () => _seekBy(10) : null,
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatDuration(_currentTime)} / ${_formatDuration(_duration)}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: _toggleMute,
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen_rounded,
                    color: Colors.white70, size: 22),
                onPressed: _toggleFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
