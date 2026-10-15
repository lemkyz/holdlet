import AppKit
import SwiftUI

struct NativeGlass: NSViewRepresentable {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow; view.state = .active; view.material = .hudWindow
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = .hudWindow
        view.wantsLayer = true
        view.layer?.backgroundColor = reduceTransparency ? NSColor.windowBackgroundColor.cgColor : NSColor.clear.cgColor
    }
}

struct GlassSurface: ViewModifier {
    var radius: CGFloat = 26
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
        content
            .background(NativeGlass())
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(.white.opacity(scheme == .dark ? 0.22 : 0.5), lineWidth: 0.75))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
    }
}
extension View {
    func glassSurface(radius: CGFloat = 26) -> some View { modifier(GlassSurface(radius: radius)) }
}

struct CapsuleAction: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .foregroundStyle(primary ? Color(nsColor: .textBackgroundColor) : .primary)
            .background(primary ? Color.primary.opacity(configuration.isPressed ? 0.7 : 0.95) : Color.primary.opacity(configuration.isPressed ? 0.16 : 0.08))
            .clipShape(Capsule())
    }
}

struct CircleSymbol: View {
    let symbol: String
    var size: CGFloat = 39
    var body: some View {
        Image(systemName: symbol).font(.system(size: size * 0.44, weight: .medium))
            .frame(width: size, height: size)
            .background(Color.primary.opacity(0.09), in: Circle())
            .accessibilityHidden(true)
    }
}
