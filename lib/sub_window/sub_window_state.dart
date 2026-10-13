import 'package:flutter/foundation.dart';

import '../common/channels.dart';
import '../common/gallery_images.dart';
import '../common/log.dart';
import '../common/reaction.dart';

/// 서브 창의 화면 상태.
/// 리액션은 메인이 보내 준 사본(snapshot)일 뿐 원본이 아니다. 바꾸고 싶으면 메인에 요청한다.
class SubWindowState extends ChangeNotifier {
  SubWindowState(this._args, this._images);

  WindowArgs _args;
  final List<String> _images;
  ReactionSnapshot _reactions = ReactionSnapshot.empty;

  WindowArgs get args => _args;
  ReactionSnapshot get reactions => _reactions;

  /// 카테고리 창: 현재 리액션이 붙은 이미지 (갤러리 순서).
  List<String> imagesWith(Reaction reaction) => _images.where((id) => _reactions.has(id, reaction)).toList();

  // ── 서브 → 메인 요청 ─────────────────────────────────────────────────

  Future<void> fetchAll() async {
    log('request', 'getAll');
    final raw = await reactionStoreChannel.invokeMethod<Map<Object?, Object?>>(Method.getAll);
    _reactions = ReactionSnapshot.fromJson(Map<String, dynamic>.from(raw ?? const {}));
    notifyListeners();
  }

  /// 로컬 사본은 고치지 않는다. 메인이 바꾼 뒤 reactionsChanged로 돌려줄 때 갱신된다.
  Future<void> toggle(String imageId, Reaction reaction) async {
    log('request', 'toggle ${reaction.name}');
    await reactionStoreChannel.invokeMethod(Method.toggle, ToggleRequest(imageId, reaction).toJson());
  }

  /// 창 생성은 창 풀의 소유자인 메인에게 맡긴다.
  Future<void> openDetail(String imageId) async {
    log('request', 'openDetail ${fileNameOf(imageId)}');
    await windowRouterChannel.invokeMethod(Method.openDetail, imageId);
  }

  // ── 메인 → 서브 push ─────────────────────────────────────────────────

  void onReactionsChanged(Map<String, dynamic> json) {
    _reactions = ReactionSnapshot.fromJson(json);
    final detail = switch (_args) {
      CategoryArgs(:final reaction) => ' (${imagesWith(reaction).length} images)',
      DetailArgs(:final imageId) => ' [${_reactions.of(imageId).map((r) => r.name).join(', ')}]',
    };
    log('receive', 'reactionsChanged$detail');
    notifyListeners();
  }

  /// 재사용되는 카테고리 창의 내용 교체.
  Future<void> onInit(WindowArgs args) async {
    _args = args;
    setWindowTag(args.tag);
    log('receive', 'init ${args.tag}');
    await fetchAll();
  }
}
