import SwiftUI

/// Role: Presentation. Four pages. Skip still writes factory payday defaults.
struct OnboardingFace: View {
    let control: PendulumControl
    @State private var page = 0
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(control: PendulumControl = .previewPopulated()) {
        self.control = control
    }

    var body: some View {
        VStack(spacing: PostageInk.space(2)) {
            Group {
                switch page {
                case 0:
                    pageView(
                        image: PostageArt.onboarding(0),
                        title: "Held until payday",
                        line: "Impulse wants wait in poste restante. The lock is payday, not a 24-hour timer."
                    )
                case 1:
                    pageView(
                        image: PostageArt.onboarding(1),
                        title: "File a want",
                        line: "Price, necessity, discretion and priority wind the span. Hours then snap forward."
                    )
                case 2:
                    pageView(
                        image: PostageArt.onboarding(2),
                        title: "Remontoire, not a skip",
                        line: "Buy early only by sacrificing another cooling want whose hours cover the gap."
                    )
                default:
                    pageView(
                        image: PostageArt.twist,
                        title: "Set the payday gate",
                        line: "Weekday, interval and monthly impulse limit. Skip still lodges Friday every two weeks."
                    )
                }
            }
            .frame(maxHeight: .infinity)
            .animation(reduceMotion ? nil : PostageInk.motion, value: page)
            HStack {
                Button("Skip") {
                    Task { await control.finishOnboarding() }
                }
                .postageText(.label, category: sizeCategory)
                .postageTap()
                Spacer()
                if page < 3 {
                    Button("Next") { page += 1 }
                        .postageText(.label, category: sizeCategory)
                        .foregroundStyle(PostageInk.accent)
                        .postageTap()
                } else {
                    Button("Open the clock") {
                        Task { await control.finishOnboarding() }
                    }
                    .postageText(.label, category: sizeCategory)
                    .foregroundStyle(PostageInk.accent)
                    .postageTap()
                }
            }
            .padding(.horizontal, PostageInk.space(2))
        }
        .padding(.vertical, PostageInk.space(3))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PostageInk.background.ignoresSafeArea())
    }

    private func pageView(image: String, title: String, line: String) -> some View {
        VStack(spacing: PostageInk.space(2)) {
            PostageMark(name: image, maxWidth: 280, maxHeight: 280, fallback: .ring)
            Text(title)
                .postageText(.headline, category: sizeCategory)
                .multilineTextAlignment(.center)
            Text(line)
                .postageText(.body, category: sizeCategory)
                .foregroundStyle(PostageInk.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PostageInk.space(3))
        }
    }
}
