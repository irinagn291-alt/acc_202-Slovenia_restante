import SwiftUI
import UIKit

/// Role: Presentation. Home wait clock. Forwards input; never computes hours or snaps payday.
struct PendulumFace: View {
    let control: PendulumControl
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(control: PendulumControl = .previewPopulated()) {
        self.control = control
    }

    var body: some View {
        let face = control.abstraction
        GeometryReader { proxy in
            VStack(spacing: PostageInk.space(2)) {
                header
                if face.empty {
                    PostagePlate(
                        image: PostageArt.emptyHome,
                        headline: "File a want",
                        line: "The span starts. Hours snap to the next payday.",
                        actionTitle: "File a want",
                        action: { control.open(.filing) },
                        disabled: face.commitBusy
                    )
                } else {
                    populated(face, in: proxy)
                }
                if let fault = face.fault {
                    faultBanner(fault)
                }
                spokes
            }
            .padding(.horizontal, PostageInk.space(2))
            .padding(.top, PostageInk.space(2))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .overlay { StruckFlash(visible: face.flashSuccess) }
        }
        .background(PostageInk.background.ignoresSafeArea())
    }

    @ViewBuilder
    private func populated(_ face: PendulumAbstraction, in proxy: GeometryProxy) -> some View {
        let wide = proxy.size.width >= 600
        let side = dialSide(in: proxy, wide: wide)
        let dial = TimelineView(.periodic(from: .now, by: reduceMotion ? 60 : 30)) { context in
            WaitDial(
                remainingHours: displayedHours(face: face, now: context.date),
                fraction: face.dialFraction,
                gateOpen: face.gateOpen,
                empty: face.empty,
                busy: face.busy,
                cooling: face.cooling,
                focusID: face.focus?.id,
                size: side
            ) { id in
                control.focus(id)
            }
            .frame(width: side, height: side)
        }
        if wide {
            HStack(alignment: .top, spacing: PostageInk.space(3)) {
                dial
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(spacing: PostageInk.space(2)) {
                    readout(face)
                    actions(face)
                    donorBoard(face)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: PostageInk.space(2)) {
                dial
                readout(face)
                actions(face)
                if !face.gateOpen, !face.donors.isEmpty {
                    Text("\(donorNames(face)) can cover this wait.")
                        .postageText(.body, category: sizeCategory)
                        .foregroundStyle(PostageInk.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func dialSide(in proxy: GeometryProxy, wide: Bool) -> CGFloat {
        let cap: CGFloat = wide ? 560 : 320
        let widthBudget = wide
            ? (proxy.size.width - PostageInk.space(8)) * 0.46
            : proxy.size.width - PostageInk.space(6)
        let heightBudget = proxy.size.height * (wide ? 0.70 : 0.36)
        return min(widthBudget, heightBudget, cap)
    }

    private func displayedHours(face: PendulumAbstraction, now: Date) -> Double {
        guard let unlock = face.focus?.unlockAt else { return face.remainingHours }
        return max(0, (unlock - now.timeIntervalSinceReferenceDate) / 3600)
    }

    private var header: some View {
        HStack(spacing: PostageInk.space(1)) {
            Text("RESTANTE")
                .postageText(.label, category: sizeCategory)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                control.open(.settings)
            } label: {
                Text("Settings")
                    .font(PostageInk.font(.label, sizeCategory: sizeCategory))
                    .foregroundStyle(PostageInk.ink)
                    .frame(minWidth: PostageInk.tap, minHeight: PostageInk.tap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, minHeight: PostageInk.tap)
    }

    @ViewBuilder
    private func readout(_ face: PendulumAbstraction) -> some View {
        if let focus = face.focus {
            VStack(spacing: PostageInk.space(1)) {
                Text(focus.title)
                    .postageText(.headline, category: sizeCategory)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                Text(PostageFigures.money(focus.price))
                    .postageText(.figure, category: sizeCategory)
                    .monospacedDigit()
                Text(face.gateOpen ? "Payday is open. Release this want." : "Cooling until payday")
                    .postageText(.body, category: sizeCategory)
                    .foregroundStyle(PostageInk.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(PostageInk.space(2))
            .frame(maxWidth: .infinity)
            .background { PostageCardWash(opacity: 0.35) }
        }
    }

    @ViewBuilder
    private func actions(_ face: PendulumAbstraction) -> some View {
        if face.gateOpen {
            VStack(spacing: PostageInk.space(1)) {
                PostageFillButton(
                    title: "Bought",
                    enabled: !control.releasing.abstraction.busy
                ) {
                    Task { try? await control.releasing.strike(.bought) }
                }
                PostageQuietButton(
                    title: "Dropped",
                    enabled: !control.releasing.abstraction.busy
                ) {
                    Task { try? await control.releasing.strike(.dropped) }
                }
            }
        } else {
            VStack(spacing: PostageInk.space(1)) {
                PostageFillButton(
                    title: "Sacrifice another want",
                    enabled: !face.donors.isEmpty && !face.commitBusy
                ) {
                    control.open(.remontoire)
                }
                PostageQuietButton(title: "File another want", enabled: !face.commitBusy) {
                    control.open(.filing)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func donorBoard(_ face: PendulumAbstraction) -> some View {
        VStack(alignment: .leading, spacing: PostageInk.space(1)) {
            ForEach(face.donors) { donor in
                Button {
                    control.open(.remontoire)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(donor.title)
                                .postageText(.label, category: sizeCategory)
                                .lineLimit(1)
                            Text("Sacrifice to buy before payday")
                                .postageText(.caption, category: sizeCategory)
                                .foregroundStyle(PostageInk.muted)
                        }
                        Spacer(minLength: PostageInk.space(1))
                        Text(PostageFigures.hours(donor.remainingHours))
                            .postageText(.figure, category: sizeCategory)
                            .monospacedDigit()
                    }
                    .padding(PostageInk.space(2))
                    .frame(maxWidth: .infinity, minHeight: PostageInk.tap, alignment: .leading)
                    .background(PostageInk.surface)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(face.commitBusy)
                .accessibilityLabel("Sacrifice \(donor.title)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func donorNames(_ face: PendulumAbstraction) -> String {
        ListFormatter.localizedString(byJoining: face.donors.map(\.title))
    }

    private var spokes: some View {
        HStack(spacing: 0) {
            spokeButton("This week", spoke: .dispatch)
            spokeButton("Payday", spoke: .payday)
            spokeButton("Rules", spoke: .regulator)
        }
        .frame(maxWidth: .infinity, minHeight: PostageInk.tap)
        .padding(.bottom, PostageInk.space(1))
        .background(PostageInk.background.ignoresSafeArea(edges: .bottom))
    }

    private func spokeButton(_ title: String, spoke: PendulumSpoke) -> some View {
        Button {
            control.open(spoke)
        } label: {
            Text(title)
                .postageText(.label, category: sizeCategory)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: PostageInk.tap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func faultBanner(_ text: String) -> some View {
        VStack(spacing: PostageInk.space(1)) {
            Text(text)
                .postageText(.body, category: sizeCategory)
                .multilineTextAlignment(.center)
            PostageFillButton(title: "Retry") {
                Task { await control.retry() }
            }
        }
        .padding(PostageInk.space(2))
        .frame(maxWidth: .infinity)
        .background(PostageInk.surface)
    }
}

/// Role: Presentation. Canvas wait dial. Remaining hours come from the Abstraction.
struct WaitDial: View {
    var remainingHours: Double
    var fraction: Double
    var gateOpen: Bool
    var empty: Bool
    var busy: Bool
    var cooling: [BarrelStamp]
    var focusID: UUID?
    var size: CGFloat
    var onFocus: (UUID) -> Void
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        Canvas { context, canvasSize in
            let side = min(canvasSize.width, canvasSize.height)
            let rect = CGRect(
                x: (canvasSize.width - side) / 2,
                y: (canvasSize.height - side) / 2,
                width: side,
                height: side
            ).insetBy(dx: 12, dy: 12)
            DateStampRing().path(in: rect).addTo(context, color: PostageInk.ink, width: 2)
            if !empty {
                let sweep = gateOpen ? 1 : min(1, max(0, fraction))
                var arc = Path()
                arc.addArc(
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    radius: rect.width * 0.38,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * sweep),
                    clockwise: false
                )
                context.stroke(arc, with: .color(PostageInk.accent), lineWidth: 6)
            }
        }
        .overlay {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    if busy {
                        Text(" ")
                            .postageText(.clock, category: sizeCategory)
                            .redacted(reason: .placeholder)
                    } else if empty {
                        HeldWindow()
                            .stroke(PostageInk.muted, lineWidth: 1.5)
                            .frame(width: 88, height: 64)
                            .accessibilityHidden(true)
                    } else {
                        Text(PostageFigures.hours(remainingHours))
                            .postageText(.clock, category: sizeCategory)
                            .monospacedDigit()
                        Text("until payday")
                            .postageText(.caption, category: sizeCategory)
                            .foregroundStyle(PostageInk.muted)
                            .offset(y: max(36, side * 0.12))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .allowsHitTesting(false)
            }
        }
        .overlay {
            GeometryReader { geo in
                let reach = min(geo.size.width, geo.size.height) * 0.42
                ZStack {
                    ForEach(Array(cooling.enumerated()), id: \.element.id) { index, stamp in
                        let angle = Angle.degrees(Double(index) / Double(max(cooling.count, 1)) * 360 - 90)
                        Button {
                            onFocus(stamp.id)
                        } label: {
                            Circle()
                                .stroke(stamp.id == focusID ? PostageInk.accent : PostageInk.ink, lineWidth: 2)
                                .frame(width: 16, height: 16)
                                .background(Circle().fill(PostageInk.surface))
                                .frame(width: PostageInk.tap, height: PostageInk.tap)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(stamp.title)
                        .offset(
                            x: cos(angle.radians) * reach,
                            y: sin(angle.radians) * reach
                        )
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(empty ? "Empty wait clock" : "Remaining \(PostageFigures.hours(remainingHours)) hours until payday")
    }
}

private extension Path {
    func addTo(_ context: GraphicsContext, color: Color, width: CGFloat) {
        context.stroke(self, with: .color(color), style: StrokeStyle(lineWidth: width))
    }
}
