import SwiftUI

/// Role: Presentation tokens. Palette and type scale live only here.
enum PostageInk {
    static let background = Color("background")
    static let surface = Color("surface")
    static let ink = Color("ink")
    static let accent = Color("accent")
    static let muted = Color("muted")

    static let unit: CGFloat = 8
    static let tap: CGFloat = 44
    static let motion = Animation.easeInOut(duration: 0.28)

    static func space(_ steps: Int) -> CGFloat {
        unit * CGFloat(steps)
    }

    enum Step: CaseIterable {
        case clock
        case headline
        case label
        case body
        case caption
        case figure

        var size: CGFloat {
            switch self {
            case .clock: return 56
            case .headline: return 28
            case .label: return 15
            case .body: return 17
            case .caption: return 13
            case .figure: return 22
            }
        }

        var style: Font.TextStyle {
            switch self {
            case .clock: return .largeTitle
            case .headline: return .title
            case .label: return .subheadline
            case .body: return .body
            case .caption: return .caption
            case .figure: return .title2
            }
        }
    }

    static func font(_ step: Step, sizeCategory: ContentSizeCategory) -> Font {
        let a11y = sizeCategory >= .accessibilityMedium
        switch step {
        case .clock, .headline:
            if a11y {
                return .system(step.style, design: .serif)
            }
            return .custom("Copperplate-Bold", size: step.size, relativeTo: step.style)
        case .label, .figure:
            if a11y {
                return .system(step.style, design: .serif)
            }
            return .custom("Copperplate", size: step.size, relativeTo: step.style)
        case .body, .caption:
            return .system(step.style, design: .serif)
        }
    }
}

/// Role: Presentation. Locale-aware figures. Round only at display.
enum PostageFigures {
    private static let hours: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    private static let money: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let plain: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    static func hours(_ value: Double) -> String {
        hours.string(from: NSNumber(value: value.rounded())) ?? "—"
    }

    static func money(_ value: Double) -> String {
        money.string(from: NSNumber(value: value)) ?? "—"
    }

    static func decimal(_ value: Double) -> String {
        plain.string(from: NSNumber(value: value)) ?? "—"
    }

    static func parseDecimal(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return plain.number(from: trimmed)?.doubleValue
            ?? hours.number(from: trimmed)?.doubleValue
    }
}

extension View {
    func postageText(_ step: PostageInk.Step, category: ContentSizeCategory) -> some View {
        font(PostageInk.font(step, sizeCategory: category))
            .foregroundStyle(PostageInk.ink)
    }

    func postageTap() -> some View {
        frame(minWidth: PostageInk.tap, minHeight: PostageInk.tap)
        .contentShape(Rectangle())
    }
}
