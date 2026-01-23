import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
            CommandGroup(after: .help) {
                Button("Run Benchmark...") {
                    appDelegate.runBenchmark()
                }
                .keyboardShortcut("B", modifiers: [.command, .option])
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
        let creditsText = """
        © 2025 Demed L'Her – Dedicated-Labs.com
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

    func runBenchmark() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.message = "Select PDF files to benchmark"

        if panel.runModal() == .OK {
            Task {
                let engines: [CompressionEngine] = [
                    GhostscriptEngine(),
                    NativeCompressionEngine()
                ]
                let benchmark = CompressionBenchmark(engines: engines)

                var allResults: [BenchmarkResult] = []
                for url in panel.urls {
                    let results = await benchmark.benchmark(file: url)
                    allResults.append(contentsOf: results)
                }

                let markdown = CompressionBenchmark.formatAsMarkdown(allResults)
                print(markdown)

                // Also save to Desktop
                let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                let outputURL = desktopURL.appendingPathComponent("benchmark-results.md")
                try? markdown.write(to: outputURL, atomically: true, encoding: .utf8)
                NSWorkspace.shared.open(outputURL)
            }
        }
    }
}
