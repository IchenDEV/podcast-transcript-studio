import AppKit
import SwiftUI
import PodcastTranscriptStudioCore

enum AppIconPreference: String, CaseIterable, Identifiable {
    case system
    case black
    case white

    static let storageKey = "PodcastTranscriptStudio.AppIconPreference"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            "默认"
        case .black:
            "黑色"
        case .white:
            "白色"
        }
    }

    var detail: String {
        switch self {
        case .system:
            "与应用启动图标保持一致"
        case .black:
            "始终显示黑色图标"
        case .white:
            "始终显示白色图标"
        }
    }

    var systemImage: String {
        switch self {
        case .system:
            "circle.lefthalf.filled"
        case .black:
            "moon.fill"
        case .white:
            "sun.max.fill"
        }
    }

    func resolvedVariant(for _: ColorScheme) -> AppIconVariant {
        switch self {
        case .system:
            .white
        case .black:
            .black
        case .white:
            .white
        }
    }
}

enum AppIconVariant {
    case black
    case white

    var fileName: String {
        switch self {
        case .black:
            "AppIconDark.png"
        case .white:
            "AppIconLight.png"
        }
    }
}

@MainActor
enum AppIconController {
    static func imageURL(for variant: AppIconVariant, configuration: AppConfiguration) -> URL {
        configuration.bundledResourcesDirectory
            .appendingPathComponent("AppIcons", isDirectory: true)
            .appendingPathComponent(variant.fileName)
    }

    static func apply(
        preferenceRawValue: String,
        colorScheme: ColorScheme,
        configuration: AppConfiguration
    ) {
        let preference = AppIconPreference(rawValue: preferenceRawValue) ?? .system
        let variant = preference.resolvedVariant(for: colorScheme)
        let url = imageURL(for: variant, configuration: configuration)
        guard let image = NSImage(contentsOf: url) else { return }
        image.size = NSSize(width: 1024, height: 1024)
        image.isTemplate = false
        NSApplication.shared.applicationIconImage = image
    }
}

struct AppIconApplier: ViewModifier {
    let preferenceRawValue: String
    let configuration: AppConfiguration

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .onAppear(perform: applyIcon)
            .onChange(of: preferenceRawValue) { _, _ in applyIcon() }
            .onChange(of: colorScheme) { _, _ in applyIcon() }
            .onChange(of: configuration) { _, _ in applyIcon() }
    }

    private func applyIcon() {
        AppIconController.apply(
            preferenceRawValue: preferenceRawValue,
            colorScheme: colorScheme,
            configuration: configuration
        )
    }
}

struct AppIconPreviewImage: View {
    let variant: AppIconVariant
    let configuration: AppConfiguration

    var body: some View {
        if let image = NSImage(contentsOf: AppIconController.imageURL(for: variant, configuration: configuration)) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary)
        }
    }
}
