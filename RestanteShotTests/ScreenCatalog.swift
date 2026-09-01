import SwiftUI
@testable import Restante

enum ScreenCatalog {
    @MainActor
    static var shots: [(String, AnyView)] {
        [
            ("pendulum", AnyView(PendulumFace())),
            ("dispatch", AnyView(DispatchScreen())),
            ("regulator", AnyView(RegulatorScreen())),
            ("settings", AnyView(SettingsScreen()))
        ]
    }
}
