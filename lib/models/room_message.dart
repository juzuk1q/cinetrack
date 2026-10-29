class RoomMessage {
  final String id;
  final String userName;
  final String text;
  final DateTime createdAt;

  const RoomMessage({
    required this.id,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  factory RoomMessage.fromJson(Map<String, dynamic> json) {
    return RoomMessage(
      id: json['id'] as String,
      userName: json['user_name'] as String? ?? 'Зритель',
      text: json['text'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_name': userName,
      'text': text,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
