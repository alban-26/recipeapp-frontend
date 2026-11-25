import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipeapp_frontend/offline/LocalStore.dart';
import 'package:recipeapp_frontend/offline/SyncQueue.dart';

void main() {
  late MemoryLocalStore store;
  late SyncQueue queue;
  late List<String> done;

  setUp(() async {
    store = MemoryLocalStore();
    queue = SyncQueue(store: store);
    await queue.load();
    done = [];
  });

  test('verarbeitet strikt in der Reihenfolge des Eintragens', () async {
    queue.register('op', (op) async {
      // Der erste Eintrag braucht am längsten - überholt werden darf er nicht.
      await Future<void>.delayed(
          Duration(milliseconds: op.data['n'] == 1 ? 30 : 1));
      done.add('op${op.data['n']}');
    });

    queue.enqueue('op', {'n': 1});
    queue.enqueue('op', {'n': 2});
    queue.enqueue('op', {'n': 3});

    expect(await queue.flush(), isTrue);
    expect(done, ['op1', 'op2', 'op3']);
    expect(queue.pendingCount, 0);
  });

  test('was während der Übertragung dazukommt, geht im selben Lauf mit raus',
      () async {
    queue.register('op', (op) async {
      done.add('op${op.data['n']}');
      if (op.data['n'] == 1) queue.enqueue('op', {'n': 2});
    });

    queue.enqueue('op', {'n': 1});
    expect(await queue.flush(), isTrue);
    expect(done, ['op1', 'op2']);
  });

  test('ohne Netz bleibt alles liegen und stoppt beim ersten Eintrag', () async {
    var online = false;
    queue.register('op', (op) async {
      if (!online) throw const SocketException('offline');
      done.add('op${op.data['n']}');
    });

    queue.enqueue('op', {'n': 1});
    queue.enqueue('op', {'n': 2});
    expect(await queue.flush(), isFalse);
    expect(await queue.flush(), isFalse);
    expect(queue.pendingCount, 2);
    expect(done, isEmpty);

    online = true;
    expect(await queue.flush(), isTrue);
    expect(done, ['op1', 'op2']);
  });

  test('übersteht einen Neustart: Einträge, Zuordnungen und ID-Zähler',
      () async {
    queue.register('op', (op) async => throw const SocketException('offline'));
    final first = queue.newTempId();
    final second = queue.newTempId();
    queue.mapId('list', first, 4711);
    queue.enqueue('op', {'listId': second});
    await queue.flush();

    final restarted = SyncQueue(store: store);
    await restarted.load();

    expect(restarted.pendingCount, 1);
    expect(restarted.resolve('list', first), 4711);
    expect(restarted.resolve('list', second), second,
        reason: 'noch unbekannt -> bleibt vorläufig');
    expect(restarted.newTempId(), lessThan(second),
        reason: 'keine vorläufige ID wird zweimal vergeben');
  });

  test('vorläufige IDs sind negativ, echte bleiben unangetastet', () {
    final temp = queue.newTempId();
    expect(SyncQueue.isTempId(temp), isTrue);
    expect(queue.resolve('list', 42), 42);
    queue.mapId('list', temp, 42);
    expect(queue.resolve('list', temp), 42);
    expect(queue.resolve('item', temp), temp, reason: 'andere Art, andere Zuordnung');
  });

  test('ein fehlender Handler wirft nichts weg', () async {
    queue.enqueue('unbekannt', {});
    expect(await queue.flush(), isFalse);
    expect(queue.pendingCount, 1);
  });

  test('ein Programmfehler im Handler blockiert die Schlange nicht', () async {
    final failures = <SyncFailure>[];
    queue.failures.listen(failures.add);
    queue.register('kaputt', (op) async => throw StateError('nicht auflösbar'));
    queue.register('ok', (op) async => done.add('ok'));

    queue.enqueue('kaputt', {});
    queue.enqueue('ok', {});
    expect(await queue.flush(), isTrue);
    await pumpEventQueue();

    expect(done, ['ok']);
    expect(failures.single.op.type, 'kaputt');
  });

  test('nach dem Zurücksetzen werden alte vorläufige IDs nie wiederverwendet',
      () async {
    final before = queue.newTempId();
    queue.mapId('list', before, 1);
    queue.enqueue('op', {});

    queue.reset();

    expect(queue.pendingCount, 0);
    expect(queue.resolve('list', before), before);
    expect(queue.newTempId(), lessThan(before));
  });

  test('parallele flush()-Aufrufe starten nur einen Lauf', () async {
    var running = 0;
    var maxRunning = 0;
    queue.register('op', (op) async {
      running++;
      if (running > maxRunning) maxRunning = running;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      running--;
    });
    queue.enqueue('op', {});
    queue.enqueue('op', {});

    await Future.wait([queue.flush(), queue.flush(), queue.flush()]);
    expect(maxRunning, 1);
    expect(queue.pendingCount, 0);
  });
}
