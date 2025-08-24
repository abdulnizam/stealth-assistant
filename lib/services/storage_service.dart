import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';

class StorageService extends ChangeNotifier {
  static const _kMessagesKey = 'messages';
  List<Message> _messages = [];
  bool _ready = false;

  bool get isReady => _ready;
  List<Message> get messages => List.unmodifiable(_messages);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMessagesKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _messages = Message.decodeList(raw);
      } catch (_) {
        _messages = [];
      }
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> addMessage(Role role, String content) async {
    final msg = Message(
      id: const Uuid().v4(),
      role: role,
      content: content,
      createdAt: DateTime.now(),
    );
    _messages.add(msg);
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _messages.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMessagesKey, Message.encodeList(_messages));
  }
}