import 'dart:math';
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../common/log.dart';

/// 이 창을 [anchor](메인 창 중심)가 있는 모니터 가운데로 옮긴다.
/// [onlyIfElsewhere]면 이미 그 모니터에 있을 때 사용자가 옮겨 둔 위치를 유지한다.
Future<void> moveToScreenOf(Offset anchor, {bool onlyIfElsewhere = false}) async {
  final (displays, primary, bounds) = await (
    screenRetriever.getAllDisplays(),
    screenRetriever.getPrimaryDisplay(),
    windowManager.getBounds(),
  ).wait;
  final area = pickWorkArea(displays.map(_workAreaOf), anchor, fallback: _workAreaOf(primary));
  if (onlyIfElsewhere && area.contains(bounds.center)) return;
  await windowManager.setPosition(centeredIn(area, bounds.size));
  log('lifecycle', 'move to main screen ${area.topLeft}');
}

/// [anchor]를 포함하는 작업 영역. 없으면 [fallback](주 모니터).
Rect pickWorkArea(Iterable<Rect> areas, Offset anchor, {required Rect fallback}) =>
    areas.where((area) => area.contains(anchor)).firstOrNull ?? fallback;

/// [area] 가운데에 [size] 창을 둘 때의 좌상단. 창이 더 크면 좌상단을 영역 안에 맞춘다.
Offset centeredIn(Rect area, Size size) =>
    Offset(max(area.left, area.center.dx - size.width / 2), max(area.top, area.center.dy - size.height / 2));

/// 메뉴 막대·Dock·작업 표시줄을 뺀 영역. window_manager와 같은 좌표계(주 모니터 좌상단 기준)다.
Rect _workAreaOf(Display display) => (display.visiblePosition ?? Offset.zero) & (display.visibleSize ?? display.size);
