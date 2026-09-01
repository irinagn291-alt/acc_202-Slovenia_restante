import SwiftUI
import UIKit

/// Role: Presentation. Asset or a drawn stamp — never an unframed missing Image.
struct PostageMark: View {
    var name: String
    var maxWidth: CGFloat = 220
    var maxHeight: CGFloat = 180
    var fallback: Kind = .ring

    enum Kind {
        case ring
        case bars
        case window
    }

    var body: some View {
        Group {
            if UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .scaledToFit()
            } else {
                fallbackShape
            }
        }
        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var fallbackShape: some View {
        switch fallback {
        case .ring:
            DateStampRing().stroke(PostageInk.ink, lineWidth: 2)
        case .bars:
            KillerBars(waves: 3).stroke(PostageInk.muted, lineWidth: 1.2)
        case .window:
            HeldWindow().stroke(PostageInk.ink, lineWidth: 1.5)
        }
    }
}

/// Role: Presentation. Card wash — skip the asset when UIImage(named:) is nil.
struct PostageCardWash: View {
    var opacity: Double = 0.28

    var body: some View {
        ZStack {
            PostageInk.surface
            if UIImage(named: PostageArt.card) != nil {
                Image(PostageArt.card)
                    .resizable()
                    .scaledToFill()
                    .opacity(opacity)
                    .clipped()
                    .accessibilityHidden(true)
            }
        }
    }
}

/// Role: Presentation. In-content spoke chrome. No NavigationStack.
struct SpokeShell<Content: View>: View {
    var title: String
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        VStack(spacing: 0) {
            header
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PostageInk.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button(action: onClose) {
                HStack(spacing: PostageInk.space(1)) {
                    Image(systemName: "xmark")
                    Text(title)
                        .lineLimit(1)
                }
                .font(PostageInk.font(.label, sizeCategory: sizeCategory))
                .foregroundStyle(PostageInk.ink)
                .padding(.horizontal, PostageInk.space(2))
                .frame(minHeight: PostageInk.tap)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: PostageInk.tap, alignment: .leading)
        .background(PostageInk.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PostageInk.ink.opacity(0.12))
                .frame(height: 1)
        }
    }
}

/// Role: Presentation. Primary filled CTA — chrome lives inside the label.
struct PostageFillButton: View {
    var title: String
    var enabled: Bool = true
    var action: () -> Void
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PostageInk.font(.label, sizeCategory: sizeCategory))
                .foregroundStyle(enabled ? Color(red: 0.97, green: 0.93, blue: 0.88) : PostageInk.muted)
                .frame(maxWidth: .infinity, minHeight: PostageInk.tap)
                .background(enabled ? PostageInk.accent : PostageInk.surface)
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .frame(maxWidth: .infinity)
    }
}

/// Role: Presentation. Non-interactive wait mark. Never Button.disabled (no fade).
struct PostageIdleCapsule: View {
    var title: String
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        Text(title)
            .font(PostageInk.font(.label, sizeCategory: sizeCategory))
            .foregroundStyle(PostageInk.ink.opacity(0.85))
            .frame(maxWidth: .infinity, minHeight: PostageInk.tap)
            .background(PostageInk.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(PostageInk.ink, lineWidth: 1.5))
            .contentShape(Capsule())
            .accessibilityLabel("Wait for payday")
    }
}

/// Role: Presentation. Secondary / disabled chip — full-width capsule.
struct PostageQuietButton: View {
    var title: String
    var enabled: Bool = true
    var action: () -> Void
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PostageInk.font(.label, sizeCategory: sizeCategory))
                .foregroundStyle(PostageInk.ink.opacity(0.7))
                .frame(maxWidth: .infinity, minHeight: PostageInk.tap)
                .background(PostageInk.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(PostageInk.ink.opacity(0.55), lineWidth: 1.5))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .frame(maxWidth: .infinity)
    }
}

/// Role: Presentation. Empty plate — generated art, one headline, one line, one CTA.
struct PostagePlate: View {
    var image: String
    var headline: String
    var line: String
    var actionTitle: String
    var action: () -> Void
    var disabled: Bool = false
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        VStack(spacing: PostageInk.space(2)) {
            Spacer(minLength: 0)
            PostageMark(name: image, maxHeight: 180, fallback: .window)
            Text(headline)
                .postageText(.headline, category: sizeCategory)
                .multilineTextAlignment(.center)
            Text(line)
                .postageText(.body, category: sizeCategory)
                .foregroundStyle(PostageInk.muted)
                .multilineTextAlignment(.center)
            PostageFillButton(title: actionTitle, enabled: !disabled, action: action)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(PostageInk.space(2))
    }
}

/// Role: Presentation. Brief success cancellation after a commit.
struct StruckFlash: View {
    var visible: Bool

    var body: some View {
        Group {
            if UIImage(named: PostageArt.success) != nil {
                Image(PostageArt.success)
                    .resizable()
                    .scaledToFit()
            } else {
                DateStampRing()
                    .stroke(PostageInk.accent, lineWidth: 4)
            }
        }
        .frame(width: 128, height: 128)
        .opacity(visible ? 1 : 0)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

enum PostageArt {
    static let emptyHome = "rst_EmptyHome"
    static let emptyList = "rst_EmptyList"
    static let card = "rst_CardBackdrop"
    static let control = "rst_ControlFace"
    static let twist = "rst_TwistHero"
    static let success = "rst_SuccessMark"
    static let header = "rst_HeaderDecor"
    static let splash = "rst_Splash"

    static func onboarding(_ page: Int) -> String {
        switch page {
        case 0: return "rst_Onboarding1"
        case 1: return "rst_Onboarding2"
        default: return "rst_Onboarding3"
        }
    }
}
