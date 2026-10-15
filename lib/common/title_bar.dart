import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

/// Windows·macOS에서 OS 타이틀바를 숨기고 Flutter로 직접 그린다. macOS는 신호등 버튼만 OS 것을 그대로 쓴다.
bool get useCustomTitleBar => defaultTargetPlatform == TargetPlatform.windows || _isMacOS;

/// macOS 기본 타이틀바 높이. 신호등 버튼이 이 높이의 세로 가운데에 놓인다.
const double _kMacTitleBarHeight = 28;

/// 신호등 버튼 3개가 차지하는 왼쪽 폭. 제목을 가운데 두려고 양쪽에 같은 폭을 비운다.
const double _kMacTrafficLightsWidth = 78;

/// 엔진마다 자기 창의 타이틀바를 숨긴다. `windowManager.ensureInitialized()` 뒤에 부른다.
Future<void> hideNativeTitleBar() async {
  if (!useCustomTitleBar) return;
  await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: _isMacOS);
}

/// 창 상단에 타이틀바를 얹는다. 제목 영역을 끌면 창이 움직이고, 더블클릭하면 최대화(macOS는 zoom)한다.
///
/// - Windows: 제목 + 최소화·최대화·닫기 버튼을 Flutter로 그린다. 닫기는 `windowManager.close()`라
///   setPreventClose → onWindowClose 흐름을 그대로 탄다.
/// - macOS: 버튼은 OS 신호등을 그대로 쓰고, Flutter는 가운데 제목과 드래그 영역만 그린다.
///
/// Windows는 타이틀바를 숨기면 위쪽에 OS 리사이즈 테두리가 없다 (좌·우·하단 8px만 남는다).
/// [VirtualWindowFrame]이 위·왼쪽 위·오른쪽 위 가장자리 8px에 리사이즈 영역을 깔고, 끌면 `startResizing`으로 OS에 넘긴다.
/// 최대화 중에는 꺼진다. macOS는 OS 리사이즈 테두리가 그대로 남아 [VirtualWindowFrame]이 child를 그대로 돌려준다.
class WindowFrame extends StatelessWidget {
  const WindowFrame({super.key, required this.title, required this.child, this.brightness = Brightness.light});

  final String title;
  final Widget child;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    if (!useCustomTitleBar) return child;
    return VirtualWindowFrame(
      child: Column(
        children: [
          _isMacOS
              ? _MacTitleBar(title: title, brightness: brightness)
              : SizedBox(
                  height: kWindowCaptionHeight,
                  child: WindowCaption(
                    title: Text(title, style: const TextStyle(fontSize: 12)),
                    brightness: brightness,
                    backgroundColor: Colors.transparent, // 창 배경과 이어지게
                  ),
                ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// macOS 기본 타이틀바처럼 가운데 제목만 그린다. 왼쪽 신호등 버튼은 OS가 이 영역 위에 그린다.
class _MacTitleBar extends StatelessWidget {
  const _MacTitleBar({required this.title, required this.brightness});

  final String title;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final color = brightness == Brightness.dark ? Colors.white70 : Colors.black87;
    return SizedBox(
      height: _kMacTitleBarHeight,
      child: DragToMoveArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kMacTrafficLightsWidth),
          child: Center(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
