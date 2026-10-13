import 'package:flutter_test/flutter_test.dart';
import 'package:multi_window_sample/main_window/listener_slot.dart';

void main() {
  test('교체 순서(새 register → 옛 unregister)에서도 새 리스너가 남는다 (가드)', () {
    final slot = ListenerSlot<int>('test');
    final oldOwner = Object();
    final newOwner = Object();
    final received = <String>[];

    slot.register(oldOwner, (v) => received.add('old $v'));
    slot.register(newOwner, (v) => received.add('new $v')); // 새 위젯 initState
    slot.unregister(oldOwner); // 옛 위젯 dispose (늦게 실행)
    slot.notify(1);

    expect(received, ['new 1']);
  });

  test('자기 것이면 해제된다', () {
    final slot = ListenerSlot<int>('test');
    final owner = Object();
    var called = false;

    slot.register(owner, (_) => called = true);
    slot.unregister(owner);
    slot.notify(1);

    expect(called, isFalse);
  });
}
