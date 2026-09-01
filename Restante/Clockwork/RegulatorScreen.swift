import SwiftUI

/// Role: Presentation. Rules spoke — payday weekday, interval, monthly limit.
struct RegulatorScreen: View {
    let control: PendulumControl
    @Environment(\.sizeCategory) private var sizeCategory

    init(control: PendulumControl = .previewPopulated()) {
        self.control = control
    }

    var body: some View {
        let rules = control.regulator.abstraction
        SpokeShell(title: "Regulator", onClose: control.dismissSpoke) {
            VStack(alignment: .leading, spacing: PostageInk.space(2)) {
                if let fault = rules.fault {
                    Text(fault)
                        .postageText(.body, category: sizeCategory)
                    PostageFillButton(title: "Retry", enabled: !rules.busy) {
                        Task { try? await control.regulator.lodge() }
                    }
                }
                Text("Payday weekday")
                    .postageText(.label, category: sizeCategory)
                VStack(spacing: 0) {
                    ForEach(1 ... 7, id: \.self) { day in
                        Button {
                            control.regulator.setWeekday(day)
                        } label: {
                            HStack {
                                Text(weekdayName(day))
                                    .font(PostageInk.font(.label, sizeCategory: sizeCategory))
                                    .foregroundStyle(PostageInk.ink)
                                Spacer()
                                if rules.weekday == day {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(PostageInk.accent)
                                }
                            }
                            .padding(.horizontal, PostageInk.space(2))
                            .frame(maxWidth: .infinity, minHeight: PostageInk.tap)
                            .background(rules.weekday == day ? PostageInk.surface : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(weekdayName(day))
                    }
                }
                HStack {
                    Text("Interval days")
                        .postageText(.label, category: sizeCategory)
                    Spacer()
                    stepButton("−", label: "Shorter interval") {
                        control.regulator.setInterval(rules.intervalDays - 1)
                    }
                    Text(PostageFigures.hours(Double(rules.intervalDays)))
                        .postageText(.figure, category: sizeCategory)
                        .monospacedDigit()
                    stepButton("+", label: "Longer interval") {
                        control.regulator.setInterval(rules.intervalDays + 1)
                    }
                }
                HStack {
                    Text("Monthly impulse limit")
                        .postageText(.label, category: sizeCategory)
                    Spacer()
                    stepButton("−", label: "Lower limit") {
                        bumpLimit(rules, delta: -50)
                    }
                    Text(displayLimit(rules.limitText))
                        .postageText(.figure, category: sizeCategory)
                        .monospacedDigit()
                        .frame(minWidth: 72)
                    stepButton("+", label: "Raise limit") {
                        bumpLimit(rules, delta: 50)
                    }
                }
                PostageFillButton(title: "Lodge rules", enabled: !rules.busy) {
                    Task { try? await control.regulator.lodge() }
                }
            }
            .padding(PostageInk.space(2))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func bumpLimit(_ rules: RegulatorAbstraction, delta: Double) {
        let current = PostageFigures.parseDecimal(rules.limitText) ?? Regulator.defaultLimit
        control.regulator.setLimitText(PostageFigures.decimal(max(1, current + delta)))
    }

    private func displayLimit(_ raw: String) -> String {
        if let value = PostageFigures.parseDecimal(raw) {
            return PostageFigures.money(value)
        }
        return PostageFigures.money(Regulator.defaultLimit)
    }

    private func stepButton(_ title: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PostageInk.font(.label, sizeCategory: sizeCategory))
                .foregroundStyle(PostageInk.ink)
                .frame(minWidth: PostageInk.tap, minHeight: PostageInk.tap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func weekdayName(_ day: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let index = day - 1
        guard symbols.indices.contains(index) else { return PostageFigures.hours(Double(day)) }
        return symbols[index]
    }
}
