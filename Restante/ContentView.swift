import SwiftUI

/// Role: Presentation. Hub host. Pendulum never leaves. Spokes arrive as sheets.
struct ContentView: View {
    let control: PendulumControl
    @Environment(\.scenePhase) private var scenePhase

    init(control: PendulumControl = .previewPopulated()) {
        self.control = control
    }

    var body: some View {
        Group {
            if control.abstraction.onboarded {
                PendulumFace(control: control)
            } else {
                OnboardingFace(control: control)
            }
        }
        .task { await control.appear() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                Task { await control.flush() }
            }
        }
        .fullScreenCover(item: spokeBinding) { spoke in
            switch spoke {
            case .filing:
                FilingFace(control: control.filing, onClose: control.dismissSpoke)
            case .remontoire:
                RemontoireFace(control: control.sacrificing, onClose: control.dismissSpoke)
            case .payday:
                EscapementFace(control: control.gating, onClose: control.dismissSpoke)
            case .dispatch:
                DispatchScreen(control: control)
            case .regulator:
                RegulatorScreen(control: control)
            case .settings:
                SettingsScreen(control: control)
            case .onboarding:
                OnboardingFace(control: control)
            }
        }
    }

    private var spokeBinding: Binding<PendulumSpoke?> {
        Binding(
            get: { control.abstraction.spoke },
            set: { next in
                if next == nil {
                    control.dismissSpoke()
                }
            }
        )
    }
}

#Preview {
    ContentView()
}
