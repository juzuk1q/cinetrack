import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/friend_request.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';

class FriendState {
  final List<UserProfile> friends;
  final List<FriendRequest> incomingRequests;
  final List<FriendRequest> outgoingRequests;
  final bool isLoading;
  final String? error;

  const FriendState({
    this.friends = const [],
    this.incomingRequests = const [],
    this.outgoingRequests = const [],
    this.isLoading = false,
    this.error,
  });

  FriendState copyWith({
    List<UserProfile>? friends,
    List<FriendRequest>? incomingRequests,
    List<FriendRequest>? outgoingRequests,
    bool? isLoading,
    String? error,
  }) {
    return FriendState(
      friends: friends ?? this.friends,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      outgoingRequests: outgoingRequests ?? this.outgoingRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class FriendNotifier extends StateNotifier<FriendState> {
  final Ref _ref;
  RealtimeChannel? _realtimeChannel;
  String? _currentUserId;

  FriendNotifier(this._ref) : super(const FriendState()) {
    final user = _ref.read(currentUserProvider);
    if (user != null) {
      load(user.id);
    }
  }

  void setupForUser(String userId) {
    if (_currentUserId == userId && !state.isLoading) return;
    _currentUserId = userId;
    _subscribe(userId);
    load(userId);
  }

  void _subscribe(String userId) {
    _realtimeChannel?.unsubscribe();
    try {
      _realtimeChannel = supabase.channel('public:friend_requests:$userId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          callback: (payload) {
            load(userId, silent: true);
          },
        )
        ..subscribe();
    } catch (e) {
      debugPrint('Realtime channel error in FriendNotifier: $e');
    }
  }

  Future<void> load(String userId, {bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      List<Map<String, dynamic>> rawRequests = [];
      try {
        final rows = await supabase
            .from('friend_requests')
            .select()
            .or('sender_id.eq.$userId,receiver_id.eq.$userId');
        rawRequests = List<Map<String, dynamic>>.from(rows);
      } catch (e) {
        debugPrint('friend_requests table not available: $e');
      }

      final Set<String> relatedUserIds = {};
      for (final r in rawRequests) {
        final sId = r['sender_id']?.toString();
        final rId = r['receiver_id']?.toString();
        if (sId != null && sId.isNotEmpty && sId != userId) relatedUserIds.add(sId);
        if (rId != null && rId.isNotEmpty && rId != userId) relatedUserIds.add(rId);
      }

      // Also check legacy friends from profile
      final myProfile = _ref.read(userProfileProvider).valueOrNull;
      final legacyFriendHandles = myProfile?.friends ?? [];

      final Map<String, UserProfile> profilesById = {};
      final Map<String, UserProfile> profilesByHandle = {};

      if (relatedUserIds.isNotEmpty) {
        try {
          final profileRows = await supabase
              .from('profiles')
              .select()
              .inFilter('id', relatedUserIds.toList());
          for (final p in profileRows) {
            final up = UserProfile.fromJson(Map<String, dynamic>.from(p));
            profilesById[up.id] = up;
            profilesByHandle[up.handle.toLowerCase()] = up;
            profilesByHandle[up.username.toLowerCase()] = up;
          }
        } catch (e) {
          debugPrint('Error fetching friend profiles by ID: $e');
        }
      }

      // Check missing legacy friends
      final missingHandles = legacyFriendHandles.where(
        (h) => !profilesByHandle.containsKey(h.toLowerCase()),
      ).toList();

      if (missingHandles.isNotEmpty) {
        try {
          final legacyRows = await supabase
              .from('profiles')
              .select()
              .inFilter('username', missingHandles);
          for (final p in legacyRows) {
            final up = UserProfile.fromJson(Map<String, dynamic>.from(p));
            profilesById[up.id] = up;
            profilesByHandle[up.handle.toLowerCase()] = up;
            profilesByHandle[up.username.toLowerCase()] = up;
          }
        } catch (e) {
          debugPrint('Error fetching legacy friend profiles: $e');
        }
      }

      final List<UserProfile> friendsList = [];
      final List<FriendRequest> incoming = [];
      final List<FriendRequest> outgoing = [];
      final Set<String> friendIds = {};

      for (final r in rawRequests) {
        final sId = r['sender_id']?.toString() ?? '';
        final rId = r['receiver_id']?.toString() ?? '';
        final statusStr = r['status']?.toString() ?? 'pending';

        final senderProfile = profilesById[sId];
        final receiverProfile = profilesById[rId];

        final req = FriendRequest.fromJson({
          ...r,
          if (senderProfile != null) 'sender': senderProfile.toJson(),
          if (receiverProfile != null) 'receiver': receiverProfile.toJson(),
        });

        if (statusStr == 'accepted') {
          final otherId = (sId == userId) ? rId : sId;
          final otherProf = profilesById[otherId];
          if (otherProf != null && !friendIds.contains(otherProf.id)) {
            friendsList.add(otherProf);
            friendIds.add(otherProf.id);
          }
        } else if (statusStr == 'pending') {
          if (rId == userId) {
            incoming.add(req);
          } else if (sId == userId) {
            outgoing.add(req);
          }
        }
      }

      // Include legacy friends if not already represented
      for (final handle in legacyFriendHandles) {
        final match = profilesByHandle[handle.toLowerCase()];
        if (match != null && !friendIds.contains(match.id)) {
          friendsList.add(match);
          friendIds.add(match.id);
        }
      }

      state = state.copyWith(
        friends: friendsList,
        incomingRequests: incoming,
        outgoingRequests: outgoing,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading friend requests: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  FriendshipStatus getFriendshipStatus(String? targetUserId, {String? targetHandle}) {
    final currentUid = _currentUserId ?? supabase.auth.currentUser?.id;
    if (currentUid == null || targetUserId == null || targetUserId.isEmpty) {
      return FriendshipStatus.none;
    }
    if (currentUid == targetUserId) {
      return FriendshipStatus.none;
    }

    // Check friends
    final isFriend = state.friends.any((f) =>
        f.id == targetUserId ||
        (targetHandle != null && f.handle.toLowerCase() == targetHandle.toLowerCase()));
    if (isFriend) return FriendshipStatus.friends;

    // Check incoming
    final hasIncoming = state.incomingRequests.any((r) =>
        r.senderId == targetUserId ||
        (r.senderProfile != null && targetHandle != null &&
            r.senderProfile!.handle.toLowerCase() == targetHandle.toLowerCase()));
    if (hasIncoming) return FriendshipStatus.incomingPending;

    // Check outgoing
    final hasOutgoing = state.outgoingRequests.any((r) =>
        r.receiverId == targetUserId ||
        (r.receiverProfile != null && targetHandle != null &&
            r.receiverProfile!.handle.toLowerCase() == targetHandle.toLowerCase()));
    if (hasOutgoing) return FriendshipStatus.outgoingPending;

    return FriendshipStatus.none;
  }

  Future<void> sendFriendRequest(UserProfile targetUser) async {
    final myUid = _currentUserId ?? supabase.auth.currentUser?.id;
    if (myUid == null || myUid == targetUser.id) return;

    // If incoming request from targetUser exists, accept it instead
    final incoming = state.incomingRequests.where((r) => r.senderId == targetUser.id).toList();
    if (incoming.isNotEmpty) {
      await acceptRequest(incoming.first);
      return;
    }

    // Check if already friends or outgoing pending
    if (state.friends.any((f) => f.id == targetUser.id)) return;
    if (state.outgoingRequests.any((r) => r.receiverId == targetUser.id)) return;

    try {
      try {
        await supabase.from('friend_requests').upsert({
          'sender_id': myUid,
          'receiver_id': targetUser.id,
          'status': 'pending',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'sender_id,receiver_id');
      } catch (tableErr) {
        debugPrint('friend_requests table unavailable, adding friend directly: $tableErr');
        if (!state.friends.any((f) => f.id == targetUser.id)) {
          state = state.copyWith(friends: [...state.friends, targetUser]);
        }
      }

      // Sync legacy friends list & unlock achievement
      _ref.read(profileCustomizationProvider.notifier).addFriend(targetUser.handle);

      await load(myUid, silent: true);
    } catch (e) {
      debugPrint('Error sending friend request: $e');
    }
  }

  Future<void> acceptRequest(FriendRequest request) async {
    final myUid = _currentUserId ?? supabase.auth.currentUser?.id;
    if (myUid == null) return;

    try {
      try {
        await supabase.from('friend_requests').update({
          'status': 'accepted',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', request.id);
      } catch (tableErr) {
        debugPrint('friend_requests table update error: $tableErr');
      }

      final otherHandle = request.senderProfile?.handle;
      if (otherHandle != null && otherHandle.isNotEmpty) {
        _ref.read(profileCustomizationProvider.notifier).addFriend(otherHandle);
      }

      await load(myUid, silent: true);
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
    }
  }

  Future<void> rejectRequest(FriendRequest request) async {
    final myUid = _currentUserId ?? supabase.auth.currentUser?.id;
    if (myUid == null) return;

    try {
      try {
        await supabase.from('friend_requests').delete().eq('id', request.id);
      } catch (tableErr) {
        debugPrint('friend_requests table delete error: $tableErr');
      }
      await load(myUid, silent: true);
    } catch (e) {
      debugPrint('Error rejecting friend request: $e');
    }
  }

  Future<void> cancelRequest(FriendRequest request) async {
    final myUid = _currentUserId ?? supabase.auth.currentUser?.id;
    if (myUid == null) return;

    try {
      try {
        await supabase.from('friend_requests').delete().eq('id', request.id);
      } catch (tableErr) {
        debugPrint('friend_requests table delete error: $tableErr');
      }
      await load(myUid, silent: true);
    } catch (e) {
      debugPrint('Error canceling friend request: $e');
    }
  }

  Future<void> removeFriend(String targetUserId, {String? targetHandle}) async {
    final myUid = _currentUserId ?? supabase.auth.currentUser?.id;
    if (myUid == null) return;

    try {
      try {
        await supabase.from('friend_requests').delete().or(
          'and(sender_id.eq.$myUid,receiver_id.eq.$targetUserId),and(sender_id.eq.$targetUserId,receiver_id.eq.$myUid)',
        );
      } catch (tableErr) {
        debugPrint('friend_requests table delete error: $tableErr');
      }

      if (targetHandle != null && targetHandle.isNotEmpty) {
        _ref.read(profileCustomizationProvider.notifier).removeFriend(targetHandle);
      }

      state = state.copyWith(
        friends: state.friends.where((f) => f.id != targetUserId && f.handle.toLowerCase() != targetHandle?.toLowerCase()).toList(),
      );

      await load(myUid, silent: true);
    } catch (e) {
      debugPrint('Error removing friend: $e');
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}

final friendProvider = StateNotifierProvider<FriendNotifier, FriendState>((ref) {
  final notifier = FriendNotifier(ref);
  final user = ref.watch(currentUserProvider);
  if (user != null) {
    notifier.setupForUser(user.id);
  }
  return notifier;
});
