import Combine
import Foundation

enum BackdropStyle: String, CaseIterable, Identifiable {
    case albumTint
    case mahogany

    var id: String { rawValue }

    var label: String {
        switch self {
        case .albumTint: return "Album colour"
        case .mahogany: return "Mahogany desk"
        }
    }
}

final class Settings: ObservableObject {
    private static let backdropKey = "backdropStyle"
    private static let scaleKey = "sceneScale"
    private static let offsetXKey = "sceneOffsetX"
    private static let offsetYKey = "sceneOffsetY"

    @Published var backdrop: BackdropStyle {
        didSet {
            guard backdrop != oldValue else { return }
            UserDefaults.standard.set(backdrop.rawValue, forKey: Self.backdropKey)
        }
    }

    @Published var scale: Double {
        didSet {
            UserDefaults.standard.set(scale, forKey: Self.scaleKey)
        }
    }

    @Published var offsetX: Double {
        didSet {
            UserDefaults.standard.set(offsetX, forKey: Self.offsetXKey)
        }
    }

    @Published var offsetY: Double {
        didSet {
            UserDefaults.standard.set(offsetY, forKey: Self.offsetYKey)
        }
    }

    @Published var isEditMode: Bool = false

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.backdropKey)
        backdrop = stored.flatMap(BackdropStyle.init(rawValue:)) ?? .albumTint

        let storedScale = UserDefaults.standard.double(forKey: Self.scaleKey)
        scale = storedScale > 0 ? storedScale : 1.0

        offsetX = UserDefaults.standard.double(forKey: Self.offsetXKey)
        offsetY = UserDefaults.standard.double(forKey: Self.offsetYKey)
    }
}
