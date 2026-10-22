import SwiftUI

/// The full desktop scene: a mahogany desk, an album sleeve leaning at left, and a
/// brushed-metal turntable whose platter spins with the current track. Hosted live in a
/// borderless, click-through window pinned at desktop-icon level — never an app window.
struct DesktopSceneView: View {
    @ObservedObject var poller: NowPlayingPoller
    @ObservedObject var settings: Settings
    let size: CGSize

    /// The two ends of the colour change in flight, and how far along it is.
    @State private var fadeFrom: ScenePalette = .neutral
    @State private var fadeTo: ScenePalette = .neutral
    @State private var fade: Double = 1
    @State private var fadeStarted = Date.distantPast
    @State private var dragOffset: CGSize = .zero

    private var track: Track { poller.track }
    private var palette: ScenePalette { ArtworkPalette.palette(for: track.artwork, id: track.artworkID) }
    private var unit: CGFloat { min(size.width, size.height) }

    // MARK: Layout metrics (ratios traced from the reference turntable)

    private var plinthH: CGFloat { unit * 0.46 }
    private var plinthW: CGFloat { plinthH * 1.32 }
    private var discD: CGFloat { plinthH * 0.86 }
    private var ringD: CGFloat { discD * 1.04 }
    private var labelD: CGFloat { discD * 0.30 }
    private var cardSide: CGFloat { plinthH * 0.88 }
    private var armLen: CGFloat { plinthH * 0.72 }
    private var pivotD: CGFloat { plinthH * 0.105 }
    private var discDX: CGFloat { -plinthW * 0.131 }

    // MARK: - Scene Body

    var body: some View {
        ZStack {
            backdrop
                .allowsHitTesting(false)

            playerWidget
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Player Widget (Vinil + Copertă + Drag & Resize)

    private var playerWidget: some View {
        HStack(spacing: plinthW * 0.01) {
            coverCard
            turntable
        }
        .overlay {
            if settings.isEditMode {
                RoundedRectangle(cornerRadius: unit * 0.02)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, dash: [8, 6]))
                    .padding(-unit * 0.015)
                    .overlay(alignment: .top) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            Text("Drag to move")
                            Button {
                                settings.isEditMode = false
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                            .help("Done editing")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.accentColor))
                        .offset(y: -unit * 0.035)
                    }
            }
        }
        .scaleEffect(settings.scale)
        .offset(x: settings.offsetX + dragOffset.width, y: settings.offsetY + dragOffset.height)
        .gesture(
            settings.isEditMode ?
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        settings.offsetX += value.translation.width
                        settings.offsetY += value.translation.height
                        dragOffset = .zero
                    }
                : nil
        )
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var backdrop: some View {
        switch settings.backdrop {
        case .albumTint: albumTint
        case .mahogany: woodDesk
        }
    }

    /// A flat wash taken from the current cover's background colour: no grain, no figure,
    /// nothing but a soft vertical fall-off, a bloom of the same hue behind the deck, and
    /// the vignette. The turntable is the only detail in the frame, which is the whole
    /// point of the minimal look.
    ///
    /// One wash, whose colour is blended through hue space as `fade` runs — not two
    /// stacked layers dissolving. Stacking and dissolving is the same arithmetic as
    /// interpolating the components, so it would have the identical grey midpoint.
    private var albumTint: some View {
        ZStack {
            wash(ScenePalette.blending(fadeFrom, fadeTo, fade))
            RadialGradient(
                colors: [.clear, .black.opacity(0.38)],
                center: .center, startRadius: unit * 0.34, endRadius: unit * 1.0
            )
        }
        .onAppear {
            fadeFrom = palette
            fadeTo = palette
            fade = 1
        }
        .onChange(of: palette) { _, new in crossFade(to: new) }
    }

    private func wash(_ palette: ScenePalette) -> some View {
        ZStack {
            LinearGradient(
                colors: [palette.top, palette.bottom],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [palette.glow.opacity(0.30), .clear],
                center: UnitPoint(x: 0.5, y: 0.46),
                startRadius: unit * 0.05, endRadius: unit * 0.78
            )
        }
    }

    private static let fadeDuration: TimeInterval = 1.6

    private func crossFade(to new: ScenePalette) {
        guard new != fadeTo else { return }

        let elapsed = Date().timeIntervalSince(fadeStarted)
        let linear = min(1, max(0, elapsed / Self.fadeDuration))
        let eased = linear * linear * (3 - 2 * linear)

        fadeFrom = ScenePalette.blending(fadeFrom, fadeTo, eased)
        fadeTo = new
        fade = 0
        fadeStarted = Date()
        withAnimation(.easeInOut(duration: Self.fadeDuration)) { fade = 1 }
    }

    private var woodDesk: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.42, green: 0.24, blue: 0.16),
                         Color(red: 0.30, green: 0.16, blue: 0.10)],
                startPoint: .top, endPoint: .bottom
            )
            woodDetail
            deskVignette
        }
    }

    private var woodDetail: some View {
        Image(nsImage: SceneTextures.woodDetail(aspect: size.width / max(size.height, 1)))
            .resizable()
            .interpolation(.medium)
    }

    private var deskVignette: some View {
        RadialGradient(
            colors: [.clear, .black.opacity(0.5)],
            center: .center, startRadius: unit * 0.28, endRadius: unit * 0.95
        )
    }

    // MARK: - Album sleeve

    private var coverCard: some View {
        let art = Group {
            if let image = track.artwork {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Color(white: 0.14)
            }
        }
        .frame(width: cardSide, height: cardSide)
        .clipped()

        return art
            .overlay(sleeveOpening)
            .overlay(
                Rectangle().stroke(Color.black.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.65), radius: unit * 0.022, x: -unit * 0.004, y: unit * 0.012)
            .rotationEffect(.degrees(-1.5))
    }

    private var sleeveOpening: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [.clear, .white.opacity(0.16), .white.opacity(0.42)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: cardSide * 0.055)
            .frame(maxWidth: .infinity, alignment: .trailing)

            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: cardSide * 0.11, y: 0))
                p.addLine(to: CGPoint(x: cardSide * 0.11, y: cardSide * 0.11))
                p.closeSubpath()
            }
            .fill(Color.white.opacity(0.30))
            .frame(width: cardSide * 0.11, height: cardSide * 0.11)
        }
    }

    // MARK: - Turntable

    private var turntable: some View {
        plinth
            .frame(width: plinthW, height: plinthH)
            .overlay(platterAssembly.offset(x: discDX))
            .overlay(alignment: .topLeading) { controls }
            .overlay(alignment: .topLeading) { tonearmLayer }
            .shadow(color: .black.opacity(0.55), radius: unit * 0.03, y: unit * 0.02)
    }

    private var plinth: some View {
        let body = RoundedRectangle(cornerRadius: unit * 0.016)
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.90), Color(white: 0.80), Color(white: 0.86), Color(white: 0.76)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )

        return body
            .overlay(brushedTexture)
            .overlay(plinthLip)
            .overlay(
                RoundedRectangle(cornerRadius: unit * 0.016)
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1).padding(0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: unit * 0.016)
                    .strokeBorder(Color.black.opacity(0.22), lineWidth: 1)
            )
    }

    private var brushedTexture: some View {
        Image(nsImage: SceneTextures.brushedMetal(size: CGSize(width: plinthW, height: plinthH)))
            .resizable()
            .clipShape(RoundedRectangle(cornerRadius: unit * 0.016))
    }

    private var plinthLip: some View {
        LinearGradient(colors: [.clear, .black.opacity(0.16)], startPoint: .top, endPoint: .bottom)
            .frame(height: plinthH * 0.07)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .clipShape(RoundedRectangle(cornerRadius: unit * 0.016))
    }

    // MARK: Controls (vents, pitch slider, LED, knob)

    private var controls: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            vents.position(x: plinthW * 0.752, y: plinthH * 0.022)
            pitchSlider.position(x: plinthW * 0.820, y: plinthH * 0.486)
            led.position(x: plinthW * 0.896, y: plinthH * 0.477)
            knob.position(x: plinthW * 0.853, y: plinthH * 0.764)
        }
        .frame(width: plinthW, height: plinthH)
    }

    private var vents: some View {
        HStack(spacing: plinthW * 0.018) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: unit * 0.001)
                    .fill(Color(white: 0.35))
                    .frame(width: plinthW * 0.032, height: plinthH * 0.011)
            }
        }
    }

    private var pitchSlider: some View {
        let track = RoundedRectangle(cornerRadius: plinthW * 0.008)
            .fill(
                LinearGradient(colors: [Color(white: 0.72), Color(white: 0.88)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .frame(width: plinthW * 0.026, height: plinthH * 0.13)
            .overlay(
                RoundedRectangle(cornerRadius: plinthW * 0.008)
                    .stroke(Color.black.opacity(0.18), lineWidth: 0.75)
            )

        let pin = Capsule()
            .fill(Color(white: 0.55))
            .frame(width: plinthW * 0.007, height: plinthH * 0.035)
            .offset(y: -plinthH * 0.028)

        return track.overlay(pin)
    }

    private var led: some View {
        Circle()
            .fill(Color(red: 0.45, green: 0.85, blue: 0.35))
            .frame(width: plinthH * 0.014, height: plinthH * 0.014)
            .shadow(color: Color.green.opacity(0.6), radius: unit * 0.004)
    }

    private var knob: some View {
        let face = Circle()
            .fill(
                RadialGradient(
                    colors: [Color(white: 0.97), Color(white: 0.78)],
                    center: UnitPoint(x: 0.35, y: 0.28), startRadius: 0, endRadius: plinthH * 0.08
                )
            )
            .frame(width: plinthH * 0.115, height: plinthH * 0.115)

        let marker = Capsule()
            .fill(Color(white: 0.45))
            .frame(width: plinthH * 0.006, height: plinthH * 0.032)
            .offset(y: -plinthH * 0.03)

        return face
            .overlay(marker)
            .overlay(Circle().stroke(Color.black.opacity(0.16), lineWidth: 0.75))
            .shadow(color: .black.opacity(0.3), radius: unit * 0.004, y: unit * 0.002)
    }

    // MARK: Platter

    private var platterAssembly: some View {
        ZStack {
            platterRim
            spinningRecord
            staticSheen
        }
        .frame(width: ringD, height: ringD)
    }

    private var platterRim: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.80), Color(white: 0.60), Color(white: 0.74)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .frame(width: ringD, height: ringD)
            .shadow(color: .black.opacity(0.45), radius: unit * 0.012, y: unit * 0.006)
    }

    private var spinningRecord: some View {
        SpinningRecordView(
            image: SceneTextures.record(diameter: discD, artwork: track.artwork, artworkID: track.artworkID),
            isPlaying: track.isPlaying
        )
        .frame(width: discD, height: discD)
        .shadow(color: .black.opacity(0.5), radius: unit * 0.004, y: unit * 0.002)
    }

    private var staticSheen: some View {
        ZStack {
            plasticGloss
            grooveGloss
            rimLight
        }
        .frame(width: discD, height: discD)
        .clipShape(Circle())
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    private var grooveGloss: some View {
        AngularGradient(
            gradient: Gradient(stops: Self.glossStops),
            center: .center,
            angle: .degrees(-118)
        )
        .mask(
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.00),
                    .init(color: .clear, location: 0.31),
                    .init(color: .white.opacity(0.55), location: 0.40),
                    .init(color: .white, location: 0.58),
                    .init(color: .white, location: 0.90),
                    .init(color: .clear, location: 1.00),
                ]),
                center: .center, startRadius: 0, endRadius: discD * 0.5
            )
        )
    }

    private static let glossStops: [Gradient.Stop] = (0...72).map { i in
        let t = Double(i) / 72
        let theta = t * 2.0 * .pi
        let lobe = pow(max(0, cos(theta)), 1.9)
        let facing = 0.38 + 0.62 * cos(theta / 2).magnitude
        return Gradient.Stop(color: .white.opacity(0.40 * lobe * facing), location: t)
    }

    private var plasticGloss: some View {
        LinearGradient(
            colors: [.white.opacity(0.085), .white.opacity(0.02), .clear, .white.opacity(0.035)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var rimLight: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white.opacity(0.00), location: 0.00),
                        .init(color: .white.opacity(0.38), location: 0.09),
                        .init(color: .white.opacity(0.00), location: 0.22),
                        .init(color: .white.opacity(0.00), location: 1.00),
                    ]),
                    center: .center, angle: .degrees(-135)
                ),
                lineWidth: max(1, discD * 0.006)
            )
    }

    // MARK: Tonearm

    private var tonearmLayer: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            armRest.position(x: plinthW * 0.904, y: plinthH * 0.125)
            armGroup.position(x: plinthW * 0.851, y: plinthH * 0.206 + armGroupH / 2)
        }
        .frame(width: plinthW, height: plinthH)
    }

    private var armGroupH: CGFloat { armLen + plinthH * 0.06 }

    private var armGroup: some View {
        ZStack(alignment: .top) {
            armAndHeadshell
                .rotationEffect(.degrees(track.isPlaying ? 43 : 9), anchor: .top)
                .animation(.interpolatingSpring(stiffness: 32, damping: 9), value: track.isPlaying)
            pivotHub.offset(y: -pivotD / 2)
        }
        .frame(width: plinthW * 0.3, height: armGroupH, alignment: .top)
    }

    private var pivotHub: some View {
        let outer = Circle()
            .fill(
                LinearGradient(colors: [Color(white: 0.95), Color(white: 0.62)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(width: pivotD, height: pivotD)

        let inner = Circle()
            .fill(
                LinearGradient(colors: [Color(white: 0.72), Color(white: 0.92)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(width: pivotD * 0.58, height: pivotD * 0.58)

        return outer
            .overlay(Circle().stroke(Color.black.opacity(0.22), lineWidth: 0.75).frame(width: pivotD, height: pivotD))
            .overlay(inner)
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.18), lineWidth: 0.5)
                    .frame(width: pivotD * 0.58, height: pivotD * 0.58)
            )
            .shadow(color: .black.opacity(0.4), radius: unit * 0.004, y: unit * 0.002)
    }

    private var armAndHeadshell: some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(
                    LinearGradient(colors: [Color(white: 0.98), Color(white: 0.62)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: plinthH * 0.016, height: armLen)
                .shadow(color: .black.opacity(0.3), radius: unit * 0.003, y: unit * 0.002)

            headshell.offset(y: armLen - plinthH * 0.02)
        }
    }

    private var headshell: some View {
        let shell = RoundedRectangle(cornerRadius: plinthH * 0.008)
            .fill(
                LinearGradient(colors: [Color(white: 0.88), Color(white: 0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(width: plinthH * 0.05, height: plinthH * 0.085)

        let stylus = Path { p in
            p.move(to: CGPoint(x: plinthH * 0.014, y: 0))
            p.addLine(to: CGPoint(x: 0, y: plinthH * 0.022))
            p.addLine(to: CGPoint(x: plinthH * 0.028, y: plinthH * 0.022))
            p.closeSubpath()
        }
        .fill(Color(red: 0.72, green: 0.14, blue: 0.10))
        .frame(width: plinthH * 0.028, height: plinthH * 0.022)

        return shell
            .overlay(alignment: .bottomLeading) { stylus.offset(x: -plinthH * 0.004, y: plinthH * 0.014) }
            .overlay(RoundedRectangle(cornerRadius: plinthH * 0.008).stroke(Color.black.opacity(0.25), lineWidth: 0.75))
            .rotationEffect(.degrees(-18))
            .shadow(color: .black.opacity(0.35), radius: unit * 0.003, y: unit * 0.002)
    }

    private var armRest: some View {
        let post = Capsule()
            .fill(
                LinearGradient(colors: [Color(white: 0.95), Color(white: 0.6)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .frame(width: plinthH * 0.03, height: plinthH * 0.1)

        let cap = Capsule()
            .fill(Color(white: 0.55))
            .frame(width: plinthH * 0.034, height: plinthH * 0.022)
            .offset(y: -plinthH * 0.036)

        return post
            .overlay(cap)
            .rotationEffect(.degrees(38))
            .shadow(color: .black.opacity(0.35), radius: unit * 0.003, y: unit * 0.002)
    }
}
