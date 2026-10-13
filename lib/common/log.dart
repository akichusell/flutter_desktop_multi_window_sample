import 'package:flutter/foundation.dart';

/// 창 태그. 전역 변수지만 엔진(= Dart 힙)마다 따로 존재하므로 창마다 값이 다르다.
String _windowTag = 'main';

/// debug에서는 항상, profile·release에서는 `--dart-define=LOG=true`일 때만 남긴다.
const bool _logEnabled = kDebugMode || bool.fromEnvironment('LOG');

void setWindowTag(String tag) => _windowTag = tag;

/// 모든 창의 로그가 한 콘솔에 섞이므로 `[창 태그] 단계: 내용` 형식으로 남긴다.
void log(String step, String message) {
  if (!_logEnabled) return;
  print('[$_windowTag] $step: $message');
}
