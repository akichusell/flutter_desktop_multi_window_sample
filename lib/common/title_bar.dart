import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Windows에서만 OS 타이틀바를 숨기고 Flutter로 직접 그린다. macOS는 기본 타이틀바를 그대로 쓴다.
bool get useCustomTitleBar => defaultTargetPlatform == TargetPlatform.windows;

/// 엔진마다 자기 창의 타이틀바를 숨긴다. `windowManager.ensureInitialized()` 뒤에 부른다.
Future<void> hideNativeTitleBar() async {
  if (!useCustomTitleBar) return;
  await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
}

/// 창 상단에 제목 + 최소화·최대화·닫기 버튼을 얹는다. 제목 영역을 끌면 창이 움직이고, 더블클릭하면 최대화한다.
/// 닫기는 `windowManager.close()`라 setPreventClose → onWindowClose 흐름을 그대로 탄다.
///
/// 타이틀바를 숨기면 위쪽에 OS 리사이즈 테두리가 없다 (좌·우·하단 8px만 남는다).
/// [VirtualWindowFrame]이 위·왼쪽 위·오른쪽 위 가장자리 8px에 리사이즈 영역을 깔고, 끌면 `startResizing`으로 OS에 넘긴다.
/// 최대화 중에는 꺼진다.
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
          SizedBox(
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
