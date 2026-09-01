import SwiftUI
import UIKit

/// Role: Presentation. Twist spoke — payday gate. Only UIKit bridge in the app.
struct EscapementFace: View {
    let control: EscapementControl
    var onClose: () -> Void
    @Environment(\.sizeCategory) private var sizeCategory

    init(control: EscapementControl = PendulumControl.previewPopulated().gating, onClose: @escaping () -> Void = {}) {
        self.control = control
        self.onClose = onClose
    }

    var body: some View {
        let gate = control.abstraction
        SpokeShell(title: "Payday gate", onClose: onClose) {
            VStack(spacing: PostageInk.space(2)) {
                    PostageMark(name: PostageArt.twist, maxHeight: 160, fallback: .ring)
                    Text("Payday is the lock")
                        .postageText(.headline, category: sizeCategory)
                    Text("Hours never fire mid-cycle. They snap to this weekday.")
                        .postageText(.body, category: sizeCategory)
                        .foregroundStyle(PostageInk.muted)
                        .multilineTextAlignment(.center)
                    PaydayCalendar(selected: gate.selectedDay) { date in
                        control.select(date)
                    }
                    .frame(minHeight: 280)
                    HStack {
                        Text("Interval days")
                            .postageText(.label, category: sizeCategory)
                        Spacer()
                        stepButton("−", label: "Shorter interval") {
                            control.setInterval(gate.intervalDays - 1)
                        }
                        Text(PostageFigures.hours(Double(gate.intervalDays)))
                            .postageText(.figure, category: sizeCategory)
                            .monospacedDigit()
                        stepButton("+", label: "Longer interval") {
                            control.setInterval(gate.intervalDays + 1)
                        }
                    }
                    .padding(.horizontal, PostageInk.space(2))
                    if let fault = gate.fault {
                        Text(fault)
                            .postageText(.body, category: sizeCategory)
                        PostageFillButton(title: "Retry", enabled: !gate.busy) {
                            Task { try? await control.lodge() }
                        }
                    }
                    PostageFillButton(title: "Lodge payday", enabled: !gate.busy) {
                        Task { try? await control.lodge() }
                    }
            }
            .padding(PostageInk.space(2))
        }
    }

    private func stepButton(_ title: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .postageText(.label, category: sizeCategory)
                .frame(minWidth: PostageInk.tap, minHeight: PostageInk.tap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Role: Presentation. UIViewRepresentable wrapping UICalendarView. No other representables.
struct PaydayCalendar: UIViewRepresentable {
    var selected: Date
    var onChange: (Date) -> Void

    func makeCoordinator() -> Binder {
        Binder(onChange: onChange)
    }

    func makeUIView(context: Context) -> HitCalendar {
        let view = HitCalendar()
        view.calendar = Calendar.current
        view.locale = .current
        view.tintColor = UIColor(named: "accent")
        view.availableDateRange = DateInterval(start: Calendar.current.startOfDay(for: Date()), duration: 60 * 60 * 24 * 720)
        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.setSelected(
            Calendar.current.dateComponents([.year, .month, .day], from: selected),
            animated: false
        )
        view.selectionBehavior = selection
        return view
    }

    func updateUIView(_ uiView: HitCalendar, context: Context) {
        context.coordinator.onChange = onChange
        if let selection = uiView.selectionBehavior as? UICalendarSelectionSingleDate {
            selection.setSelected(
                Calendar.current.dateComponents([.year, .month, .day], from: selected),
                animated: false
            )
        }
    }

    @MainActor
    final class Binder: NSObject, UICalendarSelectionSingleDateDelegate {
        var onChange: (Date) -> Void

        init(onChange: @escaping (Date) -> Void) {
            self.onChange = onChange
        }

        func dateSelection(
            _ selection: UICalendarSelectionSingleDate,
            didSelectDate dateComponents: DateComponents?
        ) {
            guard let dateComponents,
                  let date = Calendar.current.date(from: dateComponents)
            else { return }
            onChange(Calendar.current.startOfDay(for: date))
        }
    }
}

/// Role: Presentation. Hit area uses bounds, never smaller than 44.
final class HitCalendar: UICalendarView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let box = bounds.insetBy(
            dx: min(0, (bounds.width - 44) / 2),
            dy: min(0, (bounds.height - 44) / 2)
        )
        return box.contains(point)
    }
}
