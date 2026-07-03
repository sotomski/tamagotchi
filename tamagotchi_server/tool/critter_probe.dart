// THROWAWAY Phase-0 probe (context/changes/generate-creature-image/plan.md).
// Deleted or gitignored before merge — NOT shipped code.
//
// Purpose: de-risk the no-fallback image pipeline before any production wiring.
// Issues a handful of generations against the REAL Mistral API at the chosen
// 32×16 (mirrored → 32×32) char-grid size with the candidate prompt +
// `json_schema`, composites each result to ASCII, and prints it so a human can
// eyeball "varied" and "non-degenerate", and confirm the structured-output
// response parses cleanly at this size.
//
// Usage (from tamagotchi_server/, with a real key in config/passwords.yaml):
//   dart run tool/critter_probe.dart [count] [model] [temperature]
// e.g.
//   dart run tool/critter_probe.dart 3 mistral-large-latest 0.4
//
// The RNG is FIXED-seeded, so every invocation draws the SAME critters — run two
// models back-to-back and the only variable is the model (and/or temperature).
//
// Reads `development.mistralApiKey` straight from config/passwords.yaml — no
// Serverpod boot, no DB, no Session. Mirrors the request envelope of
// lib/src/llm/mistral_client.dart (the shape Phase 3 will duplicate).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

// ── Chosen canvas (the user override of the brief's 16×16; see plan Open Risks).
const int kSize = 32; // full creature is kSize × kSize
const int kHalf =
    kSize ~/ 2; // model emits the LEFT half: kSize rows × kHalf chars

final Uri _endpoint = Uri.parse('https://api.mistral.ai/v1/chat/completions');
const String _defaultModel = 'mistral-small-2603';
const double _defaultTemp = 0.7;

/// Fixed RNG seed so every invocation draws the SAME critters — comparing two
/// models becomes apples-to-apples (identical names, hints, variety seeds).
const int _rngSeed = 0x5EED;

// ── Candidate structured-output envelope (Phase 3 will duplicate this shape).
// `strict:false` because the palette is a dynamic char→hex map (arbitrary keys),
// which strict mode's fixed-property requirement can't express.
const Map<String, dynamic> _responseFormat = {
  'type': 'json_schema',
  'json_schema': {
    'name': 'critter_sprite',
    'strict': false,
    'schema': {
      'type': 'object',
      'properties': {
        'palette': {
          'type': 'object',
          'additionalProperties': {'type': 'string'},
        },
        'base': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      },
      'required': ['palette', 'base'],
      'additionalProperties': false,
    },
  },
};

/// When true, the model emits the FULL $kSize×$kSize grid directly (the chosen
/// production approach: accept model output as-is). When false, the original
/// left-half experiment.
bool _fullMode = true;
int get _wantWidth => _fullMode ? kSize : kHalf;

String _buildSystem() => _fullMode
    ? '''
You are a pixel-art generator for a retro virtual-pet game. You design tiny
$kSize×$kSize pixel creatures ("critters") in a chunky 8-bit / Game Boy aesthetic:
bold simple shapes, a clear FILLED body silhouette, a readable face (two eyes,
maybe a small mouth), short stubby limbs. Each critter looks best roughly
bilaterally SYMMETRIC about its vertical centre line.

Respond with a JSON object with exactly two fields:

- "palette": an object mapping each single visible character you use in the grid
  to a 6-digit hex colour like "#7FB069". Use 3 to 6 colours. The character "."
  is RESERVED for transparent/empty and must NOT appear in the palette.

- "base": an array of EXACTLY $kSize strings, each EXACTLY $kSize characters long —
  the FULL square critter. Use "." for transparent pixels and your palette
  characters for coloured pixels.

Hard rules:
- Exactly $kSize rows, each exactly $kSize characters. No more, no less. Pad any
  empty space with "." so every row is the full width.
- Draw ONE recognisable, mostly-filled body CENTRED in the canvas — NOT near-empty,
  NOT random noise, NOT touching all four edges. Leave a transparent margin.
- Make it roughly left-right symmetric so it reads as a single creature.
- Make the design clearly reflect the personality hints you are given, so two
  different personalities produce two visibly different critters.
'''
    : '''
You are a pixel-art generator for a retro virtual-pet game. You design tiny
$kSize×$kSize pixel creatures ("critters"). Draw ONLY the LEFT HALF; the game
mirrors it. "palette" maps single chars to #RRGGBB ("." = transparent, excluded).
"base" is EXACTLY $kSize strings of EXACTLY $kHalf chars (the left half).
''';

String _userPrompt(_Seed s) =>
    '''
Design a critter named "${s.name}".

Personality hints (let these visibly shape silhouette, colour, and face):
${s.hints.map((h) => '- $h').join('\n')}

Variety seed: ${s.seed} — make this critter distinct from any other.
Remember: $kSize rows of $_wantWidth characters${_fullMode ? ', the FULL square' : ', LEFT half only'}.
''';

/// One probe case: a name + derived visual hints + a variety seed.
class _Seed {
  _Seed(this.name, this.hints, this.seed);
  final String name;
  final List<String> hints;
  final int seed;
}

/// Tiny stand-in for Phase 3's personality→hints mapping: turns a few rolled
/// mods into descriptive words so we exercise variety the way production will.
List<String> _hintsFor(Random rng) {
  String pick(List<String> lo, List<String> hi) {
    final v = 0.5 + rng.nextDouble(); // [0.5, 1.5) like the real roll
    return (v < 1.0 ? lo : hi)[rng.nextInt(lo.length)];
  }

  return [
    'energy: ${pick(["sleepy and droopy", "calm, soft-edged"], ["lively and spiky", "alert, bristling"])}',
    'sociability: ${pick(["shy, cool blue/grey tones, angular", "reserved, small eyes"], ["warm, round, friendly orange/yellow tones", "big expressive eyes"])}',
    'hunger: ${pick(["lean, slender body", "narrow"], ["round, chunky body", "plump and stout"])}',
    'illness: ${pick(["pale, washed-out", "muted palette"], ["vivid, saturated palette", "bold high-contrast colours"])}',
  ];
}

Future<void> main(List<String> args) async {
  final count = args.isNotEmpty ? int.tryParse(args[0]) ?? 6 : 6;
  final model = args.length > 1 ? args[1] : _defaultModel;
  final temp = args.length > 2
      ? double.tryParse(args[2]) ?? _defaultTemp
      : _defaultTemp;
  // 4th arg 'half' reverts to the original left-half experiment; default is full.
  _fullMode = !(args.length > 3 && args[3] == 'half');
  final apiKey = _readDevKey();
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln(
      'No development.mistralApiKey in config/passwords.yaml — paste a dev key '
      'first (the probe needs the REAL API).',
    );
    exit(1);
  }

  stdout.writeln(
    '### model=$model  temp=$temp  count=$count  '
    'grid=${_fullMode ? "FULL ${kSize}x$kSize" : "left-half ${kSize}x$kHalf"}  '
    '(fixed RNG seed)',
  );

  final rng = Random(_rngSeed);
  final names = [
    'Mossy',
    'Pib',
    'Zub',
    'Quill',
    'Noot',
    'Drib',
    'Fenn',
    'Wisp',
    'Tato',
    'Glim',
    'Borp',
    'Snik',
  ];

  var ok = 0;
  final fillRatios = <double>[];
  for (var i = 0; i < count; i++) {
    final seed = _Seed(
      names[i % names.length],
      _hintsFor(rng),
      rng.nextInt(1 << 30),
    );
    stdout.writeln('\n${"=" * 64}');
    stdout.writeln('[$i] "${seed.name}"  seed=${seed.seed}');
    for (final h in seed.hints) {
      stdout.writeln('     · $h');
    }
    stdout.writeln('-' * 64);
    try {
      final body = await _generate(apiKey, model, temp, seed);
      final report = _renderAndReport(body);
      stdout.write(report.ascii);
      stdout.writeln(report.summary);
      if (report.wellFormed) ok++;
      fillRatios.add(report.fillRatio);
    } catch (e) {
      stdout.writeln('  !! generation/parse FAILED: $e');
    }
  }

  stdout.writeln('\n${"=" * 64}');
  stdout.writeln(
    'DONE: $ok/$count well-formed ($kSize rows × $kHalf chars, palette-clean).',
  );
  if (fillRatios.isNotEmpty) {
    final avg = fillRatios.reduce((a, b) => a + b) / fillRatios.length;
    stdout.writeln(
      'fill ratio: min=${_pct(fillRatios.reduce(min))} '
      'max=${_pct(fillRatios.reduce(max))} avg=${_pct(avg)} '
      '(degenerate if near 0% or ~100%).',
    );
  }
}

/// POSTs one generation and returns the parsed `{palette, base}` content.
Future<Map<String, dynamic>> _generate(
  String apiKey,
  String model,
  double temp,
  _Seed seed,
) async {
  final response = await http.post(
    _endpoint,
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'model': model,
      'max_tokens':
          4096, // a 32×16 grid + palette is far larger than the text calls
      'temperature': temp,
      'messages': [
        {'role': 'system', 'content': _buildSystem()},
        {'role': 'user', 'content': _userPrompt(seed)},
      ],
      'response_format': _responseFormat,
    }),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }
  final decoded = jsonDecode(utf8.decode(response.bodyBytes));
  final content = decoded['choices']?[0]?['message']?['content'] as String?;
  if (content == null || content.isEmpty) {
    throw Exception('missing choices[0].message.content: ${response.body}');
  }
  final parsed = jsonDecode(content);
  if (parsed is! Map<String, dynamic>) {
    throw Exception('content is not a JSON object: $content');
  }
  return parsed;
}

class _Report {
  _Report(this.ascii, this.summary, this.wellFormed, this.fillRatio);
  final String ascii;
  final String summary;
  final bool wellFormed;
  final double fillRatio;
}

/// Renders the model's grid EXACTLY as emitted — no truncation, no mirroring —
/// so the ASCII reflects what the model actually drew (each pixel doubled
/// horizontally for square aspect). Separately reports protocol conformance
/// (32 rows × 16 chars, palette-clean) in the summary so drawing quality and
/// left-half-mirror adherence are judged independently.
_Report _renderAndReport(Map<String, dynamic> body) {
  final paletteRaw = (body['palette'] as Map?) ?? const {};
  final palette = <String, String>{
    for (final e in paletteRaw.entries) '${e.key}': '${e.value}',
  };
  final base = ((body['base'] as List?) ?? const []).map((e) => '$e').toList();

  final issues = <String>[];
  if (base.length != kSize) issues.add('rows=${base.length}≠$kSize');
  // Report what widths the model actually used vs the expected width.
  final widths = base.map((r) => r.length).toSet();
  if (!(widths.length == 1 && widths.first == _wantWidth)) {
    issues.add('row widths=$widths (want $_wantWidth)');
  }
  final hexRe = RegExp(r'^#[0-9A-Fa-f]{6}$');
  final badHex = palette.values.where((v) => !hexRe.hasMatch(v)).length;
  if (badHex > 0) issues.add('$badHex bad hex');
  if (palette.containsKey('.')) issues.add('"." in palette');

  // Stable shade ramp per distinct palette char, so colour regions read in mono.
  const ramp = ['#', '@', 'O', '+', '=', ':', '%', '&'];
  final order = palette.keys.toList();
  String glyph(String ch) {
    if (ch == '.' || !palette.containsKey(ch)) return '  ';
    final idx = order.indexOf(ch);
    final g = idx >= 0 && idx < ramp.length ? ramp[idx] : '*';
    return '$g$g';
  }

  // RAW render: every row as the model emitted it, mapped char→glyph.
  var filled = 0;
  var cellCount = 0;
  final sb = StringBuffer();
  for (final row in base) {
    final cells = <String>[];
    for (final ch in row.split('')) {
      cellCount++;
      if (ch != '.' && palette.containsKey(ch)) filled++;
      cells.add(glyph(ch));
    }
    sb.writeln('  |${cells.join()}|');
  }

  final fillRatio = cellCount == 0 ? 0.0 : filled / cellCount;
  final legend = order
      .map(
        (k) =>
            '${ramp.length > order.indexOf(k) ? ramp[order.indexOf(k)] : "*"}=${palette[k]}',
      )
      .join(' ');
  final wellFormed = issues.isEmpty;
  final summary = StringBuffer()
    ..writeln('  raw grid: ${base.length} rows, widths=$widths')
    ..writeln('  palette(${palette.length}): $legend')
    ..writeln(
      '  fill=${_pct(fillRatio)}  ${wellFormed ? "protocol-clean ✓" : "PROTOCOL: ${issues.join(", ")}"}',
    );
  return _Report(sb.toString(), summary.toString(), wellFormed, fillRatio);
}

String _pct(double v) => '${(v * 100).toStringAsFixed(0)}%';

/// Reads `development.mistralApiKey` from config/passwords.yaml without a YAML
/// dep (throwaway probe — a line-scan is enough). Scans within the `development:`
/// block for the `mistralApiKey:` scalar and strips quotes.
String? _readDevKey() {
  final file = File('config/passwords.yaml');
  if (!file.existsSync()) return null;
  var inDev = false;
  for (final raw in file.readAsLinesSync()) {
    // A new top-level (column-0) key ends the development block.
    if (raw.isNotEmpty && raw[0] != ' ' && raw[0] != '#') {
      inDev = raw.trimRight() == 'development:';
      continue;
    }
    if (!inDev) continue;
    final m = RegExp(
      r'''^\s*mistralApiKey:\s*['"]?([^'"#\s]+)''',
    ).firstMatch(raw);
    if (m != null) return m.group(1);
  }
  return null;
}
