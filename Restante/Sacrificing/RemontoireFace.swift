import SwiftUI

/// Role: Presentation. Swap-release spoke. Closed gate is remontoire or wait, never a skip.
struct RemontoireFace: View {
    let control: RemontoireControl
    var onClose: () -> Void
    @Environment(\.sizeCategory) private var sizeCategory

    init(control: RemontoireControl, onClose: @escaping () -> Void = {}) {
        self.control = control
        self.onClose = onClose
    }

    var body: some View {
        let face = control.abstraction
        SpokeShell(title: "Sacrifice a want", onClose: onClose) {
            VStack(alignment: .leading, spacing: PostageInk.space(2)) {
                if let focus = face.focus {
                    Text(focus.title)
                        .postageText(.headline, category: sizeCategory)
                        .lineLimit(1)
                    Text("\(PostageFigures.hours(focus.remainingHours)) hours to payday")
                        .postageText(.figure, category: sizeCategory)
                        .monospacedDigit()
                }
                Text("Sacrifice another cooling want whose remaining hours cover that gap.")
                    .postageText(.body, category: sizeCategory)
                    .foregroundStyle(PostageInk.muted)
                if let fault = face.fault {
                    Text(fault)
                        .postageText(.body, category: sizeCategory)
                    PostageFillButton(title: "Retry") { control.prepare() }
                }
                if face.donors.isEmpty {
                    PostagePlate(
                        image: PostageArt.emptyList,
                        headline: "No donor covers the gap",
                        line: "File another want, or wait for payday.",
                        actionTitle: "Wait",
                        action: onClose
                    )
                } else {
                    VStack(spacing: PostageInk.space(1)) {
                            ForEach(face.donors) { donor in
                                Button {
                                    Task { try? await control.sacrifice(donor.id) }
                                } label: {
                                    HStack {
                                        Text(donor.title)
                                            .postageText(.label, category: sizeCategory)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(PostageFigures.hours(donor.remainingHours))
                                            .postageText(.figure, category: sizeCategory)
                                            .monospacedDigit()
                                    }
                                    .padding(PostageInk.space(2))
                                    .frame(maxWidth: .infinity, minHeight: PostageInk.tap)
                                    .background(PostageInk.surface)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(face.busy)
                                .accessibilityLabel("Sacrifice \(donor.title)")
                            }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(PostageInk.space(2))
        }
    }
}
