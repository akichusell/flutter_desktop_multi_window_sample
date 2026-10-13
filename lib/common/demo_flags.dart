// 동작을 바꿔 비교해 보는 스위치. `--dart-define=이름=false`로 끈다.
// dart-define은 빌드에 박히므로 메인·서브 엔진이 같은 값을 본다.

/// 서브 창 재사용. false면 X에서 실제로 닫히고, 다시 열 때 엔진을 새로 만든다.
const kReuseWindows = bool.fromEnvironment('REUSE_WINDOWS', defaultValue: true);

/// 리스너 슬롯의 "내 것일 때만 해제" 가드. false면 늦게 온 dispose가 새 리스너를 지운다.
const kSlotGuard = bool.fromEnvironment('SLOT_GUARD', defaultValue: true);

/// reactionsChanged를 숨겨 둔 창에도 보낼지. false면 보이는 창에만 보내고, 다시 보여 줄 때 최신값을 보낸다.
const kPushToHiddenWindows = bool.fromEnvironment('PUSH_HIDDEN', defaultValue: true);
