import 'package:flutter_test/flutter_test.dart';
import 'package:multi_window_sample/common/channels.dart';
import 'package:multi_window_sample/common/reaction.dart';

void main() {
  group('WindowArgs', () {
    test('빈 문자열은 메인 창(null)', () {
      expect(WindowArgs.decode(''), isNull);
    });

    test('detail 왕복', () {
      final args = WindowArgs.decode(const DetailArgs('assets/images/a.jpg').encode());
      expect(args, isA<DetailArgs>().having((a) => a.imageId, 'imageId', 'assets/images/a.jpg'));
      expect(args?.tag, 'detail:a.jpg');
    });

    test('category 왕복', () {
      final args = WindowArgs.decode(const CategoryArgs(Reaction.heart).encode());
      expect(args, isA<CategoryArgs>().having((a) => a.reaction, 'reaction', Reaction.heart));
      expect(args?.tag, 'category:heart');
    });

    test('알 수 없는 type은 에러', () {
      expect(() => WindowArgs.decode('{"type":"unknown"}'), throwsArgumentError);
    });

    test('anchor는 encode에 붙고 decode는 무시한다', () {
      final raw = const DetailArgs('assets/images/a.jpg').encode(anchor: const ScreenAnchor(Offset(640, 400)));
      expect(WindowArgs.decode(raw), isA<DetailArgs>());
      expect(WindowArgs.anchorOf(raw)?.point, const Offset(640, 400));
    });

    test('anchor가 없거나 메인 창이면 null', () {
      expect(WindowArgs.anchorOf(const CategoryArgs(Reaction.heart).encode()), isNull);
      expect(WindowArgs.anchorOf(''), isNull);
    });
  });

  group('ScreenAnchor', () {
    test('채널이 넘겨주는 int 좌표도 double로 읽는다', () {
      expect(ScreenAnchor.fromJson(const {'x': 1440, 'y': -200}).point, const Offset(1440, -200));
    });
  });

  group('ReactionSnapshot', () {
    test('toJson → fromJson 왕복 (채널이 넘겨주는 Map<Object?, Object?> 형태 포함)', () {
      const original = ReactionSnapshot({
        'a.jpg': {Reaction.like, Reaction.heart},
        'b.jpg': {},
      });
      final overChannel = Map<Object?, Object?>.from(original.toJson());
      final restored = ReactionSnapshot.fromJson(Map<String, dynamic>.from(overChannel));

      expect(restored.of('a.jpg'), [Reaction.heart, Reaction.like]); // enum 순서로 정렬
      expect(restored.of('b.jpg'), isEmpty);
      expect(restored.of('none.jpg'), isEmpty);
      expect(original.toJson().containsKey('b.jpg'), isFalse); // 빈 항목은 보내지 않는다
    });

    test('countOf / has', () {
      const snapshot = ReactionSnapshot({
        'a.jpg': {Reaction.heart},
        'b.jpg': {Reaction.heart, Reaction.wow},
      });
      expect(snapshot.countOf(Reaction.heart), 2);
      expect(snapshot.countOf(Reaction.like), 0);
      expect(snapshot.has('b.jpg', Reaction.wow), isTrue);
    });
  });

  test('ToggleRequest 왕복', () {
    final json = Map<String, dynamic>.from(const ToggleRequest('a.jpg', Reaction.laugh).toJson());
    final restored = ToggleRequest.fromJson(json);
    expect(restored.imageId, 'a.jpg');
    expect(restored.reaction, Reaction.laugh);
  });
}
