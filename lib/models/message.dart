import 'dart:convert';

enum Role { user, assistant, system }

class Message {
  final String id;
  final Role role;
  final String content;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  static Message fromJson(Map<String, dynamic> json) {
    try {
      return Message(
        id: json['id'] as String,
        role: Role.values.firstWhere((r) => r.name == json['role']),
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
    } catch (e, st) {
      print('Error decoding message: $e\n$st\n$json');
      // Return a dummy message to avoid nulls, but mark as system error
      return Message(
        id: 'error',
        role: Role.system,
        content: 'Error loading message',
        createdAt: DateTime.now(),
      );
    }
  }

  static String encodeList(List<Message> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<Message> decodeList(String s) =>
      (jsonDecode(s) as List<dynamic>).map((e) => Message.fromJson(e)).toList();
}
