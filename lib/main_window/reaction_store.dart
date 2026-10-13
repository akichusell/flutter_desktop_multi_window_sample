import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../common/channels.dart';
import '../common/gallery_images.dart';
import '../common/log.dart';
import '../common/reaction.dart';
import 'listener_slot.dart';

/// 리액션의 유일한 소유자(SSOT). 메인 엔진의 Dart 힙에만 있다.
/// 서브 창은 이 객체에 직접 닿을 수 없고, `reaction_store` 채널로만 요청한다.
class ReactionStore extends ChangeNotifier {
  final _byImage = <String, Set<Reaction>>{};

  /// 마지막으로 반응한 이미지 (메인 그리드에서 강조).
  String? get lastReactedImageId => _lastReactedImageId;
  String? _lastReactedImageId;

  /// 강조 위젯이 등록하는 1개짜리 리스너 슬롯. Slide 9.
  final lastReactedSlot = ListenerSlot<Reaction>('lastReacted');

  List<Reaction> reactionsOf(String imageId) {
    final set = _byImage[imageId] ?? const <Reaction>{};
    return Reaction.values.where(set.contains).toList();
  }

  int countOf(Reaction reaction) => _byImage.values.where((set) => set.contains(reaction)).length;

  /// 채널로 내보낼 사본. 원본 Set은 밖으로 내보내지 않는다.
  ReactionSnapshot get snapshot => ReactionSnapshot({
    for (final e in _byImage.entries) e.key: {...e.value},
  });

  /// 서브 엔진들이 호출하는 핸들러. 앱 시작 시 한 번만 등록한다. Slide 4.
  Future<void> serve() async {
    await reactionStoreChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case Method.getAll:
          log('receive', 'getAll');
          return snapshot.toJson();
        case Method.toggle:
          _toggle(ToggleRequest.fromJson(Map<String, dynamic>.from(call.arguments as Map)));
          return null;
      }
      throw MissingPluginException('reaction_store.${call.method}');
    });
    log('channel', 'register reaction_store (unidirectional)');
  }

  /// 같은 리액션을 다시 고르면 해제된다.
  void _toggle(ToggleRequest request) {
    final ToggleRequest(:imageId, :reaction) = request;
    final set = _byImage.putIfAbsent(imageId, () => {});
    if (!set.remove(reaction)) set.add(reaction);
    _lastReactedImageId = imageId;
    log(
      'receive',
      'toggle ${fileNameOf(imageId)} ${reaction.name} -> [${reactionsOf(imageId).map((r) => r.name).join(', ')}]',
    );

    notifyListeners(); // → 메인 그리드 리빌드 + 서브 창 push (main_app.dart에서 연결)

    // 위젯 교체(새 initState → 옛 dispose)가 끝난 프레임 뒤에 슬롯을 부른다.
    SchedulerBinding.instance.addPostFrameCallback((_) => lastReactedSlot.notify(reaction));
  }
}
