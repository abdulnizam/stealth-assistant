/// Converts a GPT-5 response to the legacy OpenAI structure for UI compatibility.
Map<String, dynamic> convertGpt5ResponseToLegacy(Map<String, dynamic> gpt5) {
  // Defensive: ensure choices/message/content exist
  final choices = gpt5['choices'] as List?;
  final firstChoice =
      (choices != null && choices.isNotEmpty) ? choices[0] : null;
  final message = firstChoice != null
      ? firstChoice['message'] as Map<String, dynamic>?
      : null;
  final content = message != null ? message['content'] : null;

  return {
    'id': gpt5['id'],
    'object': gpt5['object'] ?? 'chat.completion',
    'created': gpt5['created'],
    'model': gpt5['model'],
    'choices': [
      {
        'index': 0,
        'finish_reason':
            firstChoice != null ? firstChoice['finish_reason'] : null,
        'message': {
          'role': message != null ? message['role'] : 'assistant',
          'content': content ?? '',
        },
      }
    ],
    'usage': gpt5['usage'] ?? {},
  };
}
// Model constants, endpoints, and payload builders for all LLM providers

// Enum for all supported LLM providers
enum ModelProvider {
  local,
  openai,
  anthropic,
  gemini,
  cohere,
  mistral,
  groq,
}

// Model lists for each provider
const Map<ModelProvider, List<String>> kProviderModels = {
  ModelProvider.local: [
    'gemma:7b-instruct',
    'codellama:7b-instruct',
  ],
  ModelProvider.openai: [
    'gpt-5',
    'gpt-5-mini',
    'gpt-5-nano',
    'gpt-4o-mini',
    'gpt-3.5-turbo',
  ],
  ModelProvider.anthropic: [
    'claude-3-opus-20240229',
    'claude-3-sonnet-20240229',
    'claude-3-haiku-20240307',
  ],
  ModelProvider.gemini: [
    'gemini-1.5-pro-latest',
    'gemini-1.0-pro',
  ],
  ModelProvider.cohere: [
    'command-r-plus',
    'command-r',
    'command',
  ],
  ModelProvider.mistral: [
    'mistral-large-latest',
    'mistral-medium-latest',
    'mistral-small-latest',
  ],
  ModelProvider.groq: [
    'llama3-70b-8192',
    'mixtral-8x7b-32768',
    'gemma-7b-it',
  ],
};

// Endpoints for each provider
String getProviderEndpoint(ModelProvider provider) {
  switch (provider) {
    case ModelProvider.openai:
      return 'https://api.openai.com/v1/chat/completions';
    case ModelProvider.anthropic:
      return 'https://api.anthropic.com/v1/messages';
    case ModelProvider.gemini:
      return 'https://generativelanguage.googleapis.com/v1beta/models';
    case ModelProvider.cohere:
      return 'https://api.cohere.ai/v1/chat';
    case ModelProvider.mistral:
      return 'https://api.mistral.ai/v1/chat/completions';
    case ModelProvider.groq:
      return 'https://api.groq.com/openai/v1/chat/completions';
    case ModelProvider.local:
      return '';
  }
}

// Headers for each provider
Map<String, String> getProviderHeaders(ModelProvider provider, String? apiKey) {
  switch (provider) {
    case ModelProvider.openai:
    case ModelProvider.mistral:
    case ModelProvider.groq:
      return {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey.isNotEmpty)
          'Authorization': 'Bearer $apiKey',
      };
    case ModelProvider.anthropic:
      return {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey.isNotEmpty) 'x-api-key': apiKey,
      };
    case ModelProvider.gemini:
      return {
        'Content-Type': 'application/json',
      };
    case ModelProvider.cohere:
      return {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey.isNotEmpty)
          'Authorization': 'Bearer $apiKey',
      };
    case ModelProvider.local:
      return {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey.isNotEmpty)
          'Authorization': 'Bearer $apiKey',
      };
  }
}

// Payload builder for each provider
Object buildProviderPayload(
    ModelProvider provider, String model, String prompt, int maxTokens) {
  switch (provider) {
    case ModelProvider.openai:
      // Use 'max_completion_tokens' for gpt-5 models, 'max_tokens' otherwise
      final isGpt5 = model == 'gpt-5' || model.startsWith('gpt-5-');
      return {
        "model": model,
        "messages": [
          {"role": "system", "content": "You are a helpful assistant."},
          {"role": "user", "content": prompt},
        ],
        if (isGpt5) ...{
          "max_completion_tokens": maxTokens,
          "verbosity": "medium",
          "reasoning_effort": "minimal",
        } else ...{
          "temperature": 0.7,
          "max_tokens": maxTokens,
        }
      };
    case ModelProvider.mistral:
    case ModelProvider.groq:
      return {
        "model": model,
        "messages": [
          {"role": "system", "content": "You are a helpful assistant."},
          {"role": "user", "content": prompt},
        ],
        "temperature": 0.7,
        "max_tokens": maxTokens,
      };
    case ModelProvider.anthropic:
      return {
        "model": model,
        "max_tokens": maxTokens,
        "messages": [
          {"role": "user", "content": prompt},
        ],
      };
    case ModelProvider.gemini:
      return {
        "contents": [
          {
            "role": "user",
            "parts": [
              {"text": prompt}
            ]
          },
        ],
        "generationConfig": {"maxOutputTokens": maxTokens, "temperature": 0.7},
      };
    case ModelProvider.cohere:
      return {
        "model": model,
        "message": prompt,
        "temperature": 0.7,
        "max_tokens": maxTokens,
      };
    case ModelProvider.local:
      return {
        'model': model,
        'prompt': prompt,
        'stream': false,
        'keep_alive': '5m',
        'options': {
          'num_predict': maxTokens,
          'num_thread': 4,
        },
      };
  }
}
