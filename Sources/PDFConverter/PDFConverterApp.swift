import SwiftUI
import AppKit

@main
struct PDFConverterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, maxWidth: 600, minHeight: 600)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 640)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About PDF Converter") {
                    appDelegate.showAboutPanel()
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.title = "PDF Converter"
            window.setContentSize(NSSize(width: 420, height: 640))
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }

    func showAboutPanel() {
        let year = Calendar.current.component(.year, from: Date())

        let creditsText = """
        © \(year) Demed L'Her

        Compress PDFs while preserving text selectability.
        Powered by Ghostscript.

        https://github.com/demedlher/PDFConverter
        """

        let credits = NSAttributedString(
            string: creditsText,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "PDF Converter",
            .applicationVersion: "2.5",
            .version: "2.5.0",
            .credits: credits
        ])
    }
}
