import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/widgets.dart';

import 'common/channels.dart';
import 'common/log.dart';
import 'main_window/main_app.dart';
import 'sub_window/category_app.dart';
import 'sub_window/detail_app.dart';
import 'sub_window/sub_bootstrap.dart';

/// 창을 하나 열 때마다 엔진이 하나 새로 뜨고, 그 엔진에서 이 main()이 처음부터 다시 실행된다.
/// 그래서 "지금 어떤 창인가"를 arguments로 판별해 runApp을 분기한다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = await WindowController.fromCurrentEngine();
  final args = WindowArgs.decode(controller.arguments); // 메인은 빈 문자열 → null

  setWindowTag(args?.tag ?? 'main');
  log('engine', 'start ${args?.toJson()['type'] ?? 'main'} window (id ${controller.windowId})');

  switch (args) {
    case null:
      runApp(await setUpMainWindow());
    case DetailArgs():
      runApp(DetailApp(state: await setUpSubWindow(controller, args), args: args));
      await showAfterFirstFrame();
    case CategoryArgs():
      runApp(CategoryApp(state: await setUpSubWindow(controller, args)));
      await showAfterFirstFrame();
  }
}
