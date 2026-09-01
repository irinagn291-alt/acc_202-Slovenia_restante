import SwiftUI

/// Role: Presentation. Settings spoke — contact, re-onboard, reset.
struct SettingsScreen: View {
    let control: PendulumControl
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.openURL) private var openURL
    @State private var confirmReset = false

    init(control: PendulumControl = .previewPopulated()) {
        self.control = control
    }

    var body: some View {
        let face = control.abstraction
        SpokeShell(title: "Settings", onClose: control.dismissSpoke) {
            VStack(alignment: .leading, spacing: PostageInk.space(2)) {
                if let fault = face.fault {
                    Text(fault)
                        .postageText(.body, category: sizeCategory)
                    PostageFillButton(title: "Retry") {
                        Task { await control.retry() }
                    }
                }
                Text("Wants live on this device")
                    .postageText(.headline, category: sizeCategory)
                Text(deviceLine(face))
                    .postageText(.body, category: sizeCategory)
                    .foregroundStyle(PostageInk.muted)
                heldBoard(face)
                Spacer(minLength: 0)
                if let url = URL(string: "https://restante.pro/contact-us") {
                    PostageFillButton(title: "Contact Restante") {
                        openURL(url)
                    }
                }
                PostageQuietButton(title: "Re-run onboarding") {
                    control.reopenOnboarding()
                }
                Button {
                    confirmReset = true
                } label: {
                    Text("Reset all data")
                        .font(PostageInk.font(.label, sizeCategory: sizeCategory))
                        .foregroundStyle(PostageInk.accent)
                        .frame(maxWidth: .infinity, minHeight: PostageInk.tap)
                        .background(PostageInk.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(PostageInk.accent.opacity(0.55), lineWidth: 1.5))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(face.commitBusy)
                .frame(maxWidth: .infinity)
            }
            .padding(PostageInk.space(2))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .confirmationDialog("Clear every waybill?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset all data", role: .destructive) {
                Task { await control.resetAll() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func heldBoard(_ face: PendulumAbstraction) -> some View {
        let held = face.cooling
        if held.isEmpty {
            Text("File a want from the clock when you are ready.")
                .postageText(.body, category: sizeCategory)
                .foregroundStyle(PostageInk.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: PostageInk.space(1)) {
                    Text(paydayLine(face))
                        .postageText(.label, category: sizeCategory)
                        .foregroundStyle(PostageInk.muted)
                    ForEach(held) { stamp in
                        Button {
                            control.focus(stamp.id)
                            control.dismissSpoke()
                        } label: {
                            HStack {
                                Text(stamp.title)
                                    .postageText(.label, category: sizeCategory)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer(minLength: PostageInk.space(1))
                                Text("\(PostageFigures.hours(stamp.remainingHours)) h")
                                    .postageText(.figure, category: sizeCategory)
                                    .monospacedDigit()
                            }
                            .padding(PostageInk.space(2))
                            .frame(maxWidth: .infinity, minHeight: PostageInk.tap, alignment: .leading)
                            .background(PostageInk.surface)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open \(stamp.title) on the clock")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func deviceLine(_ face: PendulumAbstraction) -> String {
        guard let focus = face.focus else {
            return "Nothing is cooling on this phone yet."
        }
        let extra = max(0, face.cooling.count - 1)
        if extra == 0 {
            return "\(focus.title) cools here. Nothing leaves this phone."
        }
        let more = PostageFigures.hours(Double(extra))
        return "\(focus.title) and \(more) more cool here. Nothing leaves this phone."
    }

    private func paydayLine(_ face: PendulumAbstraction) -> String {
        let date = Horology.date(from: face.paydayInstant)
        return "Next payday \(Self.paydayFormatter.string(from: date))"
    }

    private static let paydayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
}
