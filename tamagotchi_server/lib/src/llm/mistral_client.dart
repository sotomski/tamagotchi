import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import 'creature_prompt.dart';
import 'llm_service.dart';

/// The real [LlmService]: Mistral's OpenAI-compatible chat-completions API with
/// structured output. Mirrors the EmailLabs REST precedent (`server.dart`) —
/// `http.post` + `session.passwords[...]` + `jsonDecode` — since server-side raw
/// REST is the right tool (the RPC-only rule governs frontend↔backend).
///
/// scloud allows outbound HTTPS/443 to `api.mistral.ai` (only SMTP egress is
/// blocked). The key comes from `session.passwords['mistralApiKey']`; this class
/// is only constructed when that key is present (see `llmServiceFor`).
class MistralLlmService implements LlmService {
  const MistralLlmService();

  static final Uri _endpoint = Uri.parse(
    'https://api.mistral.ai/v1/chat/completions',
  );

  /// Mistral Small 4 — cheap, low-latency, supports Structured Outputs. Pinned.
  static const String _model = 'mistral-small-2603';

  /// Ample for a two-short-field structured response; keeps the bill small.
  static const int _maxTokens = 768;

  /// Creativity knobs — tuned high on purpose: a Tamagotchi's voice should feel
  /// fresh and surprising every feed (varied invented food names, distinct
  /// reactions), not templated. Values follow Mistral's own guidance:
  ///
  /// - [_temperature] 0.7 is the top of Mistral's recommended band ("higher
  ///   values like 0.7 make the output more random"); Mistral scales temperature
  ///   more aggressively than OpenAI, so 0.7 is genuinely high — pushing past it
  ///   risks incoherence and structured-output drift, so we cap here.
  /// - [_presencePenalty] nudges toward a wider vocabulary ("more diverse and
  ///   creative" per the API) — helps the model coin novel food names.
  /// - [_frequencyPenalty] discourages repeating words, keeping the two fields
  ///   (userResponse + journalNarrative) from echoing each other.
  ///
  /// `strict` json_schema still pins the two-field structure, so these only
  /// shape word choice *inside* the strings — never the response shape. We tune
  /// temperature + penalties and leave `top_p` at default (Mistral advises
  /// altering one of temperature/top_p, not both).
  static const double _temperature = 0.7;
  static const double _presencePenalty = 0.4;
  static const double _frequencyPenalty = 0.3;

  /// JSON-schema envelope enforcing exactly the two output fields. Mistral nests
  /// `{name, schema, strict}` under `json_schema` (the `schema` key is the wire
  /// alias for the schema body); `strict: true` + `additionalProperties: false`
  /// makes the model conform. If a future API change rejects `json_schema`, fall
  /// back to `{type: 'json_object'}` and lean on the prompt's explicit contract.
  static const Map<String, dynamic> _responseFormat = {
    'type': 'json_schema',
    'json_schema': {
      'name': 'creature_interaction',
      'strict': true,
      'schema': {
        'type': 'object',
        'properties': {
          'userResponse': {'type': 'string'},
          'journalNarrative': {'type': 'string'},
        },
        'required': ['userResponse', 'journalNarrative'],
        'additionalProperties': false,
      },
    },
  };

  @override
  Future<({String userResponse, String journalNarrative})> generateInteraction(
    Session session,
    InteractionRequest request,
  ) {
    final apiKey = session.passwords['mistralApiKey'];
    if (apiKey == null || apiKey.isEmpty) {
      // Should never happen — the factory only builds this when the key exists —
      // but guard so a misconfiguration fails loudly rather than with a 401.
      throw StateError('MistralLlmService invoked without a mistralApiKey');
    }
    return completeForKey(apiKey, request);
  }

  /// The Session-free HTTP core: posts [request] to Mistral with [apiKey] and
  /// returns the two parsed fields. Called by [generateInteraction] in
  /// production; split out so a smoke harness can also exercise the real
  /// round-trip with just a key (no Session).
  Future<({String userResponse, String journalNarrative})> completeForKey(
    String apiKey,
    InteractionRequest request,
  ) async {
    final response = await http.post(
      _endpoint,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': _maxTokens,
        'temperature': _temperature,
        'presence_penalty': _presencePenalty,
        'frequency_penalty': _frequencyPenalty,
        'messages': buildInteractionMessages(request),
        'response_format': _responseFormat,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Mistral chat-completions failed (HTTP ${response.statusCode}): '
        '${response.body}',
      );
    }

    // OpenAI-shaped envelope: choices[0].message.content is a JSON string that
    // (under json_schema mode) conforms to our two-field schema.
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final content =
        decoded['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception(
        'Mistral response missing choices[0].message.content: ${response.body}',
      );
    }

    final parsed = jsonDecode(content);
    final userResponse = parsed['userResponse'] as String?;
    final journalNarrative = parsed['journalNarrative'] as String?;
    if (userResponse == null || journalNarrative == null) {
      throw Exception('Mistral content missing required fields: $content');
    }

    return (userResponse: userResponse, journalNarrative: journalNarrative);
  }
}
