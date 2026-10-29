import 'dart:math';
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../common/log.dart';

/// [size] 창을 메인 창 [main] 근처 [area] 안에 둘 때의 좌상단.
typedef Placement = Offset Function(Rect main, Size size, Rect area);

/// 이 창을 [placement]로 [main](메인 창 영역) 근처에 둔다. 메인 창이 있는 모니터를 벗어나지 않는다.
Future<void> placeNearMain(Rect main, Placement placement) async {
  final (displays, primary, bounds) = await (
    screenRetriever.getAllDisplays(),
    screenRetriever.getPrimaryDisplay(),
    windowManager.getBounds(),
  ).wait;
  final area = pickWorkArea(displays.map(_workAreaOf), main.center, fallback: _workAreaOf(primary));
  final position = placement(main, bounds.size, area);
  await windowManager.setPosition(position);
  log('lifecycle', 'place near main $position');
}

/// [anchor]를 포함하는 작업 영역. 없으면 [fallback](주 모니터).
Rect pickWorkArea(Iterable<Rect> areas, Offset anchor, {required Rect fallback}) =>
    areas.where((area) => area.contains(anchor)).firstOrNull ?? fallback;

/// 가로는 [area] 안에 들어가는 첫 자리: 1) 메인 오른쪽  2) 메인 왼쪽  3) 영역 오른쪽 끝 (메인과 겹친다)
/// 세로는 메인 중앙에 맞추되 영역 밖으로 나가지 않게 자른다.
Offset besideMain(Rect main, Size size, Rect area) => Offset(
  _firstFit(main.left, main.right, size.width, area.left, area.right),
  _clampStart(main.center.dy - size.height / 2, area.top, area.bottom, size.height),
);

/// 세로는 [area] 안에 들어가는 첫 자리: 1) 메인 아래  2) 메인 위  3) 영역 아래 끝 (메인과 겹친다)
/// 가로는 메인 중앙에 맞추되 영역 밖으로 나가지 않게 자른다.
Offset belowMain(Rect main, Size size, Rect area) => Offset(
  _clampStart(main.center.dx - size.width / 2, area.left, area.right, size.width),
  _firstFit(main.top, main.bottom, size.height, area.top, area.bottom),
);

/// 한 축에서 메인([start]..[end]) 뒤, 앞, 영역 끝 순으로 [length]가 [from]..[to]에 들어가는 첫 시작점.
double _firstFit(double start, double end, double length, double from, double to) {
  if (end + length <= to) return end;
  if (start - length >= from) return start - length;
  return max(from, to - length);
}

/// [length] 길이 창의 시작점을 [from]..[to] 안에 맞춘다. 창이 더 길면 [from]에 붙인다.
double _clampStart(double start, double from, double to, double length) => start.clamp(from, max(from, to - length));

/// 메뉴 막대·Dock·작업 표시줄을 뺀 영역. window_manager와 같은 좌표계(주 모니터 좌상단 기준)다.
Rect _workAreaOf(Display display) => (display.visiblePosition ?? Offset.zero) & (display.visibleSize ?? display.size);
