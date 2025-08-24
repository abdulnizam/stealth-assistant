import 'dart:async'; // TimeoutException
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;

class LlmService {
  LlmService({
    required this.baseUrl, // e.g. http://192.168.0.54:11434
    required this.model, // e.g. gemma:7b-instruct / codellama:7b-instruct
    this.apiKey, // not needed for local Ollama
    this.numPredict = 384, // max output tokens (you can raise safely)
    this.numThread = 4, // set to your Mac perf cores
    this.keepAlive = const Duration(minutes: 5),
    this.timeout = const Duration(seconds: 45),

    // Tuning knobs (MUTABLE so you can reconfigure at runtime)
    this.retryBackoff = const Duration(seconds: 3),
    this.tokensPerSecondGuess = 18.0, // conservative decode speed guess
    this.timeoutOverhead = const Duration(seconds: 3),
    this.timeoutRetryDegrade = 0.65, // on timeout, num_predict *= 0.65
  });

  // Core config (mutable)
  String baseUrl;
  String model;
  final String? apiKey;

  int numPredict;
  int numThread;
  Duration keepAlive;
  Duration timeout;

  // Adaptive/behavior knobs (mutable)
  Duration retryBackoff;
  double tokensPerSecondGuess;
  Duration timeoutOverhead;
  double timeoutRetryDegrade;

  // ----------------- helpers -----------------

  Uri _generateUri() {
    var base = baseUrl.trim();
    if (base.isEmpty)
      throw StateError('Base URL is empty. Set it in Settings.');
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    if (!base.endsWith('/api/generate')) base = '$base/api/generate';
    return Uri.parse(base);
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey!.isNotEmpty)
          'Authorization': 'Bearer $apiKey',
      };

  String _keepAliveToString() {
    final s = keepAlive.inSeconds;
    if (s % 3600 == 0) return '${s ~/ 3600}h';
    if (s % 60 == 0) return '${s ~/ 60}m';
    return '${s}s';
  }

  Duration _adaptiveTimeout(int np) {
    // Estimate time for np tokens at tokensPerSecondGuess + overhead.
    final estSeconds = (np / tokensPerSecondGuess).ceil();
    final est = Duration(seconds: estSeconds) + timeoutOverhead;
    // Use whichever is larger: configured timeout vs adaptive estimate
    return est > timeout ? est : timeout;
  }

  Future<http.Response> _postWithTimeout(Uri uri, String body, Duration to) {
    return http.post(uri, headers: _headers(), body: body).timeout(to);
  }

  // ----------------- public API -----------------

  /// Non-streaming generate that auto-adjusts timeout and retries once on timeout.
  Future<String> generate(String prompt) async {
    final uri = _generateUri();

    // Attempt 1
    final attempt1Predict = numPredict;
    final attempt1Timeout = _adaptiveTimeout(attempt1Predict);
    // Optional: debug log
    // ignore: avoid_print
    print(
        '[LlmService] POST $uri model=$model np=$attempt1Predict timeout=${attempt1Timeout.inSeconds}s');

    final body1 = jsonEncode({
      'model': model,
      'prompt': prompt,
      'stream': false,
      'keep_alive': _keepAliveToString(),
      'options': {
        'num_predict': attempt1Predict,
        'num_thread': numThread,
      },
    });

    try {
      final res = await _postWithTimeout(uri, body1, attempt1Timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('LLM error: ${res.statusCode} ${res.body}');
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final resp = map['response'];
      if (resp is String && resp.isNotEmpty) return resp;
      return (map['text'] ?? map['answer'] ?? map['message'] ?? '').toString();
    } on TimeoutException catch (e) {
      // Attempt 2 (degraded num_predict)
      final attempt2Predict =
          (attempt1Predict * timeoutRetryDegrade).floor().clamp(32, 4096);
      final attempt2Timeout = _adaptiveTimeout(attempt2Predict);
      // ignore: avoid_print
      print(
          '[LlmService] Timeout after ${attempt1Timeout.inSeconds}s; retrying with '
          'np=$attempt2Predict timeout=${attempt2Timeout.inSeconds}s (err=$e)');

      await Future.delayed(retryBackoff);

      final body2 = jsonEncode({
        'model': model,
        'prompt': prompt,
        'stream': false,
        'keep_alive': _keepAliveToString(),
        'options': {
          'num_predict': attempt2Predict,
          'num_thread': numThread,
        },
      });

      final res2 = await _postWithTimeout(uri, body2, attempt2Timeout);
      if (res2.statusCode < 200 || res2.statusCode >= 300) {
        throw Exception('LLM error (retry): ${res2.statusCode} ${res2.body}');
      }
      final map2 = jsonDecode(res2.body) as Map<String, dynamic>;
      final resp2 = map2['response'];
      if (resp2 is String && resp2.isNotEmpty) return resp2;
      return (map2['text'] ?? map2['answer'] ?? map2['message'] ?? '')
          .toString();
    } on SocketException catch (e) {
      throw Exception('Cannot reach Ollama at $uri — network error: $e');
    } on FormatException catch (e) {
      throw Exception('Bad response format from $uri — $e');
    } catch (e) {
      throw Exception('Unexpected error calling $uri — $e');
    }
  }

  /// Optional: call once at app start to keep the selected model warm.
  Future<void> warmup({String prompt = 'ok'}) async {
    try {
      await generate(prompt);
    } catch (_) {/* best-effort */}
  }

  /// Runtime reconfiguration (all fields here are mutable).
  void reconfigure({
    String? baseUrl,
    String? model,
    int? numPredict,
    int? numThread,
    Duration? keepAlive,
    Duration? timeout,
    Duration? retryBackoff,
    double? tokensPerSecondGuess,
    Duration? timeoutOverhead,
    double? timeoutRetryDegrade,
  }) {
    if (baseUrl != null) this.baseUrl = baseUrl;
    if (model != null) this.model = model;
    if (numPredict != null) this.numPredict = numPredict;
    if (numThread != null) this.numThread = numThread;
    if (keepAlive != null) this.keepAlive = keepAlive;
    if (timeout != null) this.timeout = timeout;
    if (retryBackoff != null) this.retryBackoff = retryBackoff;
    if (tokensPerSecondGuess != null)
      this.tokensPerSecondGuess = tokensPerSecondGuess;
    if (timeoutOverhead != null) this.timeoutOverhead = timeoutOverhead;
    if (timeoutRetryDegrade != null)
      this.timeoutRetryDegrade = timeoutRetryDegrade;
  }
}
