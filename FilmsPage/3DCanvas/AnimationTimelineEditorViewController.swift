import SwiftUI
import UIKit

final class AnimationTimelineEditorViewController: UIViewController {

    struct ClipItem: Identifiable {
        let id: UUID
        let entityName: String
        let track: AnimationTrack
        let easing: EasingType
        var startTime: Float
        var duration: Float
        let type: AnimationType
    }

    struct TrackLane: Identifiable {
        let id: String
        let title: String
        var clips: [ClipItem]
    }

    var lanes: [TrackLane] = []
    var sceneDuration: Float = 10
    var currentTime: Float = 0
    var fps: Float = 30

    var onScrub: ((Float) -> Void)?
    var onClipChanged: ((UUID, Float, Float) -> Void)?
    /// Called when the play/pause button in the panel is tapped.
    /// CanvasViewController sets this to toggle its own playback engine.
    var onPlayPause: (() -> Void)?

    private var hostVC: UIHostingController<AnimationTimelineRootView>?
    private var displayLink: CADisplayLink?
    private var isPlaying = false

    // MARK: - Collapse Handle

    /// Width of the visible tab when the panel is fully collapsed.
    private let collapseHandleWidth: CGFloat = 28

    /// Whether the panel is in its collapsed (tab-only) state.
    private(set) var isCollapsed = false

    private lazy var collapseHandle: UIButton = {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        btn.setImage(UIImage(systemName: "chevron.right", withConfiguration: cfg), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor(white: 0.18, alpha: 1)
        btn.layer.cornerRadius = 10
        btn.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(collapseHandleTapped), for: .touchUpInside)
        return btn
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 0.97)

        // Used by RightPanelPresentationController to size the panel
        // (mirrors LightControlPanelViewController's approach).
        preferredContentSize = CGSize(width: 340, height: 620)

        buildHost()
        buildCollapseHandle()
    }

    deinit {
        stopPlayback()
    }

    // MARK: - Collapse Handle Setup

    private func buildCollapseHandle() {
        view.addSubview(collapseHandle)
        NSLayoutConstraint.activate([
            collapseHandle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -collapseHandleWidth),
            collapseHandle.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            collapseHandle.widthAnchor.constraint(equalToConstant: collapseHandleWidth),
            collapseHandle.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    @objc private func collapseHandleTapped() {
        isCollapsed ? expandPanel() : collapsePanel()
    }

    func collapsePanel() {
        guard !isCollapsed else { return }
        isCollapsed = true

        // Compute translation so the panel slides fully off-screen to the right,
        // leaving only the handle tab (collapseHandleWidth) visible at the right edge.
        // view.frame.origin.x is the panel's screen-space left edge (available post-layout).
        // We translate so the panel's leading edge = screenWidth, which places the handle
        // (pinned 28pt to the left of the panel leading) at screenWidth - 28.
        let screenWidth = UIScreen.main.bounds.width
        let originX = view.frame.origin.x > 0 ? view.frame.origin.x : (screenWidth - (view.bounds.width > 0 ? view.bounds.width : 340))
        let translation = screenWidth - originX

        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        collapseHandle.setImage(UIImage(systemName: "chevron.left", withConfiguration: cfg), for: .normal)

        UIViewPropertyAnimator(duration: 0.35, dampingRatio: 0.82) {
            self.view.transform = CGAffineTransform(translationX: translation, y: 0)
        }.startAnimation()
    }

    func expandPanel() {
        guard isCollapsed else { return }
        isCollapsed = false

        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        collapseHandle.setImage(UIImage(systemName: "chevron.right", withConfiguration: cfg), for: .normal)

        UIViewPropertyAnimator(duration: 0.35, dampingRatio: 0.82) {
            self.view.transform = .identity
        }.startAnimation()
    }

    // MARK: - SwiftUI Host

    private func buildHost() {
        let root = AnimationTimelineRootView(
            lanes: lanes,
            currentTime: currentTime,
            sceneDuration: max(sceneDuration, 1),
            fps: fps,
            isPlaying: isPlaying,
            onScrub: { [weak self] t in
                self?.currentTime = t
                self?.onScrub?(t)
            },
            onPlayPause: { [weak self] in
                // Route through the external callback if set (canvas playback engine),
                // otherwise fall back to the internal display link (standalone use).
                if let cb = self?.onPlayPause { cb() } else { self?.togglePlayback() }
            },
            onStepForward: { [weak self] in
                self?.step(by: 1)
            },
            onStepBackward: { [weak self] in
                self?.step(by: -1)
            },
            onClipChanged: { [weak self] id, start, duration in
                self?.onClipChanged?(id, start, duration)
            }
        )

        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        hostVC = host
    }

    private func rebuildRoot() {
        hostVC?.rootView = AnimationTimelineRootView(
            lanes: lanes,
            currentTime: currentTime,
            sceneDuration: max(sceneDuration, 1),
            fps: fps,
            isPlaying: isPlaying,
            onScrub: { [weak self] t in
                self?.currentTime = t
                self?.onScrub?(t)
            },
            onPlayPause: { [weak self] in
                if let cb = self?.onPlayPause { cb() } else { self?.togglePlayback() }
            },
            onStepForward: { [weak self] in
                self?.step(by: 1)
            },
            onStepBackward: { [weak self] in
                self?.step(by: -1)
            },
            onClipChanged: { [weak self] id, start, duration in
                self?.onClipChanged?(id, start, duration)
            }
        )
    }

    func refresh(lanes: [TrackLane], currentTime: Float, sceneDuration: Float) {
        self.lanes = lanes
        self.currentTime = currentTime
        self.sceneDuration = sceneDuration
        rebuildRoot()
    }

    /// Called by CanvasViewController every display-link tick so the scrubber
    /// and play/pause icon stay perfectly in sync with canvas playback.
    /// This is a lightweight update — it does NOT rebuild lanes.
    func updatePlaybackState(time: Float, isPlaying: Bool) {
        self.currentTime = time
        self.isPlaying = isPlaying
        rebuildRoot()
    }

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        guard !isPlaying else { return }
        isPlaying = true
        let link = CADisplayLink(target: self, selector: #selector(playbackTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopPlayback() {
        isPlaying = false
        displayLink?.invalidate()
        displayLink = nil
    }

    private func step(by frameDelta: Int) {
        let frame = 1.0 / max(fps, 1)
        let t = max(0, min(sceneDuration, currentTime + Float(frameDelta) * Float(frame)))
        currentTime = t
        onScrub?(t)
        rebuildRoot()
    }

    @objc private func playbackTick() {
        let frame = 1.0 / max(fps, 1)
        currentTime += Float(frame)
        if currentTime >= sceneDuration {
            currentTime = sceneDuration
            stopPlayback()
        }
        onScrub?(currentTime)
        rebuildRoot()
    }
}

// MARK: - SwiftUI Root View

private struct AnimationTimelineRootView: View {
    let lanes: [AnimationTimelineEditorViewController.TrackLane]
    let currentTime: Float
    let sceneDuration: Float
    let fps: Float
    let isPlaying: Bool
    let onScrub: (Float) -> Void
    let onPlayPause: () -> Void
    let onStepForward: () -> Void
    let onStepBackward: () -> Void
    let onClipChanged: (UUID, Float, Float) -> Void

    @State private var zoom: CGFloat = 110
    private let laneHeight: CGFloat = 52

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Row 1: Time (left) and FPS (right) labels ──────────────────
                HStack {
                    Text(String(format: "%.2f", currentTime) + "s")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text("\(Int(fps)) fps")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.40))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 2)           // tight gap to scrubber

                // ── Row 2: Video-style scrubber ────────────────────────────────
                VideoScrubberView(
                    value: Double(currentTime),
                    range: 0...Double(max(sceneDuration, 0.001)),
                    onScrub: { onScrub(Float($0)) }
                )
                .frame(height: 36)
                .padding(.horizontal, 16)

                // ── Row 3: Playback buttons, centred ──────────────────────────
                HStack(spacing: 32) {
                    // Backward — seeks to start
                    Button(action: onStepBackward) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(minWidth: 36, minHeight: 36)
                            .contentShape(Rectangle())
                    }

                    // Play / Pause — icon switches instantly based on isPlaying
                    Button(action: onPlayPause) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }

                    // Forward — seeks one step forward
                    Button(action: onStepForward) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(minWidth: 36, minHeight: 36)
                            .contentShape(Rectangle())
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)         // tight gap to scrubber above and divider below

                // ── Divider ────────────────────────────────────────────────────
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                // ── Timeline tracks ────────────────────────────────────────────
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 6) {
                        ruler
                        ForEach(lanes) { lane in
                            laneRow(lane: lane)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 20)
                }

                // ── Hint ───────────────────────────────────────────────────────
                Text("Pinch to zoom timeline scale")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.40))
                    .padding(.bottom, 8)
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    zoom = min(260, max(70, zoom * value))
                }
        )
    }

    private var totalWidth: CGFloat {
        CGFloat(max(sceneDuration, 1)) * zoom
    }

    private var ruler: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .frame(width: totalWidth, height: 30)

            HStack(spacing: 0) {
                ForEach(0...Int(ceil(sceneDuration)), id: \.self) { s in
                    VStack(alignment: .leading, spacing: 2) {
                        Rectangle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 1, height: 12)
                        Text("\(s)s")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .frame(width: zoom, alignment: .leading)
                }
            }
        }
    }

    private func laneRow(lane: AnimationTimelineEditorViewController.TrackLane) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lane.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))

            // ZStack with center vertical alignment so clip bars are vertically centred.
            // The red playhead line has been removed — only clip blocks remain.
            ZStack(alignment: Alignment(horizontal: .leading, vertical: .center)) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: totalWidth, height: laneHeight)

                ForEach(lane.clips) { clip in
                    TimelineClipBlock(
                        clip: clip,
                        zoom: zoom,
                        sceneDuration: sceneDuration
                    ) { id, start, duration in
                        onClipChanged(id, start, duration)
                    }
                }
            }
        }
    }
}

// MARK: - Video-style Scrubber

/// A custom scrubber that looks and behaves like a native video player scrubber.
/// - Filled (elapsed) portion: white / light grey
/// - Unfilled (remaining) portion: dark muted
/// - Circular thumb sits on top at the current position
/// - Drag fires `onScrub` continuously — works during playback or while paused
private struct VideoScrubberView: View {
    let value: Double
    let range: ClosedRange<Double>
    let onScrub: (Double) -> Void

    // Track geometry constants
    private let trackHeight: CGFloat = 3
    private let thumbDiameter: CGFloat = 14
    private let hitTargetPadding: CGFloat = 16   // expands vertical hit area

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let progress = clampedProgress(trackWidth: trackWidth)
            let filledWidth = trackWidth * progress

            ZStack(alignment: .leading) {

                // ── Unfilled (remaining) track ─────────────────────────────────
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.white.opacity(0.20))
                    .frame(width: trackWidth, height: trackHeight)
                    .frame(maxHeight: .infinity)

                // ── Filled (elapsed) track ─────────────────────────────────────
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.white.opacity(0.85))
                    .frame(width: max(0, filledWidth), height: trackHeight)
                    .frame(maxHeight: .infinity, alignment: .leading)

                // ── Thumb circle ───────────────────────────────────────────────
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                    .frame(maxHeight: .infinity)
                    .offset(x: max(0, filledWidth - thumbDiameter / 2))
            }
            // Expand the vertical hit area without changing visual size
            .contentShape(Rectangle().inset(by: -hitTargetPadding))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let raw = drag.location.x / trackWidth
                        let clamped = min(1, max(0, raw))
                        let t = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                        onScrub(t)
                    }
            )
        }
    }

    private func clampedProgress(trackWidth: CGFloat) -> CGFloat {
        guard range.upperBound > range.lowerBound, trackWidth > 0 else { return 0 }
        let span = range.upperBound - range.lowerBound
        let raw = (value - range.lowerBound) / span
        return CGFloat(min(1, max(0, raw)))
    }
}

// MARK: - Timeline Clip Block

private struct TimelineClipBlock: View {
    let clip: AnimationTimelineEditorViewController.ClipItem
    let zoom: CGFloat
    let sceneDuration: Float
    let onCommit: (UUID, Float, Float) -> Void

    @State private var dragStart: Float?

    var body: some View {
        let x = CGFloat(max(0, clip.startTime)) * zoom
        let w = CGFloat(max(0.08, clip.duration)) * zoom
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(UIColor.systemGray3))
            .overlay(
                HStack(spacing: 6) {
                    Text(shortTrack)
                        .font(.system(size: 10, weight: .bold))
                    Text(String(format: "%.1fs", clip.duration))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8),
                alignment: .leading
            )
            .frame(width: max(42, w), height: 36)
            .offset(x: x)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStart == nil { dragStart = clip.startTime }
                        guard let initial = dragStart else { return }
                        let deltaSec = Float(value.translation.width / zoom)
                        let newStart = max(0, min(sceneDuration, initial + deltaSec))
                        onCommit(clip.id, newStart, clip.duration)
                    }
                    .onEnded { _ in
                        dragStart = nil
                    }
            )
    }

    private var shortTrack: String {
        switch clip.track {
        case .position: return "POS"
        case .rotation: return "ROT"
        case .scale: return "SCL"
        case .fov: return "FOV"
        case .visibility: return "VIS"
        case .intensity: return "INT"
        case .color: return "COL"
        }
    }
}
