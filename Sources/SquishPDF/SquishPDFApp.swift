import SwiftUI
import AppKit

@main
struct SquishPDFApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Window dimensions aligned to 8-point grid
    private static let windowWidth: CGFloat = 424   // Close to golden ratio container
    private static let windowHeight: CGFloat = 856  // Comfortable for 7 presets + sections

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, maxWidth: 600, minHeight: 800)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: Self.windowWidth, height: Self.windowHeight)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About SquishPDF") {
                    appDelegate.showAboutPanel()
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.title = "SquishPDF"
            window.setContentSize(NSSize(width: 424, height: 856))
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }

    func showAboutPanel() {
        let year = Calendar.current.component(.year, from: Date())

        let creditsText = """
        © \(year) Demed L'Her
        AGPL-3.0 License

        Compress PDFs while preserving text selectability.
        Powered by Ghostscript.

        https://github.com/demedlher/SquishPDF
        """

        let credits = NSAttributedString(
            string: creditsText,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "SquishPDF",
            .applicationVersion: AppVersion.version,
            .version: AppVersion.versionWithBuild,
            .credits: credits
        ])
    }
}
