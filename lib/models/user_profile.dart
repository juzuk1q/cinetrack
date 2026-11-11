import 'package:supabase_flutter/supabase_flutter.dart';

class AchievementTitle {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String category;

  const AchievementTitle({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.category = 'Общие',
  });
}

class UserAchievementsCatalog {
  UserAchievementsCatalog._();

  static const List<AchievementTitle> list = [
    AchievementTitle(
      id: 'welcome',
      title: 'Новичок стримов 🍿',
      description: 'Регистрация в CineTrack. Первый шаг в мир совместных просмотров!',
      icon: '🍿',
      category: 'Начало',
    ),
    AchievementTitle(
      id: 'collector_3',
      title: 'Киноман 🎬',
      description: 'Собрать в личной коллекции 3 или более фильмов или сериалов',
      icon: '🎬',
      category: 'Коллекция',
    ),
    AchievementTitle(
      id: 'collector_10',
      title: 'Хранитель кинозала 🏛️',
      description: 'Добавить 10 или более фильмов в свою персональную коллекцию',
      icon: '🏛️',
      category: 'Коллекция',
    ),
    AchievementTitle(
      id: 'popcorn_master',
      title: 'Мастер попкорна 🍿',
      description: 'Отметить фильм или эпизод как полностью просмотренный',
      icon: '🍿',
      category: 'Просмотры',
    ),
    AchievementTitle(
      id: 'party_host',
      title: 'Создатель комнат 👑',
      description: 'Создать комнату для совместного синхронного просмотра с друзьями',
      icon: '👑',
      category: 'Совместные',
    ),
    AchievementTitle(
      id: 'night_owl',
      title: 'Полуночник 🦉',
      description: 'Смотреть кино после 23:00 или собрать 5 любимых картин в избранное',
      icon: '🦉',
      category: 'Особые',
    ),
    AchievementTitle(
      id: 'critic',
      title: 'Кинокритик 💬',
      description: 'Поставить пользовательскую оценку или написать рецензию фильму',
      icon: '💬',
      category: 'Активность',
    ),
    AchievementTitle(
      id: 'social',
      title: 'Душа компании 🤝',
      description: 'Добавить первого друга в CineTrack для быстрых приглашений',
      icon: '🤝',
      category: 'Друзья',
    ),
    AchievementTitle(
      id: 'anime_guru',
      title: 'Аниме-гуру ⚡',
      description: 'Добавить аниме или мультипликационный сериал в коллекцию',
      icon: '⚡',
      category: 'Жанры',
    ),
    AchievementTitle(
      id: 'veteran',
      title: 'Ветеран CineTrack 🛡️',
      description: 'Постоянный активный участник киносообщества CineTrack',
      icon: '🛡️',
      category: 'Особые',
    ),
    AchievementTitle(
      id: 'legend',
      title: 'Легенда платформы 🌟',
      description: 'Выдающийся статус создателя или активнейшего участника CineTrack',
      icon: '🌟',
      category: 'Особые',
    ),
    AchievementTitle(
      id: 'vip_streamer',
      title: 'VIP Киноман 💎',
      description: 'Премиальный статус кинолюбителя CineTrack',
      icon: '💎',
      category: 'Особые',
    ),
    AchievementTitle(
      id: 'coder_badge',
      title: 'Архитектор кода 💻',
      description: 'Создатель и разработчик архитектуры платформы',
      icon: '💻',
      category: 'Особые',
    ),
  ];
}

class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String username;
  final String role; // 'user', 'moderator', 'admin'
  final DateTime createdAt;
  final String? customTitle; // e.g. 'Мастер попкорна 🍿', 'Кинокритик 💬', 'Легенда платформы 🌟', etc.
  final String? bannerUrl;
  final String? avatarUrl;
  final bool isPrivate;
  final List<String> friends;
  final List<String> unlockedTitles;
  final bool isBlocked;
  final bool isFrozen;
  final String? blockReason;
  final DateTime? blockUntil;
  final bool hasPassword;

  bool get effectiveHasPassword =>
      hasPassword || _computeHasPassword(id);

  static bool _computeHasPassword(String? uid) {
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser != null && (uid == null || authUser.id == uid)) {
        final provider = authUser.appMetadata['provider'] as String?;
        final hasEmailIdentity =
            authUser.identities?.any((i) => i.provider == 'email') ?? false;
        final hasMetadataFlag = authUser.userMetadata?['has_password'] == true;
        return provider == 'email' || hasEmailIdentity || hasMetadataFlag;
      }
    } catch (_) {}
    return false;
  }

  // Role hierarchy getters (Strictly 3 roles: user, moderator, admin)
  bool get isAdmin => role == 'admin';
  bool get isModerator => isAdmin || role == 'moderator';
  bool get isUser => role == 'user';

  int get roleRank => rankForRole(role);

  static int rankForRole(String r) {
    switch (r.toLowerCase()) {
      case 'admin':
        return 50;
      case 'moderator':
        return 30;
      case 'user':
      default:
        return 10;
    }
  }

  bool get hasStaffRole => role == 'admin' || role == 'moderator';

  String? get roleDisplayName {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Администратор';
      case 'moderator':
        return 'Модератор';
      case 'user':
      default:
        return null;
    }
  }

  String? get roleIcon {
    switch (role.toLowerCase()) {
      case 'admin':
        return '⭐';
      case 'moderator':
        return '🛡️';
      case 'user':
      default:
        return null;
    }
  }

  String? get roleLabel {
    final name = roleDisplayName;
    final icon = roleIcon;
    if (name == null || icon == null) return null;
    return ' ';
  }

  String get fullRoleTitle {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Администратор ⭐';
      case 'moderator':
        return 'Модератор 🛡️';
      case 'user':
      default:
        return 'Пользователь 👤';
    }
  }

  /// Permission check: whether this profile can manage targetUser (ban, freeze, alter roles)
  bool canManage(UserProfile target) {
    // 1. Cannot manage self
    if (id == target.id || email.toLowerCase() == target.email.toLowerCase()) {
      return false;
    }
    // 2. Only admin can manage other users
    if (!isAdmin) {
      return false;
    }
    return true;
  }

  /// Permission check: whether this profile can assign newRole to targetUser
  bool canAssignRole(UserProfile target, String newRole) {
    if (!canManage(target)) return false;
    return isAdmin;
  }

  /// List of roles this profile is allowed to assign to other users
  List<String> get assignableRoles {
    if (!isAdmin) return const [];
    return const ['user', 'moderator', 'admin'];
  }

  bool get isCurrentlyFrozen =>
      isFrozen && (blockUntil == null || DateTime.now().isBefore(blockUntil!));

  bool get isRestricted => isBlocked || isCurrentlyFrozen;

  String get effectiveTitle {
    if (customTitle != null && customTitle!.trim().isNotEmpty) {
      return customTitle!.trim();
    }
    return 'Новичок стримов 🍿';
  }

  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.username = '',
    this.role = 'user',
    required this.createdAt,
    this.customTitle,
    this.bannerUrl,
    this.avatarUrl,
    this.isPrivate = false,
    this.friends = const [],
    this.unlockedTitles = const ['welcome'],
    this.isBlocked = false,
    this.isFrozen = false,
    this.blockReason,
    this.blockUntil,
    this.hasPassword = false,
  });

  String get handle {
    if (username.isNotEmpty) return username;
    if (email.isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }
    return 'cinelover';
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? username,
    String? role,
    DateTime? createdAt,
    String? customTitle,
    String? bannerUrl,
    String? avatarUrl,
    bool? isPrivate,
    List<String>? friends,
    List<String>? unlockedTitles,
    bool? isBlocked,
    bool? isFrozen,
    String? blockReason,
    DateTime? blockUntil,
    bool? hasPassword,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      customTitle: customTitle ?? this.customTitle,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isPrivate: isPrivate ?? this.isPrivate,
      friends: friends ?? this.friends,
      unlockedTitles: unlockedTitles ?? this.unlockedTitles,
      isBlocked: isBlocked ?? this.isBlocked,
      isFrozen: isFrozen ?? this.isFrozen,
      blockReason: blockReason ?? this.blockReason,
      blockUntil: blockUntil ?? this.blockUntil,
      hasPassword: hasPassword ?? this.hasPassword,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final email = (json['email'] as String? ?? '').trim();
    final role = json['role'] as String? ?? 'user';

    final rawFriends = json['friends'];
    List<String> parsedFriends = [];
    if (rawFriends is List) {
      parsedFriends = rawFriends.map((e) => e.toString()).toList();
    }

    final rawUnlocked = json['unlocked_titles'];
    List<String> parsedUnlocked = ['welcome'];
    if (rawUnlocked is List) {
      parsedUnlocked = rawUnlocked.map((e) => e.toString()).toList();
    }

    final defaultHandle = email.isNotEmpty ? email.split('@').first : 'user';

    return UserProfile(
      id: json['id'] as String? ?? 'user-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: json['display_name'] as String? ?? defaultHandle,
      username: json['username'] as String? ?? defaultHandle,
      role: role,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      customTitle: json['custom_title'] as String?,
      bannerUrl: json['banner_url'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isPrivate: json['is_private'] as bool? ?? false,
      friends: parsedFriends,
      unlockedTitles: parsedUnlocked,
      isBlocked: json['is_blocked'] as bool? ?? false,
      isFrozen: json['is_frozen'] as bool? ?? false,
      blockReason: json['block_reason'] as String?,
      blockUntil: json['block_until'] != null
          ? DateTime.tryParse(json['block_until'].toString())
          : null,
      hasPassword: json['has_password'] as bool? ??
          _computeHasPassword(json['id'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'username': username.isNotEmpty ? username : handle,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'custom_title': customTitle,
      'banner_url': bannerUrl,
      'avatar_url': avatarUrl,
      'is_private': isPrivate,
      'friends': friends,
      'unlocked_titles': unlockedTitles,
      'is_blocked': isBlocked,
      'is_frozen': isFrozen,
      'block_reason': blockReason,
      'block_until': blockUntil?.toIso8601String(),
      'has_password': hasPassword,
    };
  }
}
