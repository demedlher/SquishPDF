import SwiftUI
import AppKit

@main
struct PDFConverterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, maxWidth: 600, minHeight: 520)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 580)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.title = "PDF Converter"
            window.setContentSize(NSSize(width: 400, height: 580))
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }
} 