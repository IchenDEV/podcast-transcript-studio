import SwiftUI

struct NeutralGlassBackground<S: InsettableShape>: ViewModifier {
    let shape: S
    let material: Material
    let strokeOpacity: Double
    let shadowOpacity: Double

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                shape.fill(material)
                shape.fill(neutralOverlay)
                shape.fill(neutralHighlight)
            }
            .overlay(
                shape.strokeBorder(.white.opacity(colorScheme == .dark ? strokeOpacity * 0.45 : strokeOpacity))
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? shadowOpacity * 1.8 : shadowOpacity), radius: 20, y: 10)
    }

    private var neutralOverlay: Color {
        colorScheme == .dark ? Color.black.opacity(0.18) : Color.white.opacity(0.24)
    }

    private var neutralHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.035 : 0.20),
                Color.white.opacity(0.0),
                Color.black.opacity(colorScheme == .dark ? 0.10 : 0.025),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {
    func neutralGlass<S: InsettableShape>(
        in shape: S,
        material: Material = .regularMaterial,
        strokeOpacity: Double = 0.44,
        shadowOpacity: Double = 0.08
    ) -> some View {
        modifier(
            NeutralGlassBackground(
                shape: shape,
                material: material,
                strokeOpacity: strokeOpacity,
                shadowOpacity: shadowOpacity
            )
        )
    }
}

struct GlassToolbarButtonStyle: ButtonStyle {
    let prominent: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(.primary)
            .padding(.horizontal, prominent ? 14 : 12)
            .frame(height: 38)
            .frame(maxWidth: .infinity)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(buttonTint(isPressed: configuration.isPressed))
            }
            .overlay(alignment: .topLeading) {
                Capsule()
                    .stroke(.white.opacity(colorScheme == .dark ? 0.16 : 0.58), lineWidth: 1)
                    .blur(radius: 0.2)
            }
            .overlay(
                Capsule()
                    .strokeBorder(.separator.opacity(colorScheme == .dark ? 0.25 : 0.18))
            )
            .shadow(color: .black.opacity(prominent ? (colorScheme == .dark ? 0.26 : 0.10) : 0.055), radius: prominent ? 12 : 8, y: 5)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.smooth(duration: 0.16), value: configuration.isPressed)
    }

    private func buttonTint(isPressed: Bool) -> Color {
        if prominent {
            return Color.primary.opacity(isPressed ? (colorScheme == .dark ? 0.20 : 0.13) : (colorScheme == .dark ? 0.15 : 0.09))
        }
        return Color.white.opacity(isPressed ? (colorScheme == .dark ? 0.12 : 0.34) : (colorScheme == .dark ? 0.07 : 0.22))
    }
}

struct GlassIconToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
        }
        .buttonStyle(GlassIconButtonStyle(isSelected: configuration.isOn))
    }
}

struct GlassIconButtonStyle: ButtonStyle {
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .frame(width: 38, height: 38)
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
                Circle()
                    .fill(fillColor(isPressed: configuration.isPressed))
            }
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.13 : 0.48))
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.07), radius: 10, y: 5)
            .opacity(isEnabled ? 1 : 0.42)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.smooth(duration: 0.16), value: configuration.isPressed)
    }

    private func fillColor(isPressed: Bool) -> Color {
        if isSelected {
            return Color.primary.opacity(isPressed ? (colorScheme == .dark ? 0.23 : 0.15) : (colorScheme == .dark ? 0.18 : 0.11))
        }
        return Color.white.opacity(isPressed ? (colorScheme == .dark ? 0.12 : 0.34) : (colorScheme == .dark ? 0.06 : 0.20))
    }
}

struct GlassSidebarButtonStyle: ButtonStyle {
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fillColor(isPressed: configuration.isPressed))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.12 : 0.44))
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.smooth(duration: 0.16), value: configuration.isPressed)
            .animation(.smooth(duration: 0.18), value: isSelected)
    }

    private func fillColor(isPressed: Bool) -> Color {
        if isSelected {
            return Color.primary.opacity(isPressed ? (colorScheme == .dark ? 0.23 : 0.15) : (colorScheme == .dark ? 0.18 : 0.11))
        }
        return Color.white.opacity(isPressed ? (colorScheme == .dark ? 0.12 : 0.34) : (colorScheme == .dark ? 0.05 : 0.17))
    }
}
