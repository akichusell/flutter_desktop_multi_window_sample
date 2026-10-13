import 'package:flutter/foundation.dart';

import '../common/demo_flags.dart';
import '../common/log.dart';

/// 리스너를 딱 1개만 담는 슬롯 ("현재 활성 리스너").
///
/// 위젯이 교체되면 새 위젯 `initState`(register)가 옛 위젯 `dispose`(unregister)보다 먼저 실행된다.
/// 그래서 unregister가 무조건 슬롯을 비우면, 방금 등록된 새 리스너가 지워진다.
/// → "내 것일 때만 해제"하는 가드가 필요하다.
class ListenerSlot<T> {
  ListenerSlot(this.name);

  final String name;
  Object? _owner;
  ValueChanged<T>? _listener;

  void register(Object owner, ValueChanged<T> listener) {
    log('slot', 'register $name <- $owner (was ${_owner ?? 'empty'})');
    _owner = owner;
    _listener = listener;
  }

  void unregister(Object owner) {
    if (kSlotGuard && !identical(_owner, owner)) {
      log('slot', 'unregister $name by $owner BLOCKED by guard (owner is $_owner)');
      return;
    }
    log('slot', 'unregister $name by $owner${identical(_owner, owner) ? '' : ' (warning! erased $_owner)'}');
    _owner = null;
    _listener = null;
  }

  void notify(T value) {
    final listener = _listener;
    if (listener == null) {
      log('slot', 'notify $name -> EMPTY (listener was erased)');
      return;
    }
    log('slot', 'notify $name -> $_owner');
    listener(value);
  }
}
