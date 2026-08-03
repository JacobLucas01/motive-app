import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum MotiveTheme {
    static let background = Color(red: 0.03, green: 0.035, blue: 0.04)
    static let surface = Color(red: 0.075, green: 0.08, blue: 0.09)
    static let elevatedSurface = Color(red: 0.105, green: 0.115, blue: 0.13)
    static let primaryText = Color(red: 0.94, green: 0.96, blue: 0.95)
    static let secondaryText = Color(red: 0.60, green: 0.64, blue: 0.66)
    static let accent = Color(red: 0.55, green: 0.94, blue: 0.72)
    static let accentMuted = Color(red: 0.16, green: 0.28, blue: 0.21)
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.38)
    static let border = Color.white.opacity(0.10)

    static let pagePadding: CGFloat = 22
    static let controlHeight: CGFloat = 52
    static let radius: CGFloat = 14
}

struct MotivePrimaryButton: View {
    let title: String
    let systemImage: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: MotiveTheme.controlHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MotiveTheme.background)
        .background(isDisabled ? MotiveTheme.secondaryText : MotiveTheme.accent)
        .clipShape(Capsule(style: .continuous))
        .motiveCapsuleGlass(tint: isDisabled ? MotiveTheme.secondaryText : MotiveTheme.accent)
        .disabled(isDisabled)
    }
}

struct MotiveSecondaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: MotiveTheme.controlHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MotiveTheme.primaryText)
        .background(MotiveTheme.elevatedSurface)
        .overlay(
            Capsule(style: .continuous)
                .stroke(MotiveTheme.border, lineWidth: 1)
        )
        .clipShape(Capsule(style: .continuous))
        .motiveCapsuleGlass(tint: MotiveTheme.elevatedSurface)
    }
}

struct MotiveChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundStyle(isSelected ? MotiveTheme.background : MotiveTheme.primaryText)
                .padding(.horizontal, 14)
                .frame(height: 38)
        }
        .buttonStyle(.plain)
        .background(isSelected ? MotiveTheme.accent : MotiveTheme.elevatedSurface)
        .overlay(
            RoundedRectangle(cornerRadius: MotiveTheme.radius, style: .continuous)
                .stroke(isSelected ? Color.clear : MotiveTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: MotiveTheme.radius, style: .continuous))
        .motiveGlass(tint: isSelected ? MotiveTheme.accent : MotiveTheme.elevatedSurface)
    }
}

struct MotiveFlowLayout: Layout {
    var spacing: CGFloat = 10
    var rowSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedWidth = currentRowWidth == 0 ? size.width : currentRowWidth + spacing + size.width

            if maxWidth > 0 && proposedWidth > maxWidth {
                totalHeight += currentRowHeight + rowSpacing
                widestRow = max(widestRow, currentRowWidth)
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                currentRowWidth = proposedWidth
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        totalHeight += currentRowHeight
        widestRow = max(widestRow, currentRowWidth)
        return CGSize(width: maxWidth > 0 ? maxWidth : widestRow, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + rowSpacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct MotiveFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(MotiveTheme.primaryText)
            .foregroundColor(MotiveTheme.primaryText)
            .tint(MotiveTheme.accent)
            .padding(14)
            .background(MotiveTheme.elevatedSurface)
            .overlay(
                RoundedRectangle(cornerRadius: MotiveTheme.radius, style: .continuous)
                    .stroke(MotiveTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: MotiveTheme.radius, style: .continuous))
    }
}

extension View {
    func motiveField() -> some View {
        modifier(MotiveFieldStyle())
    }

    func motiveScreen() -> some View {
        background(MotiveTheme.background.ignoresSafeArea())
            .foregroundStyle(MotiveTheme.primaryText)
    }

    @ViewBuilder
    func motiveGlass(cornerRadius: CGFloat = MotiveTheme.radius, tint: Color? = nil, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                if interactive {
                    glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
                } else {
                    glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
                }
            } else if interactive {
                glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func motiveCapsuleGlass(tint: Color? = nil, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                if interactive {
                    glassEffect(.regular.tint(tint).interactive(), in: Capsule(style: .continuous))
                } else {
                    glassEffect(.regular.tint(tint), in: Capsule(style: .continuous))
                }
            } else if interactive {
                glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
            } else {
                glassEffect(.regular, in: Capsule(style: .continuous))
            }
        } else {
            self
        }
    }

    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                #if canImport(UIKit)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                #endif
            }
        )
    }
}
