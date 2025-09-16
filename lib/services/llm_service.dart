import 'dart:async'; // TimeoutException
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import '../utils/model_constants.dart';

class LlmService {
  LlmService({
    required this.provider,
    required this.model,
    this.baseUrl = '',
    this.apiKey,
    this.numPredict = 384,
    this.numThread = 4,
    this.keepAlive = const Duration(minutes: 5),
    this.timeout = const Duration(seconds: 45),
    this.retryBackoff = const Duration(seconds: 3),
    this.tokensPerSecondGuess = 18.0,
    this.timeoutOverhead = const Duration(seconds: 3),
    this.timeoutRetryDegrade = 0.65,
  });

  ModelProvider provider;
  String model;
  String baseUrl;
  final String? apiKey;
  int numPredict;
  int numThread;
  Duration keepAlive;
  Duration timeout;

  Duration retryBackoff;
  double tokensPerSecondGuess;
  Duration timeoutOverhead;
  double timeoutRetryDegrade;

  // ----------------- helpers -----------------

  Uri _generateUri() {
    if (provider == ModelProvider.local) {
      var base = baseUrl.trim();
      if (base.isEmpty) {
        throw StateError('Base URL is empty. Set it in Settings.');
      }
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      if (!base.endsWith('/api/generate')) base = '$base/api/generate';
      return Uri.parse(base);
    } else if (provider == ModelProvider.gemini) {
      // Gemini endpoint needs model in path
      return Uri.parse(
          '${getProviderEndpoint(provider)}/$model:generateContent');
    } else {
      return Uri.parse(getProviderEndpoint(provider));
    }
  }

  Map<String, String> _headers() => getProviderHeaders(provider, apiKey);

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
    final payload = buildProviderPayload(provider, model, prompt, numPredict);
    final body = jsonEncode(payload);
    // print("[GPT-5 DEBUG] request payload: " + body);
    try {
      final res = await http
          .post(uri, headers: _headers(), body: body)
          .timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(
            '${provider.name} error: ${res.statusCode} ${res.body}');
      }
      final data = jsonDecode(res.body);
      // Parse response for each provider
      switch (provider) {
        case ModelProvider.openai:
          // If gpt-5 or gpt-5-* model, convert to legacy structure
          if (model == 'gpt-5' || model.startsWith('gpt-5-')) {
            final legacy = convertGpt5ResponseToLegacy(data);
            final content =
                legacy["choices"]?[0]?["message"]?["content"]?.toString() ?? '';
            return content;
          }
          return data["choices"]?[0]?["message"]?["content"]?.toString() ?? '';
        case ModelProvider.mistral:
        case ModelProvider.groq:
        case ModelProvider.perplexity:
          return data["choices"]?[0]?["message"]?["content"]?.toString() ?? '';
        case ModelProvider.anthropic:
          return data["content"]?.toString() ?? '';
        case ModelProvider.gemini:
          return data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"]
                  ?.toString() ??
              '';
        case ModelProvider.cohere:
          return data["text"]?.toString() ?? '';
        case ModelProvider.local:
          final resp = data['response'];
          if (resp is String && resp.isNotEmpty) return resp;
          return (data['text'] ?? data['answer'] ?? data['message'] ?? '')
              .toString();
      }
    } on TimeoutException catch (e) {
      throw Exception('${provider.name} timeout: $e');
    } on SocketException catch (e) {
      throw Exception('Cannot reach ${provider.name} — network error: $e');
    } on FormatException catch (e) {
      throw Exception('Bad response format from ${provider.name} — $e');
    } catch (e) {
      throw Exception('Unexpected error calling ${provider.name} — $e');
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
