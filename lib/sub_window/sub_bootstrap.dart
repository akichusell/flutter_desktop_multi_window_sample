import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../common/channels.dart';
import '../common/demo_flags.dart';
import '../common/gallery_images.dart';
import '../common/log.dart';
import '../common/title_bar.dart';
import '../common/ui.dart';
import 'sub_window_state.dart';
import 'window_placement.dart';

/// 서브 엔진 초기화. 상세·카테고리 창이 같은 순서로 시작한다.
Future<SubWindowState> setUpSubWindow(WindowController controller, WindowArgs args) async {
  final state = SubWindowState(args, await loadGalleryImages());
  final isDetail = args is DetailArgs;
  final placement = isDetail ? besideMain : belowMain;

  // 1) 이 창의 WindowController 채널 핸들러. 앱 시작 시 한 번만 등록한다.
  await controller.setWindowMethodHandler((call) async {
    switch (call.method) {
      case Method.init:
        await state.onInit(WindowArgs.fromJson(Map<String, dynamic>.from(call.arguments as Map)));
        await windowManager.setTitle(windowTitleOf(state.args));
      case Method.placeNearMain:
        final anchor = ScreenAnchor.fromJson(Map<String, dynamic>.from(call.arguments as Map));
        await placeNearMain(anchor.bounds, placement);
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
  await hideNativeTitleBar();
  await windowManager.setPreventClose(kReuseWindows);
  windowManager.addListener(_CloseToHide(controller.windowId));
  await windowManager.setTitle(windowTitleOf(args));
  final minSize = isDetail ? kDetailWindowMinSize : kCategoryWindowMinSize;
  await windowManager.setMinimumSize(minSize);
  await windowManager.setSize(minSize);
  // 메인 창 근처. center()는 마우스 커서가 있는 모니터 기준이라 쓰지 않는다.
  final anchor = WindowArgs.anchorOf(controller.arguments);
  await (anchor == null ? windowManager.center() : placeNearMain(anchor.bounds, placement));

  await state.fetchAll();
  return state;
}

/// `hiddenAtLaunch: true`로 만들어진 창을 첫 프레임이 그려진 뒤 스스로 보여 준다.
Future<void> showAfterFirstFrame() async {
  await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
  await windowManager.show();
  log('lifecycle', 'first frame -> show');
}

/// OS 창 제목이자 커스텀 타이틀바(Windows·macOS)에 그리는 제목.
String windowTitleOf(WindowArgs args) => switch (args) {
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
