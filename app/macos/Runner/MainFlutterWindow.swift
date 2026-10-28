import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // The studio keeps a fixed 264/320 rail geometry; below this width the
    // preview can no longer hold the court without collapsing the rails.
    self.title = "Sportcut"
    self.contentMinSize = NSSize(width: 1100, height: 720)
    self.setContentSize(NSSize(width: 1180, height: 760))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
