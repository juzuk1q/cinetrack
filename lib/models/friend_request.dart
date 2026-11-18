import 'user_profile.dart';

enum FriendRequestStatus {
  pending,
  accepted,
  rejected,
}

enum FriendshipStatus {
  none,
  outgoingPending,
  incomingPending,
  friends,
}

class FriendRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserProfile? senderProfile;
  final UserProfile? receiverProfile;

  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.status = FriendRequestStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.senderProfile,
    this.receiverProfile,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    FriendRequestStatus parseStatus(String? val) {
      switch (val) {
        case 'accepted':
          return FriendRequestStatus.accepted;
        case 'rejected':
          return FriendRequestStatus.rejected;
        case 'pending':
        default:
          return FriendRequestStatus.pending;
      }
    }

    UserProfile? sender;
    if (json['sender'] is Map<String, dynamic>) {
      sender = UserProfile.fromJson(json['sender'] as Map<String, dynamic>);
    }
    UserProfile? receiver;
    if (json['receiver'] is Map<String, dynamic>) {
      receiver = UserProfile.fromJson(json['receiver'] as Map<String, dynamic>);
    }

    return FriendRequest(
      id: json['id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      receiverId: json['receiver_id'] as String? ?? '',
      status: parseStatus(json['status'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      senderProfile: sender,
      receiverProfile: receiver,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FriendRequest copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    FriendRequestStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserProfile? senderProfile,
    UserProfile? receiverProfile,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      senderProfile: senderProfile ?? this.senderProfile,
      receiverProfile: receiverProfile ?? this.receiverProfile,
    );
  }
}
