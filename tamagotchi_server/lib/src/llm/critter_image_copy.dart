/// Non-LLM copy for critter image generation: the deterministic placeholder the
/// [StubCritterImageService] returns in key-less environments (the `test` and
/// `e2e` run modes, and dev without a `geminiApiKey`).
///
/// It is a genuine, minimal, decodable baseline JPEG (a tiny solid square) —
/// never a generated critter. Real users always reach Gemini; this placeholder
/// only ever surfaces where the hermetic stub is selected, and it is never seen
/// by anyone whose opinion of it matters: it lets an integration-test hatch
/// succeed (asserted only on JPEG-magic bytes, never rendered) and gives the
/// patrol e2e app a valid image to load over `Image.network`. Kept deliberately
/// tiny because it lives base64-inline in committed source.
library;

/// A ~160-byte valid baseline JPEG (`FF D8 … FF D9`), base64-encoded — decoded by
/// the stub into raw bytes. Small on purpose: no user ever sees it, so visual
/// quality is irrelevant; it only has to be a well-formed JPEG that decodes.
const String placeholderCritterJpegBase64 =
    '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AfwD/2Q==';
