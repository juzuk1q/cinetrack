// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

import '../../../models/watch_room.dart';

/// Disables or enables pointer events and visibility on all iframes & platform views to prevent them from intercepting clicks when dialogs open.
void setAllIframesPointerEvents(bool enabled) {
  try {
    void visit(html.Node root) {
      if (root is html.Element) {
        final tag = root.tagName.toLowerCase();
        if (tag == 'iframe' || tag == 'flt-platform-view' || tag == 'video') {
          root.style.pointerEvents = enabled ? 'auto' : 'none';
          root.style.visibility = enabled ? 'visible' : 'hidden';
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
    double? position,
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

  final _urlController = TextEditingController();
  StreamSubscription? _msgSub;
  Timer? _heartbeatTimer;

  int _selectedOnlinePlayer = 0;

  bool get canControl => widget.isHost || widget.room.allowGuestControl;

  final List<String> _onlinePlayerNames = [
    'Основной',
    'Резерв 1',
    'Резерв 2',
    'Трейлер ▶',
  ];

  String _getOnlinePlayerUrl(int index) {
    final kpId = widget.room.kinopoiskId ?? 301;
    switch (index) {
      case 0:
        return 'https://player.shortener2.link/balancer-api/iframe?token=eyJhbGciOiJIUzI1NiJ9.eyJ3ZWJTaXRlIjoiMTkwIiwiaXNzIjoiYXBpLXdlYm1hc3RlciIsInN1YiI6IjI1OCIsImlhdCI6MTc1MzIwOTE0NiwianRpIjoiNjhmZGRhNjUtMmRhYi00ZDNlLWI1YzAtOGZiYjM4MjQyNzcwIiwic2NvcGUiOiJETEUifQ.aV02rM2AtHrgNsKzL9ft9jElwWv7VJsm0UAEbz57MN0&kp=$kpId';
      case 1:
        return 'https://kinobox.tv/embed/kp/$kpId';
      case 2:
        return 'https://4h0y.gitlab.io/#$kpId';
      case 3:
        return 'https://widgets.kinopoisk.ru/discovery/trailer/$kpId?no_top_panel=true';
      default:
        return 'https://player.shortener2.link/balancer-api/iframe?token=eyJhbGciOiJIUzI1NiJ9.eyJ3ZWJTaXRlIjoiMTkwIiwiaXNzIjoiYXBpLXdlYm1hc3RlciIsInN1YiI6IjI1OCIsImlhdCI6MTc1MzIwOTE0NiwianRpIjoiNjhmZGRhNjUtMmRhYi00ZDNlLWI1YzAtOGZiYjM4MjQyNzcwIiwic2NvcGUiOiJETEUifQ.aV02rM2AtHrgNsKzL9ft9jElwWv7VJsm0UAEbz57MN0&kp=$kpId';
    }
  }

  void _switchOnlinePlayer(int index) {
    if (!canControl) return;
    setState(() => _selectedOnlinePlayer = index);
    final url = _getOnlinePlayerUrl(index);
    _iframeElement?.src = url;
    widget.onBroadcastSync(
      action: 'SOURCE_CHANGE',
      sourceType: _sourceType,
      url: url,
      kinopoiskId: widget.room.kinopoiskId,
    );
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
      if (widget.isDialogOpen) {
        _iframeElement?.style.visibility = 'hidden';
        _videoElement?.style.visibility = 'hidden';
      } else {
        _iframeElement?.style.visibility = 'visible';
        _videoElement?.style.visibility = 'visible';
      }
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
      if (_videoElement != null && _videoUrl != null && _videoUrl!.isNotEmpty) {
        if (_videoElement!.src != _videoUrl) {
          _videoElement!.src = _videoUrl!;
          _videoElement!.load();
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
      _sourceType == 'url' || _sourceType == 'file';

  String _determineIframeSrc() {
    if (_sourceType == 'catalog' || _sourceType == 'kodik') {
      return _getOnlinePlayerUrl(_selectedOnlinePlayer);
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
      _videoElement!.src = _videoUrl!;
    }

    _videoElement!.onLoadedMetadata.listen((_) {
      if (mounted) {
        setState(() {
          _duration = _videoElement!.duration.toDouble();
        });
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
      if (widget.isHost) {
        widget.onBroadcastSync(
          action: 'PLAY',
          position: _videoElement!.currentTime.toDouble(),
        );
      }
    });

    _videoElement!.onPause.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
      if (widget.isHost) {
        widget.onBroadcastSync(
          action: 'PAUSE',
          position: _videoElement!.currentTime.toDouble(),
        );
      }
    });

    _videoElement!.onSeeked.listen((_) {
      if (widget.isHost) {
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
      ..setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-forms allow-presentation allow-popups allow-popups-to-escape-sandbox allow-top-navigation-by-user-activation',
      )
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
      if (event.data is Map && event.data['key'] == 'kodik_player_api') {
        final val = event.data['value'];
        if (val is Map) {
          final action = val['action'] as String?;
          final time = (val['time'] as num?)?.toDouble() ?? 0.0;

          if (widget.isHost && action != null) {
            if (action == 'kodik_player_play') {
              widget.onBroadcastSync(action: 'PLAY', position: time);
            } else if (action == 'kodik_player_pause') {
              widget.onBroadcastSync(action: 'PAUSE', position: time);
            } else if (action == 'kodik_player_seek') {
              widget.onBroadcastSync(action: 'SEEK', position: time);
            }
          }
        }
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!widget.isHost || !mounted) return;

      if (_isVideoElementSource && _videoElement != null && _isPlaying) {
        widget.onBroadcastSync(
          action: 'HEARTBEAT',
          position: _videoElement!.currentTime.toDouble(),
        );
      }
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
    double? position,
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
        } else if (_isIframeSource && url != null && _iframeElement != null) {
          _iframeElement!.src = url;
        }
      }
      return;
    }

    if (_sourceType == 'catalog' || _sourceType == 'kodik') {
      if (action == 'PLAY') {
        _sendIframeCommand('play');
      } else if (action == 'PAUSE') {
        _sendIframeCommand('pause');
      } else if (action == 'SEEK' && position != null) {
        _sendIframeCommand('seek', position);
      }
      return;
    }

    // HTML5 Video Sync
    if (_videoElement == null) return;

    switch (action) {
      case 'PLAY':
        if (position != null) {
          final diff = (_videoElement!.currentTime - position).abs();
          if (diff > 0.5) _videoElement!.currentTime = position;
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
          final diff = (_videoElement!.currentTime - position).abs();
          if (diff > 2.0) {
            _videoElement!.currentTime = position;
          }
        }
        break;
    }
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

    if (_sourceType == 'catalog' || _sourceType == 'kodik') {
      _sendIframeCommand(_isPlaying ? 'pause' : 'play');
      setState(() => _isPlaying = !_isPlaying);
      widget.onBroadcastSync(
        action: _isPlaying ? 'PLAY' : 'PAUSE',
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

    if (_sourceType == 'catalog' || _sourceType == 'kodik') {
      final target = (_currentTime + deltaSeconds).clamp(0.0, _duration);
      _sendIframeCommand('seek', target);
      widget.onBroadcastSync(action: 'SEEK', position: target);
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
            title: 'YouTube',
            subtitle:
                'Для участников из России видео может требовать включенного VPN',
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
                      // 1. The Player View (Unobstructed full click area)
                      Positioned.fill(
                        child: widget.isDialogOpen
                            ? Container(
                                color: const Color(0xFF0F0F1A),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.tune_rounded,
                                          color: Color(0xFF9F67FF), size: 36),
                                      const SizedBox(height: 10),
                                      Text(
                                        widget.room.movieTitle,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Диалоговое окно активно...',
                                        style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : (_isIframeSource
                                ? HtmlElementView(
                                    key: ValueKey(
                                        'iframe-$_sourceType-${widget.room.kinopoiskId}-$_selectedOnlinePlayer-$_videoUrl'),
                                    viewType: _iframeViewId,
                                  )
                                : (_videoUrl != null && _videoUrl!.isNotEmpty)
                                    ? HtmlElementView(
                                        key: ValueKey('video-$_videoUrl'),
                                        viewType: _videoViewId,
                                      )
                                    : _buildEmptyFilePlaceholder()),
                      ),

                      // 2. Custom Controls Overlay (only for HTML5 video/file)
                      if (_isVideoElementSource &&
                          _videoUrl != null &&
                          _videoUrl!.isNotEmpty &&
                          !widget.isDialogOpen)
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
                    widget.isFullscreen ? 'Свернуть' : 'На весь экран ⛶',
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
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: List.generate(_onlinePlayerNames.length, (i) {
              final isSel = _selectedOnlinePlayer == i;
              return InkWell(
                onTap: canControl ? () => _switchOnlinePlayer(i) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSel
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF232338),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel ? const Color(0xFFF59E0B) : Colors.white12,
                    ),
                  ),
                  child: Text(
                    _onlinePlayerNames[i],
                    style: TextStyle(
                      color: isSel ? Colors.black : Colors.white,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }),
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
                    ? '👑 Пульт у вас'
                    : (canControl ? '👥 Пульт у всех' : '🔒 Синхронизировано'),
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
                  widget.isFullscreen ? 'Обычный' : 'Во весь экран ⛶',
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
                        if (_videoElement != null) {
                          _videoElement!.currentTime = val;
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
