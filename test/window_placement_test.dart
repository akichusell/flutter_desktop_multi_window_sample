import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_window_sample/sub_window/window_placement.dart';

void main() {
  const left = Rect.fromLTWH(0, 25, 1440, 875); // 주 모니터 (메뉴 막대 제외)
  const right = Rect.fromLTWH(1440, -200, 1920, 1080); // 오른쪽 위로 걸친 보조 모니터

  group('pickWorkArea', () {
    test('기준점을 포함한 모니터를 고른다', () {
      expect(pickWorkArea([left, right], const Offset(2000, 100), fallback: left), right);
      expect(pickWorkArea([left, right], const Offset(700, 400), fallback: right), left);
    });

    test('어느 모니터에도 없으면 fallback', () {
      expect(pickWorkArea([left, right], const Offset(-500, -500), fallback: left), left);
      expect(pickWorkArea(const [], const Offset(700, 400), fallback: left), left);
    });
  });

  group('centeredIn', () {
    test('영역 가운데에 둔다', () {
      expect(centeredIn(right, const Size(520, 390)), const Offset(1440 + 700, -200 + 345));
    });

    test('창이 영역보다 크면 좌상단을 영역에 맞춘다', () {
      expect(centeredIn(left, const Size(2000, 1000)), const Offset(0, 25));
    });
  });
}
