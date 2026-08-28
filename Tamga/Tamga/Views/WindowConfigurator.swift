import AppKit
import SwiftUI

/// Keeps the editor content below the title bar.
///
/// The newer macOS SDK gives a plain `WindowGroup` a title bar that draws over the
/// content, because the window carries `fullSizeContentView`. That hides the tab bar,
/// which is the first row of the content. Clearing that style mask and making the title
/// bar opaque puts the content back under the title bar.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.styleMask.remove(.fullSizeContentView)
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
    }
}
