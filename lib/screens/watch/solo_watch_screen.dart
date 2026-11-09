// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../widgets/app_header.dart';

class SoloWatchScreen extends ConsumerStatefulWidget {
  final String title;
  final int? year;
  final int? kinopoiskId;
  final String? posterUrl;
  final String type;
  final String? description;
  final String? genres;

  const SoloWatchScreen({
    super.key,
    required this.title,
    this.year,
    this.kinopoiskId,
    this.posterUrl,
    required this.type,
    this.description,
    this.genres,
  });

  @override
  ConsumerState<SoloWatchScreen> createState() => _SoloWatchScreenState();
}

class _SoloWatchScreenState extends ConsumerState<SoloWatchScreen> {
  String _activeTab = 'collaps'; // 'collaps' (Collaps HD), 'backup' (Kodik), 'trailer'
  late String _viewId;
  html.IFrameElement? _iframe;

  @override
  void initState() {
    super.initState();
    _viewId = 'cinetrack-solo-player-${DateTime.now().microsecondsSinceEpoch}';
    _initIframe();
  }

  String _getCurrentUrl() {
    final kpId = widget.kinopoiskId ?? 301;

    if (_activeTab == 'collaps') {
      // Плеер 1 (Collaps HD): 4K/1080p, выбор всех серий, сезонов и озвучек
      return 'https://api.delivembd.ws/embed/kp/$kpId';
    } else if (_activeTab == 'alloha') {
      // Плеер 2 (Alloha Player): продвинутый плеер с переводом и выбором качества
      return 'https://alloha.club/embed/kp/$kpId';
    } else if (_activeTab == 'backup') {
      // Плеер 3 (Kodik): резервный плеер
      return 'https://kodik.info/find-player?kinopoiskID=$kpId';
    } else {
      // Трейлер Кинопоиска (работает без блокировок YouTube в РФ)
      return 'https://api.atomics.ws/embed/trailer-kp/$kpId';
    }
  }

  void _initIframe() {
    final url = _getCurrentUrl();
    _iframe = html.IFrameElement()
      ..src = url
      ..referrerPolicy = 'no-referrer'
      ..setAttribute('referrerpolicy', 'no-referrer')
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#0A0A14'
      ..allow = 'autoplay; fullscreen; encrypted-media; picture-in-picture';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => _iframe!,
    );
  }

  void _switchTab(String mode) {
    if (_activeTab == mode) return;
    setState(() {
      _activeTab = mode;
    });
    _iframe?.src = _getCurrentUrl();
  }

  void _createRoomAndInvite() {
    final user = ref.read(currentUserProvider);
    final ownerName = user?.email?.split('@').first ?? 'Организатор';
    final clientToken = RoomRepository.getClientToken();
    final ownerId = user?.id ?? clientToken;

    final room = ref.read(roomsProvider.notifier).createRoom(
      title: 'Смотрим: ${widget.title} 🍿',
      movieTitle: widget.title,
      movieType: widget.type,
      moviePoster: widget.posterUrl,
      movieYear: widget.year,
      kinopoiskId: widget.kinopoiskId,
      scheduledAt: DateTime.now(),
      ownerName: ownerName,
      ownerId: ownerId,
      videoSourceType: 'catalog',
      videoUrl: _getCurrentUrl(),
    );

    context.go('/rooms/${room.id}');
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = AppConstants.mediaTypes[widget.type] ?? 'Фильм';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D18),
      body: Column(
        children: [
          const AppHeader(activeRoute: '/library'),
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Top App Header
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF16162A),
                      border: Border(bottom: BorderSide(color: Colors.white12)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Назад в каталог',
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              context.go('/library');
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.title}${widget.year != null ? ' (${widget.year})' : ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Смотреть онлайн $typeLabel в HD качестве бесплатно',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Invite Friends / Watch Together Button
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.groups_rounded, size: 16),
                          label: const Text('Смотреть с друзьями 🍿'),
                          onPressed: _createRoomAndInvite,
                        ),
                      ],
                    ),
                  ),
                ),

                // Player Area
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Clean Player Tabs (Lordfilm style)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF161622),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: Row(
                            children: [
                              _buildPlayerTab(
                                label: 'СМОТРЕТЬ ОНЛАЙН (Collaps HD)',
                                isActive: _activeTab == 'collaps',
                                onTap: () => _switchTab('collaps'),
                              ),
                              const SizedBox(width: 4),
                              _buildPlayerTab(
                                label: 'ПРОДВИНУТЫЙ ПЛЕЕР (Alloha)',
                                isActive: _activeTab == 'alloha',
                                onTap: () => _switchTab('alloha'),
                              ),
                              const SizedBox(width: 4),
                              _buildPlayerTab(
                                label: 'ЗАПАСНОЙ ПЛЕЕР (Kodik)',
                                isActive: _activeTab == 'backup',
                                onTap: () => _switchTab('backup'),
                              ),
                              const SizedBox(width: 4),
                              _buildPlayerTab(
                                label: 'ТРЕЙЛЕР',
                                isActive: _activeTab == 'trailer',
                                onTap: () => _switchTab('trailer'),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Cinema 16:9 Player Stage (Comfortable 980px max width in normal view)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 980),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      blurRadius: 20,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: HtmlElementView(viewType: _viewId),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Movie Details Block
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16162A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      color: Color(0xFF9F67FF), size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'О фильме / Сериале',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (widget.genres != null &&
                                      widget.genres!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        widget.genres!,
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.white70),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.description ??
                                    'Приятного просмотра! Вы можете выбрать плеер Alloha или запасной Collaps вверху, либо создать синхронную комнату с друзьями.',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerTab({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF5CB85C) : const Color(0xFF222232),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
