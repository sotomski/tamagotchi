import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import 'critter_image_prompt.dart';
import 'critter_image_service.dart';

/// The real [CritterImageService]: Google's Gemini image model over raw REST.
/// Mirrors the Mistral narrative precedent (`mistral_client.dart`) —
/// `http.post` + `session.passwords[...]` + `jsonDecode` — since server-side raw
/// REST is the right tool (the RPC-only rule governs frontend↔backend).
///
/// scloud allows outbound HTTPS/443 to `generativelanguage.googleapis.com` (only
/// SMTP egress is blocked). The key comes from `session.passwords['geminiApiKey']`;
/// this class is only constructed when that key is present (see
/// `critterImageServiceFor`).
class GeminiCritterImageService implements CritterImageService {
  const GeminiCritterImageService();

  /// `gemini-3.1-flash-lite-image` — cheap, low-latency, returns inline image
  /// bytes. Pinned. (Char-grid text models and heavier image models were probed
  /// and ruled out; see `change.md`.)
  static const String _model = 'gemini-3.1-flash-lite-image';

  static final Uri _endpoint = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/'
    '$_model:generateContent',
  );

  @override
  Future<Uint8List> generateImage(
    Session session,
    CritterImageRequest request,
  ) {
    final apiKey = session.passwords['geminiApiKey'];
    if (apiKey == null || apiKey.isEmpty) {
      // Should never happen — the factory only builds this when the key exists —
      // but guard so a misconfiguration fails loudly rather than with a 401.
      throw StateError(
        'GeminiCritterImageService invoked without a geminiApiKey',
      );
    }
    return completeForKey(apiKey, request);
  }

  /// The Session-free HTTP core: posts [request]'s prompt to Gemini with [apiKey]
  /// and returns the decoded JPEG bytes. Called by [generateImage] in production;
  /// split out so a smoke harness can exercise the real round-trip with just a
  /// key (no Session).
  ///
  /// The request pins a **square 1024×1024** output — `aspectRatio: '1:1'`,
  /// `imageSize: '1K'` (512 is unsupported; 1K is the model minimum, kept as-is,
  /// no downscale). Throws on any non-2xx or a response with no inline image —
  /// the block-hatch posture.
  Future<Uint8List> completeForKey(
    String apiKey,
    CritterImageRequest request,
  ) async {
    final response = await http.post(
      _endpoint,
      headers: {
        'x-goog-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': buildCritterImagePrompt(request)},
            ],
          },
        ],
        'generationConfig': {
          'responseModalities': ['IMAGE'],
          'imageConfig': {'aspectRatio': '1:1', 'imageSize': '1K'},
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Gemini image generation failed (HTTP ${response.statusCode}): '
        '${response.body}',
      );
    }

    // The image bytes come back base64 in
    // candidates[0].content.parts[*].inlineData.data. Scan the parts (a text
    // part can accompany the image) for the first one carrying inline data.
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final parts =
        decoded['candidates']?[0]?['content']?['parts'] as List<dynamic>?;
    if (parts == null) {
      throw Exception(
        'Gemini response missing candidates[0].content.parts: ${response.body}',
      );
    }
    for (final part in parts) {
      final inline = part is Map
          ? (part['inlineData'] ?? part['inline_data'])
          : null;
      final data = inline is Map ? inline['data'] as String? : null;
      if (data != null && data.isNotEmpty) {
        return base64Decode(data);
      }
    }
    throw Exception(
      'Gemini response contained no inline image data: ${response.body}',
    );
  }
}
