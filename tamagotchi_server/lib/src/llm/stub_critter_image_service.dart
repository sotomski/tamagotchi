import 'dart:convert';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import 'critter_image_copy.dart';
import 'critter_image_prompt.dart';
import 'critter_image_service.dart';

/// A no-network [CritterImageService] for key-less environments (the `test` and
/// `e2e` run modes, CI, dev without a `geminiApiKey`) and the default in
/// integration tests. Returns the deterministic placeholder JPEG
/// ([placeholderCritterJpegBase64]) so a hatch succeeds hermetically. Never
/// throws — the image analogue of [StubLlmService].
class StubCritterImageService implements CritterImageService {
  const StubCritterImageService();

  @override
  Future<Uint8List> generateImage(
    Session session,
    CritterImageRequest request,
  ) async {
    return base64Decode(placeholderCritterJpegBase64);
  }
}
