import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

import 'gallery_images.dart';
import 'reaction.dart';

// ── 채널 ───────────────────────────────────────────────────────────────
// 둘 다 메인이 등록(핸들러 1개)하고, 서브 엔진들이 호출한다.

/// 리액션 조회·토글. 소유자(SSOT)는 메인.
const reactionStoreChannel = WindowMethodChannel('reaction_store', mode: ChannelMode.unidirectional);

/// 창 열기 요청. 창 풀의 소유자도 메인.
const windowRouterChannel = WindowMethodChannel('window_router', mode: ChannelMode.unidirectional);

/// 채널별 메서드 이름.
abstract final class Method {
  // reaction_store (서브 → 메인)
  static const getAll = 'getAll';
  static const toggle = 'toggle';

  // window_router (서브 → 메인)
  static const openDetail = 'openDetail';
  static const windowHidden = 'windowHidden';

  // 각 서브 창의 WindowController 채널 (메인 → 서브)
  static const init = 'init';
  static const placeBesideMain = 'placeBesideMain';
  static const reactionsChanged = 'reactionsChanged';
  static const shutdown = 'shutdown';
}

// ── 창 arguments ───────────────────────────────────────────────────────
// WindowConfiguration.arguments는 String 하나뿐이라 JSON으로 넣는다. 메인은 빈 문자열.

sealed class WindowArgs {
  const WindowArgs();

  /// 로그용 창 태그: `detail:<파일 이름>`, `category:<리액션>`
  String get tag;

  Map<String, dynamic> toJson();

  /// [anchor]는 창 생성 시에만 `anchor` 키로 붙는다. fromJson은 이 키를 보지 않는다.
  String encode({ScreenAnchor? anchor}) => jsonEncode({...toJson(), 'anchor': ?anchor?.toJson()});

  /// 빈 문자열이면 null(= 메인 창).
  static WindowArgs? decode(String raw) => raw.isEmpty ? null : fromJson(jsonDecode(raw) as Map<String, dynamic>);

  /// 창 arguments의 `anchor`. 메인 창이거나 키가 없으면 null.
  static ScreenAnchor? anchorOf(String raw) {
    if (raw.isEmpty) return null;
    final anchor = (jsonDecode(raw) as Map<String, dynamic>)['anchor'];
    return anchor is Map ? ScreenAnchor.fromJson(Map<String, dynamic>.from(anchor)) : null;
  }

  static WindowArgs fromJson(Map<String, dynamic> json) => switch (json['type']) {
    'detail' => DetailArgs(json['imageId'] as String),
    'category' => CategoryArgs(Reaction.fromName(json['reaction'] as String)),
    final type => throw ArgumentError('unknown window type: $type'),
  };
}

/// `{"type":"detail","imageId":"assets/images/a.jpg"}`
class DetailArgs extends WindowArgs {
  const DetailArgs(this.imageId);

  final String imageId;

  @override
  String get tag => 'detail:${fileNameOf(imageId)}';

  @override
  Map<String, dynamic> toJson() => {'type': 'detail', 'imageId': imageId};
}

/// `{"type":"category","reaction":"heart"}` — 재사용 시 `init` 페이로드로도 쓴다.
class CategoryArgs extends WindowArgs {
  const CategoryArgs(this.reaction);

  final Reaction reaction;

  @override
  String get tag => 'category:${reaction.name}';

  @override
  Map<String, dynamic> toJson() => {'type': 'category', 'reaction': reaction.name};
}

// ── 채널 페이로드 ──────────────────────────────────────────────────────
// 엔진 경계는 Map·List·String만 넘는다. 받는 쪽은 Map<String, dynamic>.from(...)으로 변환.

/// `toggle` 요청: `{"imageId": ..., "reaction": "heart"}`
@immutable
class ToggleRequest {
  const ToggleRequest(this.imageId, this.reaction);

  final String imageId;
  final Reaction reaction;

  Map<String, dynamic> toJson() => {'imageId': imageId, 'reaction': reaction.name};

  factory ToggleRequest.fromJson(Map<String, dynamic> json) =>
      ToggleRequest(json['imageId'] as String, Reaction.fromName(json['reaction'] as String));
}

/// 서브 창 위치의 기준 = 메인 창 영역: `{"x": 100.0, "y": 80.0, "width": 840.0, "height": 630.0}`
/// 생성 시에는 창 arguments의 `anchor`로, 숨긴 창을 다시 보여 줄 때는 `placeBesideMain` 페이로드로 넘긴다.
@immutable
class ScreenAnchor {
  const ScreenAnchor(this.bounds);

  final Rect bounds;

  Map<String, dynamic> toJson() => {'x': bounds.left, 'y': bounds.top, 'width': bounds.width, 'height': bounds.height};

  factory ScreenAnchor.fromJson(Map<String, dynamic> json) => ScreenAnchor(
    Rect.fromLTWH(_toDouble(json['x']), _toDouble(json['y']), _toDouble(json['width']), _toDouble(json['height'])),
  );

  static double _toDouble(Object? value) => (value as num).toDouble();
}

/// 리액션 전체 상태의 읽기 전용 사본: `{"assets/images/a.jpg": ["heart", "like"], ...}`
/// 원본은 메인의 ReactionStore에만 있다. 서브는 이 사본을 받아 그리기만 한다.
@immutable
class ReactionSnapshot {
  const ReactionSnapshot(this._byImage);

  static const empty = ReactionSnapshot({});

  final Map<String, Set<Reaction>> _byImage;

  /// 이미지에 붙은 리액션 (enum 순서로 정렬).
  List<Reaction> of(String imageId) {
    final set = _byImage[imageId] ?? const <Reaction>{};
    return Reaction.values.where(set.contains).toList();
  }

  bool has(String imageId, Reaction reaction) => _byImage[imageId]?.contains(reaction) ?? false;

  int countOf(Reaction reaction) => _byImage.values.where((set) => set.contains(reaction)).length;

  Map<String, dynamic> toJson() => {
    for (final MapEntry(:key, :value) in _byImage.entries)
      if (value.isNotEmpty) key: [for (final r in value) r.name],
  };

  factory ReactionSnapshot.fromJson(Map<String, dynamic> json) => ReactionSnapshot({
    for (final MapEntry(:key, :value) in json.entries)
      key: {for (final name in value as List) Reaction.fromName(name as String)},
  });
}
