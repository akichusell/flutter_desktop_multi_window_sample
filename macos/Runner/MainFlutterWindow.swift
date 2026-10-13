import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // 메인 엔진의 플러그인 등록
    RegisterGeneratedPlugins(registry: flutterViewController)

    // 서브 엔진 생성 콜백 (Slide 8)
    // 엔진마다 플러그인 채널이 따로라서, 새 엔진이 생길 때마다 플러그인 전체를 다시 등록한다.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
    }

    super.awakeFromNib()
  }
}
