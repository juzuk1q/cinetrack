class RoomMessage {
  final String id;
  final String userName;
  final String text;
  final DateTime createdAt;
  final String? senderId;

  const RoomMessage({
    required this.id,
    required this.userName,
    required this.text,
    required this.createdAt,
    this.senderId,
  });

  factory RoomMessage.fromJson(Map<String, dynamic> json) {
    return RoomMessage(
      id: (json['id'] ?? '').toString(),
      userName: json['user_name'] as String? ?? 'Зритель',
      text: json['text'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      senderId: (json['user_id'] ?? json['sender_id']) as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_name': userName,
      'text': text,
      'created_at': createdAt.toIso8601String(),
      if (senderId != null) 'user_id': senderId,
      if (senderId != null) 'sender_id': senderId,
    };
  }
}
