import 'package:flutter_test/flutter_test.dart';

import 'package:connect_dating_app/data/models/call_models.dart';
import 'package:connect_dating_app/data/repositories/call_repository.dart';

void main() {
  group('MockCallRepository', () {
    test('no call on a fresh conversation', () {
      final calls = MockCallRepository();
      expect(calls.currentCall('a_b'), isNull);
    });

    test('startCall creates a ringing call', () async {
      final calls = MockCallRepository();
      final call = await calls.startCall('a_b', callerId: 'a', calleeId: 'b', type: CallType.video);
      expect(call.status, CallStatus.ringing);
      expect(call.type, CallType.video);
      expect(calls.currentCall('a_b')!.status, CallStatus.ringing);
    });

    test('accept moves a ringing call to accepted', () async {
      final calls = MockCallRepository();
      await calls.startCall('a_b', callerId: 'a', calleeId: 'b', type: CallType.audio);
      await calls.accept('a_b');
      expect(calls.currentCall('a_b')!.status, CallStatus.accepted);
    });

    test('decline moves a ringing call to declined', () async {
      final calls = MockCallRepository();
      await calls.startCall('a_b', callerId: 'a', calleeId: 'b', type: CallType.audio);
      await calls.decline('a_b');
      expect(calls.currentCall('a_b')!.status, CallStatus.declined);
    });

    test('end moves an accepted call to ended', () async {
      final calls = MockCallRepository();
      await calls.startCall('a_b', callerId: 'a', calleeId: 'b', type: CallType.audio);
      await calls.accept('a_b');
      await calls.end('a_b');
      expect(calls.currentCall('a_b')!.status, CallStatus.ended);
    });

    test('isCaller is true only for the caller', () async {
      final calls = MockCallRepository();
      final call = await calls.startCall('a_b', callerId: 'a', calleeId: 'b', type: CallType.audio);
      expect(call.isCaller('a'), isTrue);
      expect(call.isCaller('b'), isFalse);
    });

    test('a second call on the same conversation replaces the first', () async {
      final calls = MockCallRepository();
      await calls.startCall('a_b', callerId: 'a', calleeId: 'b', type: CallType.audio);
      await calls.end('a_b');
      final second = await calls.startCall('a_b', callerId: 'b', calleeId: 'a', type: CallType.video);
      expect(calls.currentCall('a_b'), same(second));
      expect(calls.currentCall('a_b')!.status, CallStatus.ringing);
    });

    test('accept/decline/end on a nonexistent call is a harmless no-op', () async {
      final calls = MockCallRepository();
      await calls.accept('nobody');
      await calls.decline('nobody');
      await calls.end('nobody');
      expect(calls.currentCall('nobody'), isNull);
    });

    test('changes() fires on start/accept/decline/end', () async {
      final calls = MockCallRepository();
      final events = <void>[];
      final sub = calls.changes().listen(events.add);
      await calls.startCall('a_b', callerId: 'a', calleeId: 'b', type: CallType.audio);
      await calls.accept('a_b');
      await calls.end('a_b');
      await Future<void>.delayed(Duration.zero);
      expect(events.length, greaterThanOrEqualTo(3));
      await sub.cancel();
    });
  });
}
