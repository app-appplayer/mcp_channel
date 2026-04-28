import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryIdempotencyStore store;

  setUp(() {
    store = InMemoryIdempotencyStore();
  });

  group('InMemoryIdempotencyStore', () {
    group('get', () {
      test('returns null for unknown event', () async {
        expect(await store.get('unknown'), isNull);
      });

      test('returns record after acquire', () async {
        await store.tryAcquire(
          'evt_1',
          lockHolder: 'inst_1',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );
        final record = await store.get('evt_1');
        expect(record, isNotNull);
        expect(record!.eventId, 'evt_1');
        expect(record.status, IdempotencyStatus.processing);
        expect(record.lockHolder, 'inst_1');
      });

      test('returns null for expired record', () async {
        await store.tryAcquire(
          'evt_1',
          lockHolder: 'inst_1',
          lockTimeout: Duration.zero,
          recordTtl: Duration.zero,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(await store.get('evt_1'), isNull);
      });
    });

    group('tryAcquire', () {
      test('acquires lock for new event', () async {
        final acquired = await store.tryAcquire(
          'evt_1',
          lockHolder: 'inst_1',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );
        expect(acquired, true);
        expect(store.count, 1);
      });

      test('fails when lock is held with valid lock', () async {
        await store.tryAcquire(
          'evt_1',
          lockHolder: 'inst_1',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );

        final acquired = await store.tryAcquire(
          'evt_1',
          lockHolder: 'inst_2',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );
        expect(acquired, false);
      });

      test('succeeds when lock has expired', () async {
        await store.tryAcquire(
          'evt_1',
          lockHolder: 'inst_1',
          lockTimeout: Duration.zero,
          recordTtl: const Duration(hours: 24),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final acquired = await store.tryAcquire(
          'evt_1',
          lockHolder: 'inst_2',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );
        expect(acquired, true);
      });
    });

    group('complete', () {
      test('marks record as completed', () async {
        await store.tryAcquire(
          'evt_1',
          lockHolder: 'inst_1',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );

        await store.complete('evt_1', IdempotencyResult.success());

        final record = await store.get('evt_1');
        expect(record!.status, IdempotencyStatus.completed);
        expect(record.result, isNotNull);
        expect(record.result!.success, true);
        expect(record.completedAt, isNotNull);
      });

      test('does nothing for unknown event', () async {
        await store.complete('unknown', IdempotencyResult.success());
        expect(store.count, 0);
      });
    });

    group('fail', () {
      test('marks record as failed', () async {
        await store.tryAcquire(
          'evt_1',
          lockHolder: 'inst_1',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );

        await store.fail('evt_1', 'something went wrong');

        final record = await store.get('evt_1');
        expect(record!.status, IdempotencyStatus.failed);
        expect(record.result!.success, false);
        expect(record.result!.error, contains('something went wrong'));
      });

      test('does nothing for unknown event', () async {
        await store.fail('unknown', 'error');
        expect(store.count, 0);
      });
    });

    group('release', () {
      test('removes record', () async {
        await store.tryAcquire(
          'evt_1',
          lockHolder: 'inst_1',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );
        expect(store.count, 1);

        await store.release('evt_1');
        expect(store.count, 0);
      });

      test('does nothing for unknown event', () async {
        await store.release('unknown');
        expect(store.count, 0);
      });
    });

    group('cleanup', () {
      test('removes expired records', () async {
        await store.tryAcquire(
          'evt_1',
          lockHolder: 'inst_1',
          lockTimeout: Duration.zero,
          recordTtl: Duration.zero,
        );
        await store.tryAcquire(
          'evt_2',
          lockHolder: 'inst_1',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final removed = await store.cleanup();
        expect(removed, 1);
        expect(store.count, 1);
      });

      test('returns 0 when nothing expired', () async {
        await store.tryAcquire(
          'evt_1',
          lockHolder: 'inst_1',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );
        final removed = await store.cleanup();
        expect(removed, 0);
      });
    });

    group('clear and count', () {
      test('clear removes all records', () async {
        await store.tryAcquire(
          'evt_1',
          lockHolder: 'inst_1',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );
        await store.tryAcquire(
          'evt_2',
          lockHolder: 'inst_1',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );
        expect(store.count, 2);

        store.clear();
        expect(store.count, 0);
      });
    });
  });
}
