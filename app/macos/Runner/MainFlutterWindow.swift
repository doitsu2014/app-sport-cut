import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // One chrome band: the Flutter 52 px toolbar sits under the traffic
    // lights, so the native title bar must be transparent and its content
    // must extend to the top edge (ADR-0003 D6). The traffic lights stay
    // system chrome; the toolbar reserves their leading inset.
    self.title = "Sportcut"
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true

    // The studio keeps a fixed 264/320 rail geometry; below this width the
    // preview can no longer hold the court without collapsing the rails.
    self.contentMinSize = NSSize(width: 1100, height: 720)
    self.setContentSize(NSSize(width: 1180, height: 760))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
