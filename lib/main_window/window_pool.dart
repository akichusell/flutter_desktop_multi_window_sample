import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../common/channels.dart';
import '../common/demo_flags.dart';
import '../common/gallery_images.dart';
import '../common/log.dart';
import '../common/reaction.dart';
import 'reaction_store.dart';

/// 풀에 든 서브 창 1개. 창 1개 = 엔진 1개.
class _SubWindow {
  _SubWindow(this.args, this.ready);

  WindowArgs args; // 카테고리 창은 init으로 바뀐다
  final Future<WindowController> ready; // 생성 중에도 먼저 풀에 넣어 중복 생성을 막는다
  bool hidden = false;
}

/// 서브 창 풀. 창 풀의 소유자는 메인이다.
/// - 상세 창: 이미지마다 1개. X는 hide, 같은 이미지를 다시 열면 숨겨 둔 창을 show.
/// - 카테고리 창: 1개를 재사용. 다른 리액션을 열면 init으로 내용만 바꾼다.
class WindowPool {
  WindowPool(this._store);

  final ReactionStore _store;
  final _details = <String, _SubWindow>{}; // imageId → 창
  _SubWindow? _category;

  List<_SubWindow> get _all => [..._details.values, ?_category];

  /// 카테고리 창이 상세 창을 열 때 쓰는 채널. 앱 시작 시 한 번만 등록한다.
  Future<void> serve() async {
    await windowRouterChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case Method.openDetail:
          log('receive', 'openDetail ${fileNameOf(call.arguments as String)}');
          return openDetail(call.arguments as String);
        case Method.windowHidden:
          return _markHidden(call.arguments as String);
      }
      throw MissingPluginException('window_router.${call.method}');
    });
    log('channel', 'register window_router (unidirectional)');

    // 재사용을 끈 경우 X에서 창이 실제로 닫힌다. 네이티브 창 목록이 바뀌면 풀에서 뺀다.
    onWindowsChanged.listen((_) => _forgetClosedWindows());
  }

  Future<void> openDetail(String imageId) async {
    final existing = _details[imageId];
    if (existing != null) return _reshow(existing);
    _details[imageId] = _create(DetailArgs(imageId));
  }

  Future<void> openCategory(Reaction reaction) async {
    final existing = _category;
    if (existing == null) {
      _category = _create(CategoryArgs(reaction));
      return;
    }
    existing.args = CategoryArgs(reaction);
    log('push', 'init -> ${existing.args.tag}');
    await (await existing.ready).invokeMethod(Method.init, existing.args.toJson());
    await _reshow(existing);
  }

  /// 새 엔진을 띄운다. 창은 숨긴 채로 만들고, 서브가 첫 프레임 후 스스로 show한다.
  /// 메인 창 중심을 arguments에 넣어 서브가 메인과 같은 모니터 가운데에 자리 잡게 한다.
  _SubWindow _create(WindowArgs args) {
    final stopwatch = Stopwatch()..start();
    final ready = _mainAnchor().then(
      (anchor) =>
          WindowController.create(WindowConfiguration(arguments: args.encode(anchor: anchor), hiddenAtLaunch: true)),
    );
    ready.then(
      (c) => log('lifecycle', 'create ${args.tag} (window ${c.windowId}, ${stopwatch.elapsedMilliseconds}ms)'),
    );
    return _SubWindow(args, ready);
  }

  /// 숨겨 둔 창 재사용: 엔진을 새로 띄우지 않고 show만 한다.
  /// 그사이 메인이 다른 모니터로 옮겨 갔으면 서브도 메인 모니터로 데려온다.
  Future<void> _reshow(_SubWindow window) async {
    final controller = await window.ready;
    if (window.hidden && !kPushToHiddenWindows) await _push([window]); // 숨어 있는 동안 못 받은 변경
    await _invoke(window, Method.moveToScreen, (await _mainAnchor()).toJson());
    window.hidden = false;
    await controller.show();
    log('lifecycle', 'reuse show ${window.args.tag} (window ${controller.windowId})');
  }

  // ── 메인 → 서브 push ─────────────────────────────────────────────────

  /// 열려 있는 서브 창 전체(숨겨 둔 창 포함)에 보낸다.
  Future<void> pushToAll() => _push(_all);

  /// 보이는 창에만 보낸다. 숨겨 둔 창은 다시 보여 줄 때(_reshow) 최신값을 받는다.
  Future<void> pushToVisible() => _push(_all.where((w) => !w.hidden));

  Future<void> _push(Iterable<_SubWindow> targets) async {
    final windows = targets.toList();
    if (windows.isEmpty) return;
    final payload = _store.snapshot.toJson(); // toJson() → Map만 엔진 경계를 넘는다
    log('push', 'reactionsChanged -> ${windows.map((w) => w.args.tag).join(', ')}');
    await Future.wait(windows.map((w) => _invoke(w, Method.reactionsChanged, payload)));
  }

  // ── 종료 ─────────────────────────────────────────────────────────────

  /// 메인이 닫히기 전에 서브 엔진들을 먼저 정리한다. 응답이 없으면 1초 뒤 넘어간다.
  Future<void> shutdownAll() async {
    final windows = _all;
    log('lifecycle', 'shutdown ${windows.length} sub windows -> ${windows.map((w) => w.args.tag).join(', ')}');
    await Future.wait(
      windows.map((w) => _invoke(w, Method.shutdown).timeout(const Duration(seconds: 1), onTimeout: () {})),
    );
  }

  // ── 내부 ─────────────────────────────────────────────────────────────

  /// 이 엔진의 windowManager는 메인 창을 가리킨다.
  Future<ScreenAnchor> _mainAnchor() async => ScreenAnchor((await windowManager.getBounds()).center);

  Future<void> _invoke(_SubWindow window, String method, [Object? arguments]) async {
    try {
      await (await window.ready).invokeMethod(method, arguments);
    } on Exception catch (e) {
      log('push', '$method -> ${window.args.tag} failed: $e');
    }
  }

  Future<void> _markHidden(String windowId) async {
    for (final window in _all) {
      if ((await window.ready).windowId != windowId) continue;
      window.hidden = true;
      log('receive', 'windowHidden ${window.args.tag}');
    }
  }

  Future<void> _forgetClosedWindows() async {
    final alive = {for (final c in await WindowController.getAll()) c.windowId};
    for (final window in _all) {
      final controller = await window.ready;
      if (alive.contains(controller.windowId)) continue;
      log('lifecycle', 'closed ${window.args.tag} (window ${controller.windowId}) -> removed from pool');
      _details.removeWhere((_, w) => identical(w, window));
      if (identical(_category, window)) _category = null;
    }
  }
}
