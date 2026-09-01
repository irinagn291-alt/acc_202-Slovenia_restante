import SwiftUI

/// Role: Presentation. File-a-want spoke. Forwards fields; never runs the fusee.
struct FilingFace: View {
    let control: FilingControl
    var onClose: () -> Void
    @Environment(\.sizeCategory) private var sizeCategory
    @FocusState private var priceFocused: Bool

    init(control: FilingControl, onClose: @escaping () -> Void = {}) {
        self.control = control
        self.onClose = onClose
    }

    var body: some View {
        let draft = control.abstraction
        SpokeShell(title: "File", onClose: onClose) {
            VStack(alignment: .leading, spacing: PostageInk.space(2)) {
                    if let fault = draft.fault {
                        Text(fault)
                            .postageText(.body, category: sizeCategory)
                            .foregroundStyle(PostageInk.accent)
                    }
                    Text("Title")
                        .postageText(.label, category: sizeCategory)
                    TextField("Held letter", text: Binding(
                        get: { draft.title },
                        set: { control.setTitle($0) }
                    ))
                    .postageText(.body, category: sizeCategory)
                    .padding(PostageInk.space(2))
                    .background(PostageInk.surface)
                    .frame(minHeight: PostageInk.tap)
                    Text("Price")
                        .postageText(.label, category: sizeCategory)
                    TextField(PostageFigures.money(0), text: Binding(
                        get: { draft.priceText },
                        set: { control.setPriceText($0) }
                    ))
                    .keyboardType(.decimalPad)
                    .focused($priceFocused)
                    .postageText(.figure, category: sizeCategory)
                    .monospacedDigit()
                    .padding(PostageInk.space(2))
                    .background(PostageInk.surface)
                    .frame(minHeight: PostageInk.tap)
                    labeledSlider(
                        "Necessity",
                        value: Binding(get: { draft.necessity }, set: { control.setNecessity($0) })
                    )
                    labeledSlider(
                        "Discretion",
                        value: Binding(get: { draft.discretion }, set: { control.setDiscretion($0) })
                    )
                    labeledSlider(
                        "Priority",
                        value: Binding(get: { draft.priority }, set: { control.setPriority($0) }),
                        range: 0.1 ... 2
                    )
                    PostageFillButton(title: "File the want", enabled: !draft.busy) {
                        Task { try? await control.submit() }
                    }
            }
            .padding(PostageInk.space(2))
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { priceFocused = false })
        }
    }

    private func labeledSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double> = 0 ... 100
    ) -> some View {
        VStack(alignment: .leading, spacing: PostageInk.space(1)) {
            HStack {
                Text(title)
                    .postageText(.label, category: sizeCategory)
                Spacer()
                Text(PostageFigures.decimal(value.wrappedValue))
                    .postageText(.figure, category: sizeCategory)
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
                .tint(PostageInk.accent)
                .frame(minHeight: PostageInk.tap)
        }
    }
}
