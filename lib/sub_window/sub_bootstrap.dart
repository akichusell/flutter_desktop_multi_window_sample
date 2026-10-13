import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../common/channels.dart';
import '../common/demo_flags.dart';
import '../common/gallery_images.dart';
import '../common/log.dart';
import '../common/ui.dart';
import 'sub_window_state.dart';

/// 서브 엔진 초기화. 상세·카테고리 창이 같은 순서로 시작한다.
Future<SubWindowState> setUpSubWindow(WindowController controller, WindowArgs args) async {
  final state = SubWindowState(args, await loadGalleryImages());

  // 1) 이 창의 WindowController 채널 핸들러. 앱 시작 시 한 번만 등록한다.
  await controller.setWindowMethodHandler((call) async {
    switch (call.method) {
      case Method.init:
        await state.onInit(WindowArgs.fromJson(Map<String, dynamic>.from(call.arguments as Map)));
        await windowManager.setTitle(_titleOf(state.args));
      case Method.reactionsChanged:
        state.onReactionsChanged(Map<String, dynamic>.from(call.arguments as Map));
      case Method.shutdown:
        _closeForShutdown();
      default:
        throw MissingPluginException('window_controller.${call.method}');
    }
  });
  log('channel', 'register window_controller/${controller.windowId} (unidirectional)');

  // 2) 이 엔진에 등록된 window_manager는 자기 창만 제어한다.
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(kReuseWindows);
  windowManager.addListener(_CloseToHide(controller.windowId));
  await windowManager.setTitle(_titleOf(args));
  final isDetail = args is DetailArgs;
  await windowManager.setSize(isDetail ? kDetailWindowSize : kCategoryWindowSize);
  await windowManager.setMinimumSize(isDetail ? kDetailWindowMinSize : kCategoryWindowMinSize);
  await windowManager.center();

  await state.fetchAll();
  return state;
}

/// `hiddenAtLaunch: true`로 만들어진 창을 첫 프레임이 그려진 뒤 스스로 보여 준다.
Future<void> showAfterFirstFrame() async {
  await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
  await windowManager.show();
  log('lifecycle', 'first frame -> show');
}

String _titleOf(WindowArgs args) => switch (args) {
  DetailArgs(:final imageId) => fileNameOf(imageId),
  CategoryArgs(:final reaction) => '${reaction.emoji} ${reaction.label}',
};

bool _shuttingDown = false;

/// 메인 종료 요청: 응답을 먼저 돌려준 뒤 창을 실제로 닫는다 (→ 이 엔진도 정리된다).
void _closeForShutdown() {
  log('receive', 'shutdown -> close window');
  _shuttingDown = true;
  Timer.run(() async {
    await windowManager.setPreventClose(false);
    await windowManager.close();
  });
}

/// X를 눌러도 닫지 않고 숨긴다.
/// 네이티브(X) → Dart(onWindowClose) → 네이티브(hide) 왕복이라 창이 사라지기까지 지연이 있다.
class _CloseToHide with WindowListener {
  _CloseToHide(this._windowId);

  final String _windowId;

  @override
  Future<void> onWindowClose() async {
    if (!kReuseWindows || _shuttingDown) {
      log('lifecycle', 'X -> close (this engine will be destroyed)');
      return;
    }
    final stopwatch = Stopwatch()..start();
    await windowManager.hide();
    log('lifecycle', 'X -> hide (${stopwatch.elapsedMilliseconds}ms in Dart)');
    await windowRouterChannel.invokeMethod(Method.windowHidden, _windowId);
  }
}
