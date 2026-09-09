import SwiftUI

@main
struct KinetMagicDiskApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(after: .newItem) {
                Button(I18n.t("menu.scanHome")) {
                    NotificationCenter.default.post(name: .kmdScanHome, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
                Button(I18n.t("menu.pickFolder")) {
                    NotificationCenter.default.post(name: .kmdPickFolder, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let kmdScanHome = Notification.Name("kmdScanHome")
    static let kmdPickFolder = Notification.Name("kmdPickFolder")
}
