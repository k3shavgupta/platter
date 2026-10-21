import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Settings surface for the app.
struct ControlPanelView: View {
    @ObservedObject var settings: Settings
    @State var showOnDesktop: Bool
    @State var launchAtLogin: Bool

    var onToggleDesktop: (Bool) -> Void
    var onToggleLogin: (Bool) -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider().padding(.vertical, 14)

            Toggle("Show on desktop", isOn: $showOnDesktop)
                .onChange(of: showOnDesktop) { _, value in onToggleDesktop(value) }

            Text("Draws the turntable behind your desktop icons.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Picker("Background", selection: $settings.backdrop) {
                ForEach(BackdropStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }
            .padding(.top, 14)

            // Controale dinamice în funcție de fundalul ales
            if settings.backdrop == .customColor {
                HStack {
                    Text("Select colour:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    ColorPicker("", selection: $settings.customColor, supportsOpacity: false)
                        .labelsHidden()
                }
                .padding(.top, 6)
            } else if settings.backdrop == .customImage {
                HStack(spacing: 8) {
                    Button("Choose Image...") {
                        selectImage()
                    }
                    .font(.caption)

                    if let path = settings.customImagePath {
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(.top, 6)
            }

            Text(backdropDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, value in onToggleLogin(value) }
                .padding(.top, 12)

            Text("Platter reads the current track from Spotify or Music. No login needed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Spacer(minLength: 18)

            HStack {
                Spacer()
                Button("Quit Platter", role: .destructive, action: onQuit)
                    .keyboardShortcut("q")
            }
        }
        .toggleStyle(.switch)
        .padding(22)
        .frame(width: 340, height: 360)
    }

    private var backdropDescription: String {
        switch settings.backdrop {
        case .albumTint:
            return "Album colour tints the desktop with the current cover's background."
        case .mahogany:
            return "Draws the classic mahogany wood desk."
        case .transparent:
            return "Transparent — keeps your native desktop wallpaper visible."
        case .customColor:
            return "Draws a solid background in your chosen color."
        case .customImage:
            return "Draws your chosen wallpaper image behind the vinyl."
        case .waves:
            return "Renders smooth, fluid animated waves tinted with the current album palette."
        }
    }

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.title = "Select Wallpaper Image"
        panel.prompt = "Choose"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.customImagePath = url.path
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "opticaldisc.fill")
                .font(.system(size: 30))
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Platter").font(.title2.weight(.semibold))
                Text(versionString).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }
}
