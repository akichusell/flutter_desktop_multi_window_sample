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

  group('besideMain', () {
    const area = Rect.fromLTWH(0, 25, 1440, 875);
    const size = Size(520, 390);

    test('오른쪽에 공간이 있으면 메인 오른쪽, 세로는 메인 중앙', () {
      const main = Rect.fromLTWH(100, 200, 600, 400); // 오른쪽 끝 700 + 520 <= 1440
      expect(besideMain(main, size, area), const Offset(700, 200 + 200 - 195));
    });

    test('오른쪽이 모자라면 메인 왼쪽', () {
      const main = Rect.fromLTWH(600, 200, 600, 400); // 1200 + 520 > 1440, 600 - 520 >= 0
      expect(besideMain(main, size, area), const Offset(80, 205));
    });

    test('양쪽 다 모자라면 영역 오른쪽 끝에 붙여 메인과 겹친다', () {
      const main = Rect.fromLTWH(300, 200, 900, 400); // 1200 + 520 > 1440, 300 - 520 < 0
      expect(besideMain(main, size, area), const Offset(1440 - 520, 205));
    });

    test('딱 맞으면 오른쪽에 둔다 (경계 포함)', () {
      const main = Rect.fromLTWH(320, 200, 600, 400); // 920 + 520 == 1440
      expect(besideMain(main, size, area).dx, 920);
    });

    test('세로가 영역을 넘으면 위·아래 끝에 맞춘다', () {
      const nearTop = Rect.fromLTWH(100, 25, 600, 100); // 중앙 75 - 195 < 25
      const nearBottom = Rect.fromLTWH(100, 800, 600, 100); // 중앙 850 + 195 > 900
      expect(besideMain(nearTop, size, area).dy, 25);
      expect(besideMain(nearBottom, size, area).dy, 900 - 390);
    });

    test('창이 영역보다 크면 좌상단을 영역에 맞춘다', () {
      const main = Rect.fromLTWH(100, 200, 600, 400);
      expect(besideMain(main, const Size(2000, 1000), area), const Offset(0, 25));
    });

    test('보조 모니터에서도 그 모니터 영역 기준으로 계산한다', () {
      const main = Rect.fromLTWH(2900, 100, 400, 300); // 오른쪽 끝 3300 + 520 > 3360
      expect(besideMain(main, size, right), const Offset(2900 - 520, 55));
    });
  });

  group('belowMain', () {
    const area = Rect.fromLTWH(0, 25, 1440, 875);
    const size = Size(560, 420);

    test('아래에 공간이 있으면 메인 아래, 가로는 메인 중앙', () {
      const main = Rect.fromLTWH(300, 25, 600, 400); // 아래 끝 425 + 420 <= 900
      expect(belowMain(main, size, area), const Offset(300 + 300 - 280, 425));
    });

    test('아래가 모자라면 메인 위', () {
      const main = Rect.fromLTWH(300, 450, 600, 400); // 850 + 420 > 900, 450 - 420 >= 25
      expect(belowMain(main, size, area), const Offset(320, 30));
    });

    test('위아래 다 모자라면 영역 아래 끝에 붙여 메인과 겹친다', () {
      const main = Rect.fromLTWH(300, 200, 600, 400); // 600 + 420 > 900, 200 - 420 < 25
      expect(belowMain(main, size, area), const Offset(320, 900 - 420));
    });

    test('딱 맞으면 아래에 둔다 (경계 포함)', () {
      const main = Rect.fromLTWH(300, 80, 600, 400); // 480 + 420 == 900
      expect(belowMain(main, size, area).dy, 480);
    });

    test('가로가 영역을 넘으면 왼쪽·오른쪽 끝에 맞춘다', () {
      const nearLeft = Rect.fromLTWH(0, 25, 200, 300); // 중앙 100 - 280 < 0
      const nearRight = Rect.fromLTWH(1240, 25, 200, 300); // 중앙 1340 + 280 > 1440
      expect(belowMain(nearLeft, size, area).dx, 0);
      expect(belowMain(nearRight, size, area).dx, 1440 - 560);
    });
  });
}
