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

    private var hostVC: UIHostingController<AnimationTimelineRootView>?
    private var displayLink: CADisplayLink?
    private var isPlaying = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        buildHost()
    }

    deinit {
        stopPlayback()
    }

    private func buildHost() {
        let root = AnimationTimelineRootView(
            lanes: lanes,
            currentTime: currentTime,
            sceneDuration: max(sceneDuration, 1),
            fps: fps,
            onScrub: { [weak self] t in
                self?.currentTime = t
                self?.onScrub?(t)
            },
            onPlayPause: { [weak self] in
                self?.togglePlayback()
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
            onScrub: { [weak self] t in
                self?.currentTime = t
                self?.onScrub?(t)
            },
            onPlayPause: { [weak self] in
                self?.togglePlayback()
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

private struct AnimationTimelineRootView: View {
    let lanes: [AnimationTimelineEditorViewController.TrackLane]
    let currentTime: Float
    let sceneDuration: Float
    let fps: Float
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

            VStack(spacing: 10) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 42, height: 5)
                    .padding(.top, 8)

                HStack(spacing: 10) {
                    Button(action: onStepBackward) {
                        Image(systemName: "backward.frame.fill")
                    }
                    Button(action: onPlayPause) {
                        Image(systemName: "playpause.fill")
                    }
                    Button(action: onStepForward) {
                        Image(systemName: "forward.frame.fill")
                    }
                    Text("t: \(String(format: "%.2f", currentTime))s")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Text("\(Int(fps)) fps")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)

                Slider(
                    value: Binding(
                        get: { Double(currentTime) },
                        set: { onScrub(Float($0)) }
                    ),
                    in: 0...Double(max(sceneDuration, 0.001))
                )
                .padding(.horizontal, 14)

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

                Text("Pinch to zoom timeline scale")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
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

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: totalWidth, height: laneHeight)

                Rectangle()
                    .fill(Color.red.opacity(0.75))
                    .frame(width: 2, height: laneHeight)
                    .offset(x: CGFloat(currentTime) * zoom)

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
            .fill(trackColor)
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
            .offset(x: x, y: 8)
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

    private var trackColor: Color {
        switch clip.track {
        case .position, .rotation, .scale: return .blue
        case .fov: return .purple
        case .visibility, .intensity, .color: return .green
        }
    }
}
