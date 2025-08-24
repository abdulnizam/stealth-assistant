import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../services/storage_service.dart';
import '../services/speech_service.dart';
import '../services/llm_service.dart';
import '../utils/model_constants.dart';
import '../utils/constants.dart';
import '../widgets/markdown_message.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  bool _showScrollDown = false;
  // Robust scroll helper (waits for layout; retries once)
  void _safeScrollToBottom() {
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
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _safeScrollToBottom());
      }
    });
  }

  Future<void> _send(BuildContext context, {String? overrideText}) async {
    if (_sending) return;
    if (_speech.isListening) return; // Send disabled while mic is active

    final text = (overrideText ?? _input.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _sending = true;
      _loadingTail = true;
    });

    // Hide keyboard immediately
    FocusScope.of(context).unfocus();

    final storage = context.read<StorageService>();
    // Clear input (user is done typing)
    _input.clear();

    // 1) Persist user message
    await storage.addMessage(Role.user, text);
    if (storage.messages.isNotEmpty) {
      _safeScrollToBottom();
    }

    // 2) Always reload latest model config before sending
    String answer = '';
    try {
      final (base, key, model, provider) = await AppConfig.load();
      final modelProvider = ModelProvider.values.firstWhere(
        (p) => p.name == provider,
        orElse: () => ModelProvider.local,
      );
      _llm = LlmService(
        provider: modelProvider,
        baseUrl: base,
        apiKey: (key.isEmpty) ? null : key,
        model: model,
      );
      if (_llm == null) {
        answer =
            "Model not configured. Open Settings and set Base URL & Model.";
      } else {
        answer = await _llm!.generate(text);
      }
    } catch (e) {
      answer = "Sorry, I hit an error: $e";
    } finally {
      // Always reset loader state
      if (mounted) {
        setState(() {
          _sending = false;
          _loadingTail = false;
        });
      }
    }

    // 3) Persist assistant message
    await storage.addMessage(Role.assistant, answer);
    if (storage.messages.isNotEmpty) {
      _safeScrollToBottom();
    }
  }

  Future<void> _toggleMic() async {
    if (_micToggling || _sending) return; // don't allow mic while sending
    setState(() => _micToggling = true);

    // Always hide the keyboard when toggling mic
    FocusScope.of(context).unfocus();

    try {
      if (_speech.isListening) {
        // STOP LISTENING
        await _speech.stop();
        // After stop: auto-send whatever was captured
        final finalText = _tempTranscript?.trim() ?? '';
        setState(() {
          _tempTranscript = null;
        });
        if (finalText.isNotEmpty) {
          await _send(context, overrideText: finalText);
        }
      } else {
        // START LISTENING
        _input.clear();
        setState(() {
          _tempTranscript = '';
        });
        // Stream partial transcripts directly into the chat window only
        await _speech.start((partial) {
          setState(() {
            _tempTranscript = partial;
          });
        });
      }
    } finally {
      if (!mounted) return;
      setState(() => _micToggling = false);
    }
  }

  static final RouteObserver<ModalRoute<void>> _routeObserver =
      RouteObserver<ModalRoute<void>>();
  String? _tempTranscript;
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  final _speech = SpeechService();
  LlmService? _llm;
  bool _sending = false; // API call in progress (Send)
  bool _micToggling = false; // mic start/stop in progress (spinner on mic)
  bool _loadingTail =
      false; // tail spinner item in the list (assistant thinking)

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
    _bootstrap();

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

  Future<void> _bootstrap() async {
    await _speech.init();
    final (base, key, model, provider) = await AppConfig.load();
    final modelProvider = ModelProvider.values.firstWhere(
      (p) => p.name == provider,
      orElse: () => ModelProvider.local,
    );
    setState(() {
      _llm = LlmService(
        provider: modelProvider,
        baseUrl: base,
        apiKey: (key.isEmpty) ? null : key,
        model: model,
      );
    });
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    _routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute? route = ModalRoute.of(context);
    if (route is PageRoute) {
      _routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // Called when coming back to this screen
    _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final messages = storage.messages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stealth Assistant'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                  },
                  child: Builder(
                    builder: (context) {
                      // ...existing code...
                      final totalCount = messages.length +
                          (_loadingTail ? 1 : 0) +
                          (_tempTranscript != null &&
                                  _speech.isListening &&
                                  _tempTranscript!.isNotEmpty
                              ? 1
                              : 0);
                      if (totalCount == 0) {
                        return const Center(child: Text('No messages yet.'));
                      }
                      return ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 12),
                        itemCount: totalCount,
                        itemBuilder: (context, index) {
                          final showTemp = _tempTranscript != null &&
                              _speech.isListening &&
                              _tempTranscript!.isNotEmpty;
                          final hasLoader = _loadingTail;
                          final tempIndex = messages.length;
                          final loaderIndex =
                              messages.length + (showTemp ? 1 : 0);

                          if (showTemp &&
                              index == tempIndex &&
                              (_tempTranscript ?? '').isNotEmpty) {
                            // Show temp transcript as last message
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    _tempTranscript ?? '',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          if (hasLoader && index == loaderIndex) {
                            // tail loader item (assistant thinking)
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          // Normal messages
                          final msgIndex = index;
                          if (msgIndex < messages.length && msgIndex >= 0) {
                            final m = messages[msgIndex];
                            return MarkdownMessage(
                              text: m.content,
                              isUser: m.role == Role.user,
                            );
                          }
                          // Should never reach here
                          return const SizedBox.shrink();
                        },
                      );
                    },
                  ),
                ),
              ),
              // Bottom bar (input area)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _speech.isListening
                        ? Center(
                            key: const ValueKey('mic-active'),
                            child: AnimatedScale(
                              scale: 1.33,
                              duration: const Duration(milliseconds: 300),
                              child: _MicButton(
                                isListening: true,
                                isBusy: _micToggling,
                                onPressed: _toggleMic,
                                size: 44,
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 5.0),
                            child: Row(
                              key: const ValueKey('mic-inactive'),
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _input,
                                    focusNode: _inputFocus,
                                    minLines: 1,
                                    maxLines: 5,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) =>
                                        (_sending) ? null : _send(context),
                                    decoration: const InputDecoration(
                                      hintText: 'Type a message…',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(24)),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _MicButton(
                                  isListening: false,
                                  isBusy: _micToggling || _sending,
                                  onPressed: (_sending) ? null : _toggleMic,
                                ),
                                const SizedBox(width: 6),
                                _SendButton(
                                  isBusy: _sending,
                                  enabled: !_sending &&
                                      _input.text.trim().isNotEmpty,
                                  onPressed: () => _send(context),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          // Floating scroll-to-bottom button
          if (_showScrollDown)
            Positioned(
              right: 18,
              bottom: 90,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                onPressed: _safeScrollToBottom,
                child: const Icon(Icons.arrow_downward),
                tooltip: 'Scroll to bottom',
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact mic button with built-in busy state
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.isListening,
    required this.isBusy,
    required this.onPressed,
    this.size = 48,
  });

  final bool isListening; // true => Stop icon
  final bool isBusy; // show loader overlay
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: size,
          width: size,
          child: IconButton.filled(
            tooltip: isListening ? 'Stop' : 'Mic',
            onPressed: isBusy ? null : onPressed,
            icon: Icon(
              isListening ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: size * 0.5,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: const CircleBorder(),
              fixedSize: Size(size, size),
            ),
          ),
        ),
        if (isBusy)
          SizedBox(
            height: size,
            width: size,
            child: Center(
              child: SizedBox(
                height: size * 0.375,
                width: size * 0.375,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact send button with built-in busy state
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isBusy,
    required this.enabled,
    required this.onPressed,
  });

  final bool isBusy; // show loader
  final bool enabled; // enable/disable
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = (enabled && !isBusy) ? onPressed : null;
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton.filled(
          tooltip: 'Send',
          onPressed: effectiveOnPressed,
          icon: const Icon(Icons.send, color: Colors.white),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: const CircleBorder(),
          ),
        ),
        if (isBusy)
          const SizedBox(
            height: 48,
            width: 48,
            child: Center(
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}
