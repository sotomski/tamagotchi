import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';
import 'package:tamagotchi_flutter/app/client_provider.dart';
import 'package:tamagotchi_flutter/creature/creature_provider.dart';
import 'package:tamagotchi_flutter/creature/cure_controller.dart';
import 'package:tamagotchi_flutter/creature/feed_controller.dart';
import 'package:tamagotchi_flutter/creature/play_controller.dart';
import 'package:tamagotchi_flutter/creature/time_scale_provider.dart';

/// A [Client] whose every RPC is intercepted at [callServerEndpoint]: it records
/// the endpoint/method/args (so a test can assert the `timeScale` the real
/// provider/controllers passed) and returns canned results without a server.
/// This overrides the generated `Client` at its single egress point rather than
/// faking each endpoint, so the real provider/controller code under test runs
/// unmodified (lesson: don't fake the Client per-method).
class _RecordingClient extends Client {
  _RecordingClient() : super('http://localhost/');

  final List<({String endpoint, String method, Map<String, dynamic> args})>
  calls = [];

  @override
  Future<T> callServerEndpoint<T>(
    String endpoint,
    String method,
    Map<String, dynamic> args, {
    bool authenticated = true,
  }) async {
    calls.add((endpoint: endpoint, method: method, args: args));
    final dynamic result = switch (method) {
      'myCreature' => _status(),
      'feed' => FeedResult(
        userResponse: 'ok',
        accepted: true,
        exhausted: false,
        status: _status(),
      ),
      'play' => PlayResult(
        userResponse: 'ok',
        exhausted: false,
        status: _status(),
      ),
      'cure' => CureResult(userResponse: 'ok', status: _status()),
      _ => throw UnimplementedError(method),
    };
    return result as T;
  }
}

CreatureStatus _status() => CreatureStatus(
  creature: Creature(
    ownerUuid: UuidValue.fromString('00000000-0000-0000-0000-000000000001'),
    name: 'Testy',
    hunger: 0,
    energy: 50,
    love: 50,
    illness: 0,
  ),
  mood: CreatureMood.happy,
  canFeed: true,
  canPlay: true,
);

/// The `timeScale` argument the [method] call carried (the first such call).
double _timeScaleOf(_RecordingClient client, String method) =>
    client.calls.firstWhere((call) => call.method == method).args['timeScale']
        as double;

void main() {
  ProviderContainer makeContainer(_RecordingClient client) {
    final container = ProviderContainer(
      overrides: [serverpodClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('creatureProvider passes the current timeScale to myCreature', () async {
    final client = _RecordingClient();
    final container = makeContainer(client);

    // The default slider value flows through on the first read.
    await container.read(creatureProvider.future);
    expect(_timeScaleOf(client, 'myCreature'), minTimeScale);

    // Moving the slider re-fetches with the new value (the provider watches it).
    container.read(timeScaleProvider.notifier).set(5);
    await container.read(creatureProvider.future);
    expect(client.calls.last.method, 'myCreature');
    expect(client.calls.last.args['timeScale'], 5.0);
  });

  test('the feed controller passes the current timeScale', () async {
    final client = _RecordingClient();
    final container = makeContainer(client);
    container.read(timeScaleProvider.notifier).set(4);

    await container.read(feedControllerProvider.notifier).feed();

    expect(_timeScaleOf(client, 'feed'), 4.0);
  });

  test('the play controller passes the current timeScale', () async {
    final client = _RecordingClient();
    final container = makeContainer(client);
    container.read(timeScaleProvider.notifier).set(3);

    await container.read(playControllerProvider.notifier).play();

    expect(_timeScaleOf(client, 'play'), 3.0);
  });

  test('the cure controller passes the current timeScale', () async {
    final client = _RecordingClient();
    final container = makeContainer(client);
    container.read(timeScaleProvider.notifier).set(6);

    await container.read(cureControllerProvider.notifier).cure();

    expect(_timeScaleOf(client, 'cure'), 6.0);
  });
}
