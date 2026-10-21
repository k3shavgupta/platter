import Combine
import Foundation
import SwiftUI
import AppKit

enum BackdropStyle: String, CaseIterable, Identifiable {
    /// A flat wash tinted from the current cover's background colour.
    case albumTint
    /// The original mahogany desk.
    case mahogany
    /// Desktop-level transparency (shows your native macOS wallpaper).
    case transparent
    /// A solid custom color chosen by the user.
    case customColor
    /// A custom image/wallpaper from disk.
    case customImage
    
    case waves

    var id: String { rawValue }

    var label: String {
        switch self {
        case .albumTint: return "Album colour"
        case .mahogany: return "Mahogany desk"
        case .transparent: return "None (Transparent)"
        case .customColor: return "Custom colour"
        case .customImage: return "Custom image"
        case .waves: return "Animated waves"
        }
    }
}

/// The user choices the scene reads.
final class Settings: ObservableObject {
    private static let backdropKey = "backdropStyle"
    private static let customColorRKey = "customColor_r"
    private static let customColorGKey = "customColor_g"
    private static let customColorBKey = "customColor_b"
    private static let customImagePathKey = "customImagePath"

    @Published var backdrop: BackdropStyle {
        didSet {
            guard backdrop != oldValue else { return }
            UserDefaults.standard.set(backdrop.rawValue, forKey: Self.backdropKey)
        }
    }

    @Published var customColor: Color {
        didSet {
            if #available(macOS 14.0, *) {
                let resolved = customColor.resolve(in: EnvironmentValues())
                UserDefaults.standard.set(Double(resolved.red), forKey: Self.customColorRKey)
                UserDefaults.standard.set(Double(resolved.green), forKey: Self.customColorGKey)
                UserDefaults.standard.set(Double(resolved.blue), forKey: Self.customColorBKey)
            }
        }
    }

    @Published var customImagePath: String? {
        didSet {
            UserDefaults.standard.set(customImagePath, forKey: Self.customImagePathKey)
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.backdropKey)
        backdrop = stored.flatMap(BackdropStyle.init(rawValue:)) ?? .albumTint

        let r = UserDefaults.standard.object(forKey: Self.customColorRKey) as? Double ?? 0.18
        let g = UserDefaults.standard.object(forKey: Self.customColorGKey) as? Double ?? 0.18
        let b = UserDefaults.standard.object(forKey: Self.customColorBKey) as? Double ?? 0.20
        customColor = Color(red: r, green: g, blue: b)

        customImagePath = UserDefaults.standard.string(forKey: Self.customImagePathKey)
    }
}
