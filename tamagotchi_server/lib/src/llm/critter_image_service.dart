import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import 'critter_image_prompt.dart';
import 'gemini_critter_image_service.dart';
import 'stub_critter_image_service.dart';

/// The seam the hatch flow depends on for the creature's birth graphic, so the
/// deterministic layer is testable against a stub without a live model — the
/// image analogue of [LlmService] (`llm_service.dart`). Implemented by
/// [GeminiCritterImageService] (real) and [StubCritterImageService] (no network).
///
/// A pure bytes-producer: it returns the raw JPEG and nothing else. Storing the
/// bytes in `public` cloud storage and persisting the resulting URL is the
/// endpoint's job (Phase 3), keeping this service free of [Session]-side effects
/// beyond the outbound HTTP call.
abstract interface class CritterImageService {
  /// Generates the creature's birth graphic and returns the raw JPEG bytes.
  /// Throws on any failure (non-2xx, missing image) — the hatch blocks on a
  /// failed generation rather than degrading, mirroring the narrative call.
  Future<Uint8List> generateImage(Session session, CritterImageRequest request);
}

/// Picks the real client vs the stub by key presence — NOT by run mode, matching
/// [llmServiceFor]. A non-empty `geminiApiKey` password means dev (local key) and
/// prod (scloud-injected) both hit the real API, while the `test`/`e2e` run modes
/// (no `passwords.yaml` entry) stay hermetic on the stub.
CritterImageService critterImageServiceFor(Session session) =>
    critterImageServiceForKey(session.passwords['geminiApiKey']);

/// The pure key→service decision behind [critterImageServiceFor], split out so it
/// is unit-testable without constructing a [Session]: a non-empty key selects the
/// real [GeminiCritterImageService], a null/empty key the [StubCritterImageService].
CritterImageService critterImageServiceForKey(String? geminiApiKey) {
  if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
    return const GeminiCritterImageService();
  }
  return const StubCritterImageService();
}
