import SwiftUI

/// Role: Presentation. Review spoke — released, sacrificed, still cooling.
struct DispatchScreen: View {
    let control: PendulumControl
    @Environment(\.sizeCategory) private var sizeCategory

    init(control: PendulumControl = .previewPopulated()) {
        self.control = control
    }

    var body: some View {
        let book = control.reviewing.abstraction
        SpokeShell(title: "Dispatch", onClose: control.dismissSpoke) {
            VStack(alignment: .leading, spacing: PostageInk.space(2)) {
                if let fault = book.fault ?? control.abstraction.fault {
                    Text(fault)
                        .postageText(.body, category: sizeCategory)
                    PostageFillButton(title: "Retry") {
                        Task { await control.reviewing.retry() }
                    }
                } else if book.empty {
                    Text("Nothing struck")
                        .postageText(.headline, category: sizeCategory)
                    Text("Released, sacrificed and cooling wants collect here.")
                        .postageText(.body, category: sizeCategory)
                        .foregroundStyle(PostageInk.muted)
                    PostageFillButton(title: "File a want") {
                        control.open(.filing)
                    }
                } else {
                    lane("Bought", rows: book.bought)
                    lane("Dropped", rows: book.dropped)
                    lane("Sacrificed", rows: book.sacrificed)
                    lane("Still cooling", rows: book.cooling)
                }
            }
            .padding(PostageInk.space(2))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func lane(_ title: String, rows: [BarrelStamp]) -> some View {
        VStack(alignment: .leading, spacing: PostageInk.space(1)) {
            Text(title)
                .postageText(.label, category: sizeCategory)
                .foregroundStyle(PostageInk.muted)
            if rows.isEmpty {
                Text("—")
                    .postageText(.body, category: sizeCategory)
                    .foregroundStyle(PostageInk.muted)
            } else {
                ForEach(rows) { row in
                    HStack {
                        Text(row.title)
                            .postageText(.body, category: sizeCategory)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: PostageInk.space(1))
                        Text(PostageFigures.money(row.price))
                            .postageText(.figure, category: sizeCategory)
                            .monospacedDigit()
                    }
                    .padding(.vertical, PostageInk.space(1))
                }
            }
        }
        .padding(PostageInk.space(2))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PostageInk.surface)
    }
}
