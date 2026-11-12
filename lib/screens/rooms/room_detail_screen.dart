import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../platform/platform.dart';
import '../../data/curated_catalog.dart';
import '../../models/catalog_item.dart';
import '../../models/room_message.dart';
import '../../models/watch_room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/kinopoisk_service.dart';
import '../../services/vk_video_service.dart';
import '../../services/youtube_service.dart';
import 'widgets/room_sync_player.dart';

class _RoomToastItem {
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;

  const _RoomToastItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor = const Color(0xFF9F67FF),
  });
}

class RoomDetailScreen extends ConsumerStatefulWidget {
  final String roomId;
  const RoomDetailScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _passwordInputCtrl = TextEditingController();
  final GlobalKey<RoomSyncPlayerState> _playerKey =
      GlobalKey<RoomSyncPlayerState>();

  RealtimeChannel? _roomChannel;
  late String _userId;
  bool _isPasswordUnlocked = false;
  bool _hidePassword = true;
  String? _passwordError;
  bool _isModalDialogOpen = false;

  // Fullscreen & Notifications
  bool _isFullscreen = false;
  bool _isChatSidebarOpen = true;
  final List<_RoomToastItem> _notifications = [];
  StreamSubscription? _fullscreenSub;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _userId = user?.id ?? supabase.auth.currentUser?.id ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';

    _setupRealtimeChannel();
    Future.microtask(() {
      if (mounted) {
        ref.read(roomsProvider.notifier).loadMessages(widget.roomId);
      }
    });

    // Listen to browser fullscreen changes (e.g. Esc key pressed)
    _fullscreenSub = PlatformHelper.onFullscreenChange?.listen((_) {
      final isFs = PlatformHelper.isFullscreen;
      if (mounted && _isFullscreen != isFs) {
        setState(() {
          _isFullscreen = isFs;
        });
      }
    });
  }

  void _toggleFullscreen() {
    if (!PlatformHelper.isFullscreen) {
      PlatformHelper.requestFullscreen();
      setState(() => _isFullscreen = true);
    } else {
      PlatformHelper.exitFullscreen();
      setState(() => _isFullscreen = false);
    }
  }

  void _addNotification({
    required String title,
    String? subtitle,
    required IconData icon,
    Color iconColor = const Color(0xFF9F67FF),
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final toast = _RoomToastItem(
      id: id,
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor,
    );
    if (!mounted) return;
    setState(() {
      if (_notifications.length >= 4) {
        _notifications.removeAt(0);
      }
      _notifications.add(toast);
    });

    Timer(const Duration(milliseconds: 4500), () {
      if (mounted) {
        setState(() {
          _notifications.removeWhere((item) => item.id == id);
        });
      }
    });
  }

  void _setupRealtimeChannel() {
    _roomChannel = supabase.channel('room_${widget.roomId}');

    // Listen to video sync broadcast events
    _roomChannel!.onBroadcast(
      event: 'player_sync',
      callback: (payload) {
        final senderId = payload['senderId'];
        if (senderId == _userId) return;

        final action = payload['action'] as String;
        final pos = (payload['position'] as num?)?.toDouble();
        final sType = payload['sourceType'] as String?;
        final u = payload['url'] as String?;
        final fName = payload['fileName'] as String?;

        _playerKey.currentState?.applyRemoteSync(
          action: action,
          position: pos,
          sourceType: sType,
          url: u,
          fileName: fName,
        );

        // Top-left corner toast notifications
        if (action == 'PAUSE') {
          _addNotification(
            title: 'Пауза ⏸',
            subtitle: 'Воспроизведение приостановлено',
            icon: Icons.pause_circle_rounded,
            iconColor: const Color(0xFFF59E0B),
          );
        } else if (action == 'PLAY') {
          _addNotification(
            title: 'Воспроизведение ▶',
            subtitle: 'Сеанс возобновлен',
            icon: Icons.play_circle_rounded,
            iconColor: const Color(0xFF10B981),
          );
        } else if (action == 'SEEK' && pos != null) {
          final total = pos.round();
          final m = (total % 3600) ~/ 60;
          final s = total % 60;
          _addNotification(
            title: 'Перемотка ⏩',
            subtitle:
                'Перемотано на ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
            icon: Icons.fast_forward_rounded,
            iconColor: const Color(0xFF6366F1),
          );
        } else if (action == 'SOURCE_CHANGE') {
          final mTitle = payload['movieTitle'] as String?;
          final mPoster = payload['moviePoster'] as String?;
          final kpId = payload['kinopoiskId'] as int?;
          if (sType != null) {
            ref.read(roomsProvider.notifier).setRoomMovieSource(
                  widget.roomId,
                  movieTitle: mTitle ?? fName ?? u ?? 'Новое видео',
                  videoSourceType: sType,
                  videoUrl: u,
                  videoFileName: fName,
                  moviePoster: mPoster,
                  kinopoiskId: kpId,
                );
          }
          _addNotification(
            title: 'Смена видео 🎬',
            subtitle: mTitle ?? fName ?? u ?? 'Выбрано новое видео',
            icon: Icons.swap_horiz_rounded,
            iconColor: const Color(0xFF8B5CF6),
          );
        } else if (action == 'HOST_TRANSFER') {
          final newHostName = payload['newHostName'] as String? ?? 'Организатор';
          final newHostId = payload['newHostId'] as String?;
          ref.read(roomsProvider.notifier).transferRoomHost(
                widget.roomId,
                newHostId: newHostId,
                newHostName: newHostName,
              );
          _addNotification(
            title: 'Смена организатора 👑',
            subtitle: 'Права управления переданы: $newHostName',
            icon: Icons.admin_panel_settings_rounded,
            iconColor: const Color(0xFFF59E0B),
          );
        } else if (action == 'USER_LEFT') {
          final uName = payload['userName'] as String? ?? 'Участник';
          _addNotification(
            title: 'Участник вышел 🚪',
            subtitle: '$uName покинул комнату',
            icon: Icons.logout_rounded,
            iconColor: Colors.white60,
          );
        }
      },
    );

    // Listen to chat message broadcast events
    _roomChannel!.onBroadcast(
      event: 'chat_message',
      callback: (payload) {
        final senderId = payload['senderId'];
        if (senderId == _userId) return;
        final senderName = payload['userName'] as String? ?? 'Зритель';
        final msgText = payload['text'] as String? ?? '';

        ref
            .read(roomsProvider.notifier)
            .addMessage(widget.roomId, senderName, msgText, senderId);
        _scrollToBottom();

        // Top toast notification for incoming chat message
        _addNotification(
          title: '$senderName 💬',
          subtitle: msgText,
          icon: Icons.chat_bubble_rounded,
          iconColor: const Color(0xFF9F67FF),
        );
      },
    );

    _roomChannel!.subscribe();
  }

  void _onBroadcastSync({
    required String action,
    double? position,
    String? sourceType,
    String? url,
    String? fileName,
    String? movieTitle,
    String? moviePoster,
    int? kinopoiskId,
  }) {
    _roomChannel?.sendBroadcastMessage(
      event: 'player_sync',
      payload: {
        'action': action,
        'position': position,
        'sourceType': sourceType,
        'url': url,
        'fileName': fileName,
        'movieTitle': movieTitle,
        'moviePoster': moviePoster,
        'kinopoiskId': kinopoiskId,
        'senderId': _userId,
        'sentAt': DateTime.now().millisecondsSinceEpoch,
      },
    );

    if (action == 'SOURCE_CHANGE' && sourceType != null) {
      ref.read(roomsProvider.notifier).setRoomMovieSource(
            widget.roomId,
            movieTitle: movieTitle ?? fileName ?? 'Новое видео',
            videoSourceType: sourceType,
            videoUrl: url,
            videoFileName: fileName,
            moviePoster: moviePoster,
            kinopoiskId: kinopoiskId,
          );
    }
  }

  Future<T?> _safeShowDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    setState(() => _isModalDialogOpen = true);
    setAllIframesPointerEvents(false);
    try {
      return await showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: builder,
      );
    } finally {
      if (mounted) {
        setState(() => _isModalDialogOpen = false);
      }
      setAllIframesPointerEvents(true);
    }
  }

  void _leaveOrExitRoom(BuildContext context, WatchRoom room) {
    final user = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).valueOrNull;
    final myUsername = (profile?.username.isNotEmpty == true && profile!.username != 'cinelover')
        ? profile.username.replaceAll('@', '').toLowerCase()
        : (user?.userMetadata?['username'] as String? ?? (user?.email?.split('@').first ?? '').toLowerCase());
    final isHost = room.ownerId == _userId ||
        (user != null &&
            (room.ownerName.replaceAll('@', '').toLowerCase() == myUsername ||
             (profile != null && room.ownerName.toLowerCase() == profile.displayName.toLowerCase()) ||
             room.ownerName.toLowerCase() == (user.email?.split('@').first ?? '').toLowerCase()));

    final int count = room.participantCount;

    if (count <= 1) {
      // 1 participant leaving -> delete room completely
      _safeShowDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E34),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Row(
            children: [
              Icon(Icons.meeting_room_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Покинуть комнату?'),
            ],
          ),
          content: Text(
            'Вы единственный участник комнаты «${room.title}». При вашем выходе комната будет автоматически закрыта и удалена.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.of(ctx, rootNavigator: true).pop();
                ref.read(roomsProvider.notifier).deleteRoom(room.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Комната «${room.title}» закрыта')),
                );
                context.go('/rooms');
              },
              child: const Text('Выйти и закрыть', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      if (isHost) {
        // Host leaving -> transfer ownership to next participant
        final remaining = room.participants.where((p) => p['id'] != _userId).toList();
        final nextHost = remaining.isNotEmpty ? remaining.first : null;
        final nextHostName = nextHost?['name'] ?? 'Следующий участник';
        final nextHostId = nextHost?['id'];

        _safeShowDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E34),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white12),
            ),
            title: const Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFF59E0B)),
                SizedBox(width: 10),
                Text('Передать права и выйти?'),
              ],
            ),
            content: Text(
              'Вы являетесь организатором комнаты «${room.title}». При вашем выходе права управления будут автоматически переданы участнику «$nextHostName».',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                onPressed: () {
                  Navigator.of(ctx, rootNavigator: true).pop();
                  _roomChannel?.sendBroadcastMessage(
                    event: 'player_sync',
                    payload: {
                      'action': 'HOST_TRANSFER',
                      'newHostId': nextHostId,
                      'newHostName': nextHostName,
                      'senderId': _userId,
                    },
                  );
                  ref.read(roomsProvider.notifier).leaveRoom(room.id, _userId);
                  context.go('/rooms');
                },
                child: const Text('Передать права и выйти', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        // Regular viewer leaving
        _safeShowDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E34),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white12),
            ),
            title: const Row(
              children: [
                Icon(Icons.logout_rounded, color: Color(0xFF9F67FF)),
                SizedBox(width: 10),
                Text('Покинуть комнату?'),
              ],
            ),
            content: Text(
              'Вы уверены, что хотите выйти из комнаты «${room.title}»?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                onPressed: () {
                  Navigator.of(ctx, rootNavigator: true).pop();
                  final user = ref.read(currentUserProvider);
                  final prof = ref.read(userProfileProvider).valueOrNull;
                  final uName = (prof != null && prof.username.isNotEmpty && prof.username != 'cinelover')
                      ? '@${prof.username.replaceAll('@', '')}'
                      : ((prof != null && prof.displayName.isNotEmpty && prof.displayName != 'Пользователь')
                          ? prof.displayName
                          : (user?.userMetadata?['username'] != null
                              ? '@${user!.userMetadata!['username']}'
                              : (user?.email?.split('@').first ?? 'Зритель')));
                  _roomChannel?.sendBroadcastMessage(
                    event: 'player_sync',
                    payload: {
                      'action': 'USER_LEFT',
                      'userName': uName,
                      'senderId': _userId,
                    },
                  );
                  ref.read(roomsProvider.notifier).leaveRoom(room.id, _userId);
                  context.go('/rooms');
                },
                child: const Text('Выйти', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    }
  }

  void _confirmDeleteRoom(BuildContext context, WatchRoom room) {
    _safeShowDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E34),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Удалить комнату?'),
          ],
        ),
        content: Text(
          'Вы уверены, что хотите принудительно удалить комнату «${room.title}»? Сеанс и история чата будут удалены.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.of(ctx, rootNavigator: true).pop();
              ref.read(roomsProvider.notifier).deleteRoom(room.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Комната «${room.title}» удалена')),
              );
              context.go('/rooms');
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRoomSettingsDialog(BuildContext context, WatchRoom room) {
    final titleCtrl = TextEditingController(text: room.title);
    final passwordCtrl = TextEditingController();
    int controlMode = room.allowGuestControl ? 1 : (room.allowedControllers.isNotEmpty ? 2 : 0);
    final selectedControllers = Set<String>.from(room.allowedControllers);
    int? maxParticipants = room.maxParticipants;
    double sliderVal = (maxParticipants ?? 50).toDouble();
    final limitTextCtrl = TextEditingController(
        text: maxParticipants == null ? '∞' : maxParticipants.toString());
    bool hidePassword = true;

    _safeShowDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E34),
              title: const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Color(0xFF9F67FF)),
                  SizedBox(width: 10),
                  Text('Настройки комнаты'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Room Title
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Название комнаты',
                          prefixIcon: Icon(Icons.meeting_room_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Room Password
                      TextField(
                        controller: passwordCtrl,
                        obscureText: hidePassword,
                        decoration: InputDecoration(
                          labelText: 'Пароль для входа (необязательно)',
                          hintText: 'Оставьте пустым для открытого входа',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 18,
                            ),
                            onPressed: () => setDlgState(
                                () => hidePassword = !hidePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Max Participants (Slider + Precise TextField)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Лимит участников:',
                            style: TextStyle(
                              color: Color(0xFF9F67FF),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: sliderVal >= 50
                                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                  : const Color(0xFF7C3AED).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: sliderVal >= 50
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF7C3AED),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              sliderVal >= 50
                                  ? '♾ Без лимита'
                                  : '${sliderVal.round()} чел.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: sliderVal >= 50
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFC084FC),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF7C3AED),
                                inactiveTrackColor: Colors.white12,
                                thumbColor: const Color(0xFF9F67FF),
                                overlayColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: sliderVal,
                                min: 2,
                                max: 50,
                                divisions: 48,
                                onChanged: (val) {
                                  setDlgState(() {
                                    sliderVal = val;
                                    if (val >= 50) {
                                      maxParticipants = null;
                                      limitTextCtrl.text = '∞';
                                    } else {
                                      maxParticipants = val.round();
                                      limitTextCtrl.text = val.round().toString();
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 74,
                            child: TextField(
                              controller: limitTextCtrl,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                hintText: '2-50',
                                hintStyle: const TextStyle(fontSize: 11, color: Colors.white30),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (text) {
                                final parsed = int.tryParse(text.trim());
                                setDlgState(() {
                                  if (parsed == null || parsed >= 50 || parsed <= 0) {
                                    sliderVal = 50.0;
                                    maxParticipants = null;
                                  } else {
                                    final clamped = parsed.clamp(2, 49);
                                    sliderVal = clamped.toDouble();
                                    maxParticipants = clamped;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      Text(
                        sliderVal >= 50
                            ? '♾ Ползунок справа: количество участников неограниченно'
                            : 'Точная настройка: максимум ${sliderVal.round()} зрителей одновременно',
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                      const SizedBox(height: 16),

                      // Permissions (Granular & customizable)
                      const Text(
                        'Права доступа к управлению плеером:',
                        style: TextStyle(
                          color: Color(0xFF9F67FF),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ignore: deprecated_member_use
                      RadioListTile<int>(
                        value: 0,
                        // ignore: deprecated_member_use
                        groupValue: controlMode,
                        title: const Text('🔒 Только организатор (рекомендуется)'),
                        subtitle: const Text(
                          'Зрители смотрят синхронно, паузой и перемоткой управляете только вы',
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                        // ignore: deprecated_member_use
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() => controlMode = val);
                          }
                        },
                      ),
                      // ignore: deprecated_member_use
                      RadioListTile<int>(
                        value: 1,
                        // ignore: deprecated_member_use
                        groupValue: controlMode,
                        title: const Text('👥 Все участники'),
                        subtitle: const Text(
                          'Любой зритель в комнате может ставить на паузу и перематывать видео',
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                        // ignore: deprecated_member_use
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() => controlMode = val);
                          }
                        },
                      ),
                      // ignore: deprecated_member_use
                      RadioListTile<int>(
                        value: 2,
                        // ignore: deprecated_member_use
                        groupValue: controlMode,
                        title: const Text('🎯 Точечная настройка участников'),
                        subtitle: const Text(
                          'Разрешить ставить на паузу и перематывать только выбранным зрителям',
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                        // ignore: deprecated_member_use
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() => controlMode = val);
                          }
                        },
                      ),
                      if (controlMode == 2) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16162A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Кому разрешено управление:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFA5B4FC),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (room.participants.where((p) => p['id'] != _userId).isEmpty)
                                const Text(
                                  'Пока в комнате нет других зрителей. При их подключении вы сможете выдать им пульт.',
                                  style: TextStyle(fontSize: 11, color: Colors.white54),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: room.participants
                                      .where((p) => p['id'] != _userId)
                                      .map((p) {
                                    final pId = p['id'] ?? '';
                                    final pName = p['name'] ?? 'Зритель';
                                    final isAllowed = selectedControllers.contains(pId) ||
                                        selectedControllers.contains(pName);
                                    return FilterChip(
                                      avatar: Icon(
                                        isAllowed
                                            ? Icons.sports_esports_rounded
                                            : Icons.visibility_outlined,
                                        size: 14,
                                        color: isAllowed ? Colors.white : Colors.white60,
                                      ),
                                      label: Text(pName),
                                      selected: isAllowed,
                                      selectedColor: const Color(0xFF7C3AED),
                                      onSelected: (selected) {
                                        setDlgState(() {
                                          if (selected) {
                                            selectedControllers.add(pId);
                                            if (pName.isNotEmpty) selectedControllers.add(pName);
                                          } else {
                                            selectedControllers.remove(pId);
                                            selectedControllers.remove(pName);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newTitle = titleCtrl.text.trim();
                    final newPass = passwordCtrl.text.trim();
                    ref.read(roomsProvider.notifier).updateRoomSettings(
                          room.id,
                          title: newTitle.isNotEmpty ? newTitle : null,
                          password: newPass.isNotEmpty ? newPass : null,
                          maxParticipants: maxParticipants,
                          allowGuestControl: controlMode == 1,
                          allowedControllers: controlMode == 2 ? selectedControllers.toList() : [],
                        );
                    _roomChannel?.sendBroadcastMessage(
                      event: 'permissions_update',
                      payload: {
                        'allowGuestControl': controlMode == 1,
                        'allowedControllers': controlMode == 2 ? selectedControllers.toList() : [],
                      },
                    );
                    Navigator.of(ctx, rootNavigator: true).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Настройки комнаты сохранены')),
                    );
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _fullscreenSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _passwordInputCtrl.dispose();
    _roomChannel?.unsubscribe();
    super.dispose();
  }

  void _sendMessage(WatchRoom room) {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    final customProf = ref.read(profileCustomizationProvider);
    final prof = ref.read(userProfileProvider).valueOrNull;
    final userName = (customProf != null && customProf.username.isNotEmpty && customProf.username != 'cinelover')
        ? '@${customProf.username.replaceAll('@', '')}'
        : ((prof != null && prof.username.isNotEmpty && prof.username != 'cinelover')
            ? '@${prof.username.replaceAll('@', '')}'
            : ((customProf != null && customProf.displayName.isNotEmpty && customProf.displayName != 'Пользователь')
                ? customProf.displayName
                : ((prof != null && prof.displayName.isNotEmpty && prof.displayName != 'Пользователь')
                    ? prof.displayName
                    : (user?.userMetadata?['username'] != null
                        ? '@${user!.userMetadata!['username']}'
                        : (user?.email?.split('@').first ?? 'Зритель')))));

    ref.read(roomsProvider.notifier).addMessage(room.id, userName, text, _userId);
    _msgCtrl.clear();
    _scrollToBottom();

    _roomChannel?.sendBroadcastMessage(
      event: 'chat_message',
      payload: {
        'userName': userName,
        'text': text,
        'senderId': _userId,
        'sentAt': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // --- Source Selection Dialog Window ---

  void _showChangeSourceDialog(BuildContext context, WatchRoom room) {
    _safeShowDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E34),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Colors.white12),
          ),
          child: Container(
            width: 520,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.video_library_rounded,
                          color: Color(0xFF9F67FF), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Сменить видеоисточник',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 22, color: Colors.white70),
                      tooltip: 'Закрыть окно',
                      onPressed: () =>
                          Navigator.of(ctx, rootNavigator: true).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSourceOptionTile(
                  ctx,
                  icon: Icons.movie_creation_rounded,
                  color: const Color(0xFF9F67FF),
                  title: 'Каталог фильмов и сериалов',
                  subtitle: 'Выбрать фильм или сериал из каталога (Alloha & Collaps)',
                  onTap: () {
                    Navigator.of(ctx, rootNavigator: true).pop();
                    _showCatalogSearchDialog(context, room);
                  },
                ),
                _buildSourceOptionTile(
                  ctx,
                  icon: Icons.smart_display_rounded,
                  color: const Color(0xFFEF4444),
                  title: 'YouTube (как в Rave)',
                  subtitle:
                      'Внутренний каталог трендов, поиск видео и запуск по ссылке',
                  onTap: () {
                    Navigator.of(ctx, rootNavigator: true).pop();
                    _showYoutubeBrowserDialog(context, room);
                  },
                ),
                _buildSourceOptionTile(
                  ctx,
                  icon: Icons.play_circle_fill_rounded,
                  color: const Color(0xFF0077FF),
                  title: 'VK Видео (как в Rave)',
                  subtitle:
                      'Каталог шоу (ЧБД, Большое шоу, Топлес) и поиск без VPN',
                  onTap: () {
                    Navigator.of(ctx, rootNavigator: true).pop();
                    _showVkVideoBrowserDialog(context, room);
                  },
                ),
                _buildSourceOptionTile(
                  ctx,
                  icon: Icons.link_rounded,
                  color: const Color(0xFF10B981),
                  title: 'Прямая ссылка (URL)',
                  subtitle: 'MP4, WebM или HLS (.m3u8) поток по прямой ссылке',
                  onTap: () {
                    Navigator.of(ctx, rootNavigator: true).pop();
                    _showDirectUrlDialog(context, room);
                  },
                ),
                _buildSourceOptionTile(
                  ctx,
                  icon: Icons.folder_open_rounded,
                  color: const Color(0xFFF59E0B),
                  title: 'Локальный файл с компьютера',
                  subtitle: 'Видеофайл (.mp4, .webm) без загрузки в интернет',
                  onTap: () {
                    Navigator.of(ctx, rootNavigator: true).pop();
                    _pickLocalFileForRoom(room);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceOptionTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white10),
        ),
        tileColor: const Color(0xFF16162A),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }

  // --- Catalog Browser Dialog ---

  void _showCatalogSearchDialog(BuildContext context, WatchRoom room) {
    final searchCtrl = TextEditingController();
    List<CatalogItem> searchResults = CuratedCatalog.items;
    bool isLoading = false;
    bool hasLoadedLive = false;

    _safeShowDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            if (!hasLoadedLive) {
              hasLoadedLive = true;
              KinopoiskService().getPopular().then((items) {
                if (items.isNotEmpty && ctx.mounted) {
                  setDlgState(() {
                    searchResults = items;
                  });
                }
              }).catchError((_) {});
            }

            void performSearch(String q) async {
              setDlgState(() => isLoading = true);
              final res = await KinopoiskService().search(q);
              setDlgState(() {
                searchResults = res;
                isLoading = false;
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E34),
              title: Row(
                children: [
                  const Icon(Icons.movie_creation_rounded,
                      color: Color(0xFF9F67FF)),
                  const SizedBox(width: 10),
                  const Text('Выбрать фильм из каталога'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 22, color: Colors.white70),
                    tooltip: 'Закрыть',
                    onPressed: () =>
                        Navigator.of(ctx, rootNavigator: true).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 650,
                height: 520,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText:
                            'Поиск по названию фильма, сериала или аниме...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded),
                          onPressed: () =>
                              performSearch(searchCtrl.text.trim()),
                        ),
                      ),
                      onSubmitted: performSearch,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : searchResults.isEmpty
                              ? const Center(
                                  child: Text('Ничего не найдено',
                                      style: TextStyle(color: Colors.white60)),
                                )
                              : ListView.builder(
                                  itemCount: searchResults.length,
                                  itemBuilder: (context, i) {
                                    final item = searchResults[i];
                                    return ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          item.posterUrl,
                                          width: 44,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            width: 44,
                                            height: 60,
                                            color: Colors.white10,
                                            child: const Icon(
                                                Icons.movie_rounded,
                                                size: 20),
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        item.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        '${item.year} • ${item.genres.take(2).join(", ")}',
                                        style: const TextStyle(
                                            color: Colors.white60, fontSize: 11),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B)
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '★ ${item.rating.toStringAsFixed(1)}',
                                          style: const TextStyle(
                                            color: Color(0xFFF59E0B),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      onTap: () {
                                        ref
                                            .read(roomsProvider.notifier)
                                            .setRoomMovieSource(
                                              room.id,
                                              movieTitle: item.title,
                                              movieType: item.type,
                                              moviePoster: item.posterUrl,
                                              movieYear: item.year,
                                              kinopoiskId: item.kinopoiskId,
                                              videoSourceType: 'catalog',
                                            );
                                        _onBroadcastSync(
                                          action: 'SOURCE_CHANGE',
                                          sourceType: 'catalog',
                                          movieTitle: item.title,
                                          moviePoster: item.posterUrl,
                                          kinopoiskId: item.kinopoiskId,
                                        );
                                        Navigator.of(ctx, rootNavigator: true)
                                            .pop();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Фильм «${item.title}» запущен в комнате'),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
          },
        );
      },
    );
  }

  // --- YouTube In-App Browser Dialog (Rave Style) ---

  void _showYoutubeBrowserDialog(BuildContext context, WatchRoom room) {
    final searchCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    int currentTab = 0; // 0: Browse/Search, 1: Direct link
    String selectedCategory = '🔥 В тренде';
    List<YouTubeVideoItem> videos = YouTubeService.curatedPopular;
    bool isLoading = false;

    _safeShowDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            void performSearch(String q) async {
              setDlgState(() => isLoading = true);
              final res = await YouTubeService().search(q);
              setDlgState(() {
                videos = res;
                isLoading = false;
              });
            }

            return Dialog(
              backgroundColor: const Color(0xFF1E1E34),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Colors.white12),
              ),
              child: Container(
                width: 780,
                height: 580,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.smart_display_rounded,
                              color: Color(0xFFEF4444), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YouTube (как в Rave)',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Внутренний поиск, рекомендации и синхронный просмотр',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.white60),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 22, color: Colors.white70),
                          tooltip: 'Закрыть',
                          onPressed: () =>
                              Navigator.of(ctx, rootNavigator: true).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Tab Selector
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141424),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDlgState(() => currentTab = 0),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: currentTab == 0
                                      ? const Color(0xFFEF4444)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_rounded,
                                        size: 16, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text('Поиск и тренды',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDlgState(() => currentTab = 1),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: currentTab == 1
                                      ? const Color(0xFFEF4444)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.link_rounded,
                                        size: 16, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text('По прямой ссылке',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // TAB 0: Browse & Search
                    if (currentTab == 0) ...[
                      // Search Bar
                      TextField(
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText:
                              'Поиск роликов на YouTube (музыка, трейлеры, обзоры, стримы)...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    searchCtrl.clear();
                                    setDlgState(() =>
                                        videos = YouTubeService.curatedPopular);
                                  },
                                )
                              : IconButton(
                                  icon: const Icon(Icons.arrow_forward_rounded,
                                      size: 18),
                                  onPressed: () =>
                                      performSearch(searchCtrl.text.trim()),
                                ),
                        ),
                        onSubmitted: performSearch,
                      ),
                      const SizedBox(height: 10),

                      // Category Quick Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            '🔥 В тренде',
                            '🎬 Трейлеры',
                            '🎮 Игры',
                            '🎵 Музыка',
                            '💡 Подкасты & Шоу',
                            '🍿 Аниме',
                          ].map((cat) {
                            final isSel = selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSel,
                                onSelected: (_) {
                                  setDlgState(() => selectedCategory = cat);
                                  if (cat == '🔥 В тренде') {
                                    performSearch('');
                                  } else {
                                    performSearch(
                                        cat.replaceAll(RegExp(r'[^\w\sа-яА-ЯёЁ]'), '').trim());
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Grid of Video Cards
                      Expanded(
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : videos.isEmpty
                                ? const Center(
                                    child: Text('Ролики не найдены',
                                        style: TextStyle(color: Colors.white60)),
                                  )
                                : GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 240,
                                      childAspectRatio: 1.15,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                    itemCount: videos.length,
                                    itemBuilder: (context, i) {
                                      final item = videos[i];
                                      return InkWell(
                                        onTap: () {
                                          ref
                                              .read(roomsProvider.notifier)
                                              .setRoomMovieSource(
                                                room.id,
                                                movieTitle: item.title,
                                                moviePoster: item.thumbnailUrl,
                                                videoSourceType: 'youtube',
                                                videoUrl: item.embedUrl,
                                              );
                                          _onBroadcastSync(
                                            action: 'SOURCE_CHANGE',
                                            sourceType: 'youtube',
                                            url: item.embedUrl,
                                            movieTitle: item.title,
                                            moviePoster: item.thumbnailUrl,
                                          );
                                          Navigator.of(ctx,
                                                  rootNavigator: true)
                                              .pop();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  '«${item.title}» запущен в комнате'),
                                            ),
                                          );
                                        },
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF16162A),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: Colors.white12),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Thumbnail with duration
                                              Stack(
                                                children: [
                                                  Image.network(
                                                    item.thumbnailUrl,
                                                    height: 110,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) =>
                                                            Container(
                                                      height: 110,
                                                      color: Colors.white10,
                                                      child: const Icon(
                                                          Icons.smart_display_rounded,
                                                          size: 30),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    bottom: 6,
                                                    right: 6,
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black87,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                4),
                                                      ),
                                                      child: Text(
                                                        item.duration,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.title,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      item.author,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.white60,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],

                    // TAB 1: Direct link paste
                    if (currentTab == 1) ...[
                      const SizedBox(height: 20),
                      TextField(
                        controller: linkCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Ссылка на видео YouTube',
                          hintText:
                              'https://youtube.com/watch?v=... или https://youtu.be/...',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: Color(0xFFEF4444), size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Для зрителей из России YouTube может требовать включенного VPN из-за замедления.',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Запустить видео в комнате'),
                        onPressed: () {
                          final raw = linkCtrl.text.trim();
                          if (raw.isEmpty) return;

                          final vId = YouTubeService.extractVideoId(raw);
                          final embedUrl = vId != null
                              ? 'https://www.youtube.com/embed/$vId?enablejsapi=1&autoplay=1&rel=0&playsinline=1'
                              : raw;
                          final thumb = vId != null
                              ? 'https://i.ytimg.com/vi/$vId/hqdefault.jpg'
                              : null;

                          ref.read(roomsProvider.notifier).setRoomMovieSource(
                                room.id,
                                movieTitle: 'YouTube Видео',
                                moviePoster: thumb,
                                videoSourceType: 'youtube',
                                videoUrl: embedUrl,
                              );
                          _onBroadcastSync(
                            action: 'SOURCE_CHANGE',
                            sourceType: 'youtube',
                            url: embedUrl,
                            movieTitle: 'YouTube Видео',
                            moviePoster: thumb,
                          );
                          Navigator.of(ctx, rootNavigator: true).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('YouTube видео запущено')),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- VK Video In-App Browser Dialog (Rave Style) ---

  void _showVkVideoBrowserDialog(BuildContext context, WatchRoom room) {
    final searchCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    int currentTab = 0; // 0: Browse/Search, 1: Direct link
    String selectedCategory = 'Все';
    List<VkVideoItem> videos = VkVideoService.curatedVideos;

    _safeShowDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            void performSearch(String q) async {
              final res = await VkVideoService()
                  .search(q, category: selectedCategory);
              setDlgState(() => videos = res);
            }

            return Dialog(
              backgroundColor: const Color(0xFF1E1E34),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Colors.white12),
              ),
              child: Container(
                width: 780,
                height: 580,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0077FF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.play_circle_fill_rounded,
                              color: Color(0xFF0077FF), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VK Видео (как в Rave)',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Каталог шоу, поиск и видео ВКонтакте без VPN в РФ',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.white60),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 22, color: Colors.white70),
                          tooltip: 'Закрыть',
                          onPressed: () =>
                              Navigator.of(ctx, rootNavigator: true).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Tab Selector
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141424),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDlgState(() => currentTab = 0),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: currentTab == 0
                                      ? const Color(0xFF0077FF)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.video_library_rounded,
                                        size: 16, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text('Шоу и каталог VK',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDlgState(() => currentTab = 1),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: currentTab == 1
                                      ? const Color(0xFF0077FF)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.link_rounded,
                                        size: 16, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text('По прямой ссылке / ID',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // TAB 0: Browse & Search
                    if (currentTab == 0) ...[
                      // Search Bar
                      TextField(
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText:
                              'Поиск роликов в VK (ЧБД, Большое шоу, Топлес, Смешарики)...',
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 20, color: Color(0xFF0077FF)),
                          suffixIcon: searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    searchCtrl.clear();
                                    performSearch('');
                                  },
                                )
                              : null,
                        ),
                        onChanged: performSearch,
                      ),
                      const SizedBox(height: 10),

                      // Category Quick Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            'Все',
                            'Шоу и блоги',
                            'Кино и мульты',
                            'Игры & Стримы',
                            'Технологии',
                            'Наука и жизнь',
                          ].map((cat) {
                            final isSel = selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSel,
                                onSelected: (_) {
                                  setDlgState(() => selectedCategory = cat);
                                  performSearch(searchCtrl.text);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Grid of Video Cards
                      Expanded(
                        child: videos.isEmpty
                            ? const Center(
                                child: Text('Ролики не найдены',
                                    style: TextStyle(color: Colors.white60)),
                              )
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 240,
                                  childAspectRatio: 1.15,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: videos.length,
                                itemBuilder: (context, i) {
                                  final item = videos[i];
                                  return InkWell(
                                    onTap: () {
                                      ref
                                          .read(roomsProvider.notifier)
                                          .setRoomMovieSource(
                                            room.id,
                                            movieTitle: item.title,
                                            moviePoster: item.thumbnailUrl,
                                            videoSourceType: 'vk',
                                            videoUrl: item.embedUrl,
                                          );
                                      _onBroadcastSync(
                                        action: 'SOURCE_CHANGE',
                                        sourceType: 'vk',
                                        url: item.embedUrl,
                                        movieTitle: item.title,
                                        moviePoster: item.thumbnailUrl,
                                      );
                                      Navigator.of(ctx, rootNavigator: true)
                                          .pop();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              '«${item.title}» запущен в комнате'),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16162A),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border:
                                            Border.all(color: Colors.white12),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Thumbnail with duration & VK Badge
                                          Stack(
                                            children: [
                                              Image.network(
                                                item.thumbnailUrl,
                                                height: 110,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (_, __, ___) =>
                                                        Container(
                                                  height: 110,
                                                  color: Colors.white10,
                                                  child: const Icon(
                                                      Icons.play_circle_fill_rounded,
                                                      size: 30),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 6,
                                                right: 6,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black87,
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    item.duration,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 6,
                                                left: 6,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 5,
                                                          vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF0077FF),
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'VK',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.title,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  item.author,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white60,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],

                    // TAB 1: Direct link paste
                    if (currentTab == 1) ...[
                      const SizedBox(height: 20),
                      TextField(
                        controller: linkCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Ссылка или код для вставки VK',
                          hintText:
                              'https://vk.com/video-123456_789012 или vk.com/video_ext.php?...',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0077FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF0077FF)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_rounded,
                                color: Color(0xFF0077FF), size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'VK Видео работает стабильно у всех пользователей из РФ без использования VPN.',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0077FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Запустить видео в комнате'),
                        onPressed: () {
                          final raw = linkCtrl.text.trim();
                          if (raw.isEmpty) return;

                          final embedUrl =
                              VkVideoService.parseVkUrl(raw) ?? raw;

                          ref.read(roomsProvider.notifier).setRoomMovieSource(
                                room.id,
                                movieTitle: 'VK Видео',
                                videoSourceType: 'vk',
                                videoUrl: embedUrl,
                              );
                          _onBroadcastSync(
                            action: 'SOURCE_CHANGE',
                            sourceType: 'vk',
                            url: embedUrl,
                            movieTitle: 'VK Видео',
                          );
                          Navigator.of(ctx, rootNavigator: true).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('VK Видео успешно подключено')),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDirectUrlDialog(BuildContext context, WatchRoom room) {
    final urlCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    _safeShowDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E34),
        title: Row(
          children: [
            const Icon(Icons.link_rounded, color: Color(0xFF10B981)),
            const SizedBox(width: 10),
            const Text('Прямая ссылка на файл'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 22, color: Colors.white70),
              tooltip: 'Закрыть',
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Вставьте прямую ссылку на видеофайл (.mp4, .webm, .m3u8):',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Прямая ссылка (URL)',
                  hintText: 'https://site.domain/video.mp4',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название видео (необязательно)',
                  hintText: 'Например: Фильм или Серия 1',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981)),
            onPressed: () {
              final url = urlCtrl.text.trim();
              if (url.isEmpty) return;

              String title = nameCtrl.text.trim();
              if (title.isEmpty) {
                title = url.split('/').last.split('?').first;
                if (title.isEmpty) title = 'Видео по ссылке';
              }

              ref.read(roomsProvider.notifier).setRoomMovieSource(
                    room.id,
                    movieTitle: title,
                    videoSourceType: 'url',
                    videoUrl: url,
                  );
              _onBroadcastSync(
                action: 'SOURCE_CHANGE',
                sourceType: 'url',
                url: url,
              );
              Navigator.of(ctx, rootNavigator: true).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Видеопоток запущен')),
              );
            },
            child: const Text('Запустить'),
          ),
        ],
      ),
    );
  }

  void _pickLocalFileForRoom(WatchRoom room) {
    PlatformHelper.pickVideoFile((file) {
      ref.read(roomsProvider.notifier).setRoomMovieSource(
            room.id,
            movieTitle: file.name,
            videoSourceType: 'file',
            videoUrl: file.blobUrl,
            videoFileName: file.name,
          );

      _onBroadcastSync(
        action: 'SOURCE_CHANGE',
        sourceType: 'file',
        fileName: file.name,
        url: file.blobUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Файл «${file.name}» выбран для показа')),
        );
      }
    });
  }

  // --- Views for Password & Room Limits ---

  Widget _buildPasswordGate(WatchRoom room) {
    return Center(
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E34),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF9F67FF).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 38,
                color: Color(0xFF9F67FF),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Комната «${room.title}»',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Для входа в совместный просмотр введите пароль, установленный организатором:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordInputCtrl,
              obscureText: _hidePassword,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Пароль комнаты',
                errorText: _passwordError,
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              onSubmitted: (_) => _submitPassword(room),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => context.go('/rooms'),
                      child: const Text('Назад'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      onPressed: () => _submitPassword(room),
                      child: const Text(
                        'Войти',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPassword(WatchRoom room) async {
    final entered = _passwordInputCtrl.text.trim();
    final isValid = await ref
        .read(roomRepositoryProvider)
        .verifyRoomPassword(widget.roomId, entered);
    if (!mounted) return;
    if (isValid) {
      setState(() {
        _isPasswordUnlocked = true;
        _passwordError = null;
      });
    } else {
      setState(() {
        _passwordError = 'Неверный пароль комнаты';
      });
    }
  }

  Widget _buildRoomFullGate(WatchRoom room) {
    return Center(
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E34),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                size: 38,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Комната заполнена',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'В комнате «${room.title}» достигнут лимит участников (${room.maxParticipants} чел.). Попробуйте зайти позже.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/rooms'),
              child: const Text('Вернуться к списку комнат'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Source Selection Hub (When room.videoSourceType == 'none') ---

  Widget _buildSourceSelectionHub(
      BuildContext context, WatchRoom room, bool isHost) {
    if (!isHost) {
      return Center(
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E34)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white12
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Text('🍿', style: TextStyle(fontSize: 40)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Организатор настраивает видео...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Сеанс скоро начнется! Организатор выбирает фильм или видеопоток (Каталог, VK Видео, YouTube или файл). Вы можете общаться в чате справа.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7C3AED).withValues(alpha: 0.25),
                  const Color(0xFF1E1E34),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.movie_filter_rounded,
                    color: Color(0xFF9F67FF), size: 36),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Выберите, что вы будете смотреть вместе 🍿',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Выбирайте фильмы и сериалы из каталога, ищите ролики на YouTube и в VK Видео прямо на сайте!',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Cards grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildSourceHubCard(
                    width: isWide
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth,
                    icon: Icons.movie_creation_rounded,
                    color: const Color(0xFF9F67FF),
                    badge: null,
                    title: 'Каталог фильмов и сериалов',
                    desc:
                        'Тысячи фильмов, сериалов и аниме из базы Кинопоиска с выбором плееров Alloha и Collaps.',
                    btnText: 'Выбрать из каталога',
                    onTap: () => _showCatalogSearchDialog(context, room),
                  ),
                  _buildSourceHubCard(
                    width: isWide
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth,
                    icon: Icons.smart_display_rounded,
                    color: const Color(0xFFEF4444),
                    badge: null,
                    title: 'YouTube Видео',
                    desc:
                        'Внутренний каталог трендов, поиск любых роликов прямо на сайте и запуск по ссылке.',
                    btnText: 'Открыть поиск YouTube',
                    onTap: () => _showYoutubeBrowserDialog(context, room),
                  ),
                  _buildSourceHubCard(
                    width: isWide
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth,
                    icon: Icons.play_circle_fill_rounded,
                    color: const Color(0xFF0077FF),
                    badge: null,
                    title: 'VK Видео (ВКонтакте)',
                    desc:
                        'Внутренний каталог топовых шоу (ЧБД, Большое шоу, Топлес, Смешарики) и роликов без VPN.',
                    btnText: 'Открыть каталог VK Видео',
                    onTap: () => _showVkVideoBrowserDialog(context, room),
                  ),
                  _buildSourceHubCard(
                    width: isWide
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth,
                    icon: Icons.link_rounded,
                    color: const Color(0xFF10B981),
                    badge: null,
                    title: 'Прямая ссылка (URL)',
                    desc:
                        'Ссылка на видеофайл из интернета (.mp4, .webm, .m3u8) с полной синхронизацией перемотки и паузы.',
                    btnText: 'Указать URL видео',
                    onTap: () => _showDirectUrlDialog(context, room),
                  ),
                  _buildSourceHubCard(
                    width: isWide
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth,
                    icon: Icons.folder_open_rounded,
                    color: const Color(0xFFF59E0B),
                    badge: null,
                    title: 'Файл с вашего компьютера',
                    desc:
                        'Локальное видео (.mp4, .webm) прямо с вашего ПК. Мгновенный запуск без ожидания загрузки в сеть.',
                    btnText: 'Выбрать файл с ПК',
                    onTap: () => _pickLocalFileForRoom(room),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSourceHubCard({
    required double width,
    required IconData icon,
    required Color color,
    String? badge,
    required String title,
    required String desc,
    required String btnText,
    required VoidCallback onTap,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E34),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              if (badge != null && badge.isNotEmpty) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(
                color: Colors.white60, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor:
                    color == const Color(0xFFF59E0B) ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(icon, size: 16),
              label: Text(btnText,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              onPressed: onTap,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(singleRoomProvider(widget.roomId));

    if (room == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Комната не найдена'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/rooms'),
                child: const Text('Назад ко всем комнатам'),
              ),
            ],
          ),
        ),
      );
    }

    final user = ref.watch(currentUserProvider);
    final userProfile = ref.watch(userProfileProvider).valueOrNull;
    final isAdmin = ref.watch(isAdminProvider);
    final userHandle = (userProfile != null && userProfile.username.isNotEmpty && userProfile.username != 'cinelover')
        ? userProfile.username.replaceAll('@', '').toLowerCase()
        : (user?.userMetadata?['username'] as String? ?? (user?.email?.split('@').first.toLowerCase() ?? ''));
    final customProf = ref.watch(profileCustomizationProvider);
    final myEffectiveUsername = (customProf != null && customProf.username.isNotEmpty && customProf.username != 'cinelover')
        ? customProf.username.replaceAll('@', '').toLowerCase()
        : userHandle;
    final isOwner = (user != null &&
            (room.ownerId == user.id ||
                room.ownerId == _userId ||
                room.ownerName.replaceAll('@', '').toLowerCase() == myEffectiveUsername ||
                room.ownerName.replaceAll('@', '').toLowerCase() == userHandle ||
                (userProfile != null && room.ownerName.toLowerCase() == userProfile.displayName.toLowerCase()) ||
                room.ownerName.toLowerCase() == (user.email?.split('@').first.toLowerCase() ?? ''))) ||
        room.ownerId == _userId;
    final hasRemoteControl = isOwner ||
        isAdmin ||
        room.allowGuestControl ||
        room.allowedControllers.contains(_userId) ||
        (user?.id != null && room.allowedControllers.contains(user!.id)) ||
        room.allowedControllers.contains(myEffectiveUsername);
    final isHost = hasRemoteControl;

    // Check Password protection
    final hasPassword = room.password != null && room.password!.isNotEmpty;
    if (hasPassword && !isOwner && !_isPasswordUnlocked) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text(room.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/rooms'),
          ),
        ),
        body: _buildPasswordGate(room),
      );
    }

    // Check Participant Limit
    if (room.maxParticipants != null &&
        room.participantCount >= room.maxParticipants! &&
        !isOwner) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: _buildRoomFullGate(room),
      );
    }

    final isSourceSelected = room.videoSourceType != 'none';

    // Dedicated Fullscreen Theater Mode with Sidebar Chat and Top-Left Notifications
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Row(
              children: [
                // Video player fills available area
                Expanded(
                  child: Column(
                    children: [
                      // Fullscreen top bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: const Color(0xFF121220).withValues(alpha: 0.95),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded),
                              tooltip: 'Свернуть полноэкранный режим',
                              onPressed: _toggleFullscreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    room.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    isSourceSelected
                                        ? 'Видео: ${room.movieTitle} • Организатор: ${room.ownerName}'
                                        : 'Организатор: ${room.ownerName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(room),
                            const SizedBox(width: 10),
                            // Toggle chat sidebar button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isChatSidebarOpen
                                    ? const Color(0xFF7C3AED)
                                    : const Color(0xFF252540),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: Icon(
                                _isChatSidebarOpen
                                    ? Icons.chat_rounded
                                    : Icons.chat_bubble_outline_rounded,
                                size: 16,
                              ),
                              label: Text(
                                _isChatSidebarOpen
                                    ? 'Чат сбоку (вкл)'
                                    : 'Открыть чат',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              onPressed: () {
                                setState(() =>
                                    _isChatSidebarOpen = !_isChatSidebarOpen);
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.fullscreen_exit_rounded),
                              tooltip: 'Выйти из полноэкранного режима',
                              onPressed: _toggleFullscreen,
                            ),
                          ],
                        ),
                      ),
                      // Video viewport
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: RoomSyncPlayer(
                              key: _playerKey,
                              room: room,
                              isHost: isHost,
                              isFullscreen: true,
                              isDialogOpen: _isModalDialogOpen,
                              onToggleFullscreen: _toggleFullscreen,
                              onBroadcastSync: _onBroadcastSync,
                              onChangeSourceRequested: isHost
                                  ? () =>
                                      _showChangeSourceDialog(context, room)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Collapsible Chat Sidebar (requested by user: "сбоку сделать чат, таким-же сайдбаром")
                if (_isChatSidebarOpen)
                  Container(
                    width: 380,
                    decoration: const BoxDecoration(
                      color: Color(0xFF141426),
                      border: Border(left: BorderSide(color: Colors.white12)),
                    ),
                    child: Column(
                      children: [
                        // Chat Sidebar Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E1E34),
                            border: Border(
                                bottom: BorderSide(color: Colors.white12)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.chat_rounded,
                                  color: Color(0xFF9F67FF), size: 16),
                              const SizedBox(width: 6),
                              const Text(
                                'Чат комнаты',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              const Spacer(),
                              IconButton(
                                icon:
                                    const Icon(Icons.close_rounded, size: 18),
                                tooltip: 'Свернуть чат',
                                onPressed: () => setState(
                                    () => _isChatSidebarOpen = false),
                              ),
                            ],
                          ),
                        ),
                        // Messages list
                        Expanded(child: _buildChatMessagesList(room)),
                        // Message input
                        _buildChatInput(room),
                      ],
                    ),
                  ),
              ],
            ),

            // Top-right notifications overlay
            if (_notifications.isNotEmpty)
              Positioned(
                top: 64,
                right: _isChatSidebarOpen ? 390 : 20,
                child: _buildNotificationsOverlay(),
              ),

            // If chat sidebar is closed in fullscreen, floating button to reopen it
            if (!_isChatSidebarOpen)
              Positioned(
                top: 60,
                right: 16,
                child: FloatingActionButton.small(
                  backgroundColor:
                      const Color(0xFF1E1E34).withValues(alpha: 0.9),
                  foregroundColor: const Color(0xFF9F67FF),
                  tooltip: 'Открыть чат сбоку',
                  child: const Icon(Icons.chat_bubble_outline_rounded,
                      size: 18),
                  onPressed: () => setState(() => _isChatSidebarOpen = true),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          Column(
            children: [
              // Top Room Header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A2E),
                  border: Border(
                      bottom: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_rounded),
                                tooltip: 'Покинуть комнату',
                                onPressed: () =>
                                    _leaveOrExitRoom(context, room),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      room.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15),
                                    ),
                                    Text(
                                      isSourceSelected
                                          ? 'Видео: ${room.movieTitle} • Организатор: ${room.ownerName}'
                                          : 'Организатор: ${room.ownerName} • Видео не выбрано',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Change Source Button (for Host)
                              if (isHost) ...[
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C3AED)
                                        .withValues(alpha: 0.2),
                                    foregroundColor: const Color(0xFF9F67FF),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.swap_horiz_rounded,
                                      size: 16),
                                  label: const Text('СМЕНИТЬ ВИДЕО',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                  onPressed: () =>
                                      _showChangeSourceDialog(context, room),
                                ),
                                const SizedBox(width: 8),
                              ],

                              // Status Indicator badge
                              _buildStatusBadge(room),
                              const SizedBox(width: 8),

                              // Playback permission pill
                              if (isHost)
                                ActionChip(
                                  avatar: Icon(
                                    room.allowGuestControl
                                        ? Icons.group_outlined
                                        : Icons.lock_outline_rounded,
                                    size: 13,
                                    color: room.allowGuestControl
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF9F67FF),
                                  ),
                                  label: Text(
                                    room.allowGuestControl
                                        ? 'Пульт: у всех'
                                        : 'Пульт: у вас',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: room.allowGuestControl
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF9F67FF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: () {
                                    final nextVal = !room.allowGuestControl;
                                    ref
                                        .read(roomsProvider.notifier)
                                        .updateRoomSettings(
                                          room.id,
                                          allowGuestControl: nextVal,
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          nextVal
                                              ? 'Пульт передан всем участникам'
                                              : 'Управление плеером переведено только организатору',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        room.allowGuestControl
                                            ? Icons.group_outlined
                                            : Icons.lock_outline_rounded,
                                        size: 12,
                                        color: room.allowGuestControl
                                            ? const Color(0xFF10B981)
                                            : Colors.white60,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        room.allowGuestControl
                                            ? 'Пульт: у всех'
                                            : 'Пульт: организатор',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: room.allowGuestControl
                                              ? const Color(0xFF10B981)
                                              : Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(width: 8),

                              // Fullscreen Button
                              const SizedBox(width: 8),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF9F67FF),
                                  backgroundColor: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.15),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                ),
                                icon: const Icon(Icons.fullscreen_rounded,
                                    size: 16),
                                label: const Text(
                                  'НА ВЕСЬ ЭКРАН',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700),
                                ),
                                onPressed: _toggleFullscreen,
                              ),

                              // Host Room Settings
                              if (isHost) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.tune_rounded, size: 20),
                                  tooltip: 'Настройки комнаты',
                                  onPressed: () =>
                                      _showRoomSettingsDialog(context, room),
                                ),
                              ],

                              // Leave Room Button (with host transfer & participant check)
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.logout_rounded,
                                    color: Colors.redAccent, size: 20),
                                tooltip: isHost
                                    ? 'Покинуть комнату (передать права)'
                                    : 'Покинуть комнату',
                                onPressed: () =>
                                    _leaveOrExitRoom(context, room),
                              ),
                              if (isAdmin && !isHost) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_forever_rounded,
                                      color: Colors.redAccent, size: 20),
                                  tooltip: 'Удалить комнату (Администратор)',
                                  onPressed: () =>
                                      _confirmDeleteRoom(context, room),
                                ),
                              ],
                            ],
                          ),
                        ),

                    // Main Content: Movie Player + Compact Chat
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 850;
                          final playerOrHubWidget = isSourceSelected
                              ? _buildMovieInfoPane(context, room, isHost)
                              : _buildSourceSelectionHub(context, room, isHost);

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: playerOrHubWidget),
                                const VerticalDivider(
                                    width: 1, color: Colors.white12),
                                SizedBox(
                                  width: 360,
                                  child: _buildChatPane(context, room),
                                ),
                              ],
                            );
                          } else {
                            return DefaultTabController(
                              length: 2,
                              child: Column(
                                children: [
                                  TabBar(
                                    tabs: [
                                      Tab(
                                        icon: const Icon(Icons.movie_rounded),
                                        text: isSourceSelected
                                            ? room.movieTitle
                                            : 'Видеоисточник',
                                      ),
                                      Tab(
                                        icon: const Icon(
                                            Icons.chat_bubble_rounded),
                                        text: 'Чат (${room.messages.length})',
                                      ),
                                    ],
                                  ),
                                  Expanded(
                                    child: TabBarView(
                                      children: [
                                        playerOrHubWidget,
                                        _buildChatPane(context, room),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),

          // Top-Right Notifications Overlay
          if (_notifications.isNotEmpty)
            Positioned(
              top: 64,
              right: 24,
              child: _buildNotificationsOverlay(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(WatchRoom room) {
    if (room.status == 'paused') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
        ),
        child: const Text('⏸ На паузе',
            style: TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, size: 12, color: Color(0xFF9F67FF)),
          const SizedBox(width: 4),
          Text('Организатор: ${room.ownerName}',
              style: const TextStyle(
                  color: Color(0xFF9F67FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMovieInfoPane(
      BuildContext context, WatchRoom room, bool isHost) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Synchronized Player Widget
          RoomSyncPlayer(
            key: _playerKey,
            room: room,
            isHost: isHost,
            isFullscreen: _isFullscreen,
            isDialogOpen: _isModalDialogOpen,
            onToggleFullscreen: _toggleFullscreen,
            onBroadcastSync: _onBroadcastSync,
            onChangeSourceRequested: isHost
                ? () => _showChangeSourceDialog(context, room)
                : null,
          ),
          const SizedBox(height: 20),

          // Movie Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E34),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (room.moviePoster != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          room.moviePoster!,
                          width: 80,
                          height: 115,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 115,
                            color: Colors.white10,
                            child: const Icon(Icons.movie_rounded, size: 36),
                          ),
                        ),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildSourceBadge(room.videoSourceType),
                              if (room.movieYear != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${room.movieYear} год',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ],
                              const Spacer(),
                              if (isHost)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF9F67FF),
                                  ),
                                  icon: const Icon(Icons.edit_outlined, size: 14),
                                  label: const Text('Сменить видео',
                                      style: TextStyle(fontSize: 12)),
                                  onPressed: () =>
                                      _showChangeSourceDialog(context, room),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            room.movieTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            room.videoSourceType == 'catalog'
                                ? 'Смотрите синхронно онлайн с друзьями. Переключение озвучек (Дубляж, HDRezka, LostFilm, AniLibria) доступно прямо внутри плеера.'
                                : room.videoSourceType == 'vk'
                                    ? 'Воспроизведение через официальный плеер VK Видео. Полная доступность на территории РФ без ограничений.'
                                    : room.videoSourceType == 'youtube'
                                        ? 'Воспроизведение через плеер YouTube. Для зрителей из РФ может потребоваться VPN.'
                                        : 'Синхронное воспроизведение видеофайла с общей временной шкалой и паузой.',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge(String sourceType) {
    Color bg;
    Color border;
    Color text;
    String label;
    IconData icon;

    switch (sourceType) {
      case 'vk':
        bg = const Color(0xFF0077FF).withValues(alpha: 0.18);
        border = const Color(0xFF0077FF);
        text = const Color(0xFF60A5FA);
        label = 'VK ВИДЕО';
        icon = Icons.play_circle_fill_rounded;
        break;
      case 'youtube':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.18);
        border = const Color(0xFFEF4444);
        text = const Color(0xFFF87171);
        label = 'YOUTUBE';
        icon = Icons.smart_display_rounded;
        break;
      case 'catalog':
      case 'kodik':
        bg = const Color(0xFF7C3AED).withValues(alpha: 0.2);
        border = const Color(0xFF7C3AED);
        text = const Color(0xFFC084FC);
        label = 'КАТАЛОГ / ОНЛАЙН';
        icon = Icons.movie_filter_rounded;
        break;
      case 'url':
        bg = const Color(0xFF10B981).withValues(alpha: 0.18);
        border = const Color(0xFF10B981);
        text = const Color(0xFF34D399);
        label = 'MP4 / ПРЯМАЯ ССЫЛКА';
        icon = Icons.link_rounded;
        break;
      case 'file':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.18);
        border = const Color(0xFFF59E0B);
        text = const Color(0xFFFBBF24);
        label = 'ЛОКАЛЬНЫЙ ФАЙЛ';
        icon = Icons.folder_open_rounded;
        break;
      default:
        bg = Colors.white10;
        border = Colors.white24;
        text = Colors.white70;
        label = 'ИСТОЧНИК НЕ ВЫБРАН';
        icon = Icons.video_library_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPane(BuildContext context, WatchRoom room) {
    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E34),
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: const Row(
            children: [
              Icon(Icons.chat_rounded,
                  color: Color(0xFF9F67FF), size: 16),
              SizedBox(width: 6),
              Text(
                'Чат комнаты',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),

        // Messages list
        Expanded(child: _buildChatMessagesList(room)),

        // Message input
        _buildChatInput(room),
      ],
    );
  }

  Widget _buildChatMessagesList(WatchRoom room) {
    if (room.messages.isEmpty) {
      return const Center(
        child: Text(
          'Пока нет сообщений.\nНапишите первым!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(12),
      itemCount: room.messages.length,
      itemBuilder: (context, i) {
        final msg = room.messages[i];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildChatInput(WatchRoom room) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(fontSize: 12.5, color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Написать в чат...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.white38),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onSubmitted: (_) => _sendMessage(room),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(32, 32),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.send_rounded, size: 15, color: Colors.white),
            onPressed: () => _sendMessage(room),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsOverlay() {
    return SizedBox(
      width: 310,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: _notifications.map((toast) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF16162A).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: toast.iconColor.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: toast.iconColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(toast.icon, color: toast.iconColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        toast.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (toast.subtitle != null &&
                          toast.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          toast.subtitle!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    setState(() {
                      _notifications.removeWhere((item) => item.id == toast.id);
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close_rounded,
                        size: 14, color: Colors.white38),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageBubble(RoomMessage msg) {
    final user = ref.watch(currentUserProvider);
    final customProf = ref.watch(profileCustomizationProvider);
    final userProfile = ref.watch(userProfileProvider).valueOrNull;
    final myUsername = (customProf != null && customProf.username.isNotEmpty && customProf.username != 'cinelover')
        ? customProf.username.replaceAll('@', '').toLowerCase()
        : ((userProfile != null && userProfile.username.isNotEmpty && userProfile.username != 'cinelover')
            ? userProfile.username.replaceAll('@', '').toLowerCase()
            : (user?.userMetadata?['username'] as String? ?? (user?.email?.split('@').first.toLowerCase() ?? '')));
    final myDisplayName = (customProf?.displayName.isNotEmpty == true ? customProf!.displayName : (userProfile?.displayName ?? '')).toLowerCase();
    final myEmailPrefix = user?.email?.split('@').first.toLowerCase() ?? '';

    final cleanMsgName = msg.userName.replaceAll('@', '').toLowerCase();
    final isMe = (msg.senderId != null && msg.senderId == _userId) ||
        cleanMsgName == myUsername ||
        (myDisplayName.isNotEmpty && cleanMsgName == myDisplayName) ||
        (myEmailPrefix.isNotEmpty && cleanMsgName == myEmailPrefix);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg.userName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isMe ? const Color(0xFF9F67FF) : Colors.white60,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('HH:mm').format(msg.createdAt),
                style: const TextStyle(fontSize: 9, color: Colors.white30),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            constraints: const BoxConstraints(maxWidth: 240),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
                  : const Color(0xFF252540),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isMe
                    ? const Color(0xFF7C3AED).withValues(alpha: 0.5)
                    : Colors.white12,
              ),
            ),
            child: Text(
              msg.text,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
