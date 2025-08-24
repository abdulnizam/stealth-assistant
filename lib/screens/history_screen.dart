import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../models/message.dart';
import '../widgets/markdown_message.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ScrollController _scroll = ScrollController();
  bool _showScrollDown = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final atBottom =
          _scroll.offset >= (_scroll.position.maxScrollExtent - 32);
      if (_showScrollDown == atBottom) {
        setState(() {
          _showScrollDown = !atBottom;
        });
      }
    });
  }

  void _scrollToBottom() {
    if (!mounted || !_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    _scroll
        .animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    )
        .then((_) {
      // If not at the bottom, try again (rare, but can happen)
      if (mounted &&
          _scroll.hasClients &&
          _scroll.offset < _scroll.position.maxScrollExtent - 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final items = storage.messages;
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Stack(
        children: [
          items.isEmpty
              ? const Center(child: Text('No history yet.'))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final m = items[i];
                    return MarkdownMessage(
                        text: m.content, isUser: m.role == Role.user);
                  },
                ),
          if (_showScrollDown)
            Positioned(
              right: 18,
              bottom: 90,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                onPressed: _scrollToBottom,
                child: const Icon(Icons.arrow_downward),
                tooltip: 'Scroll to bottom',
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: FilledButton.tonal(
            onPressed: items.isEmpty
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear history?'),
                        content:
                            const Text('This will remove all saved messages.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Clear')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await context.read<StorageService>().clear();
                    }
                  },
            child: const Text('Clear All'),
          ),
        ),
      ),
    );
  }
}
