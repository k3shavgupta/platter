import SwiftUI
import AppKit

struct ControlPanelView: View {
    @ObservedObject var settings: Settings
    @State var showOnDesktop: Bool
    @State var launchAtLogin: Bool

    var onToggleDesktop: (Bool) -> Void
    var onToggleLogin: (Bool) -> Void
    var onQuit: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header

                Divider().padding(.vertical, 12)

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
                .padding(.top, 12)

                Text(backdropDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Divider().padding(.vertical, 12)

                // MARK: - Widget Position & Scaling
                Group {
                    Toggle("Unlock & Drag on desktop", isOn: $settings.isEditMode)

                    Text("Enables dragging the player directly with your mouse on screen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Size:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(settings.scale * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.scale, in: 0.35...1.75, step: 0.05)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Presets:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            Button("Center") {
                                withAnimation(.spring) {
                                    settings.offsetX = 0
                                    settings.offsetY = 0
                                }
                            }
                            Button("Bottom-R") {
                                withAnimation(.spring) {
                                    settings.offsetX = 340
                                    settings.offsetY = 190
                                }
                            }
                            Button("Bottom-L") {
                                withAnimation(.spring) {
                                    settings.offsetX = -340
                                    settings.offsetY = 190
                                }
                            }
                            Button("Reset") {
                                withAnimation(.spring) {
                                    settings.scale = 1.0
                                    settings.offsetX = 0
                                    settings.offsetY = 0
                                }
                            }
                        }
                        .controlSize(.small)
                    }
                    .padding(.top, 6)
                }

                Divider().padding(.vertical, 12)

                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in onToggleLogin(value) }

                Text("Platter reads the current track from Spotify or Music. No login needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                Spacer(minLength: 16)

                HStack {
                    Spacer()
                    Button("Quit Platter", role: .destructive, action: onQuit)
                        .keyboardShortcut("q")
                }
            }
            .padding(20)
        }
        .toggleStyle(.switch)
        .frame(width: 340, height: 460)
        .background(WindowLevelAccessor(level: .floating + 1))
    }

    private var backdropDescription: String {
        switch settings.backdrop {
        case .albumTint:
            return "Album colour tints the desktop with the current cover's background."
        case .mahogany:
            return "Draws the classic mahogany wood desk."
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

// MARK: - Window Level Accessor

struct WindowLevelAccessor: NSViewRepresentable {
    let level: NSWindow.Level

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.level = level
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.level = level
        }
    }
}
