import RealityKit
import UIKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Shot Type Enums
// ─────────────────────────────────────────────────────────────────────────────

enum CameraMovementPreset: String, CaseIterable {
    case pan      = "Pan"
    case tilt     = "Tilt"
    case dollyIn  = "Dolly-in"
    case dollyOut = "Dolly-out"
    case crane    = "Crane/Boom"

    var description: String {
        switch self {
        case .pan:      return "Camera rotates left/right from a fixed position."
        case .tilt:     return "Camera tilts up/down from a fixed position."
        case .dollyIn:  return "Camera physically moves closer to the subject."
        case .dollyOut: return "Camera physically moves away from the subject."
        case .crane:    return "Camera moves up with a slight forward arc."
        }
    }
    var imageName: String {
        switch self {
        case .pan:      return "Pan"
        case .tilt:     return "Tilt"
        case .dollyIn:  return "Dolly-in"
        case .dollyOut: return "Dolly-out"
        case .crane:    return "Crane"
        }
    }
    var fallbackSFSymbol: String {
        switch self {
        case .pan:      return "arrow.left.and.right"
        case .tilt:     return "arrow.up.and.down"
        case .dollyIn:  return "arrow.down.forward"
        case .dollyOut: return "arrow.up.backward"
        case .crane:    return "arrow.up.right"
        }
    }
}

enum StaticShotPreset: String, CaseIterable {
    case establishing = "Establishing Shot"
    case Zoomin         = "Zoom-in Shot"
    case Zoomout       = "Zoom-out Shot"
//    case closeUp      = "Close-up"
//    case insert       = "Insert/Cutaway"

    var description: String {
        switch self {
        case .establishing: return "Sets up location and context."
        case .Zoomin:         return "Moves closer to subject."
        case .Zoomout:       return "Moves away from subject."
//        case .closeUp:      return "Tight shot on face or detail."
//        case .insert:       return "Cut to a supporting detail."
        }
    }
    var imageName: String {
        switch self {
        case .establishing: return "Establishing Shot"
        case .Zoomin:         return "Zoom-in Shot"
        case .Zoomout:       return "Zoom-out Shot"
//        case .closeUp:      return "shot_closeup"
//        case .insert:       return "shot_insert"
        }
    }
    var fallbackSFSymbol: String {
        switch self {
        case .establishing: return "mappin.and.ellipse"
        case .Zoomin:         return "rectangle.expand.vertical"
        case .Zoomout:       return "person.crop.rectangle"
//        case .closeUp:      return "magnifyingglass"
//        case .insert:       return "scissors"
        }
    }
}

enum ShotSelection {
    case movement(CameraMovementPreset)
    case static_(StaticShotPreset)
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - CanvasViewController: Entry Points
// ─────────────────────────────────────────────────────────────────────────────

extension CanvasViewController {

    // Called from showActionMenu .addShot
    func presentShotPicker(for cameraEntity: Entity) {
        let vc = ShotPickerViewController(cameraEntity: cameraEntity) { [weak self] selection in
            self?.presentShotSettings(selection: selection, cameraEntity: cameraEntity)
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let pc = nav.sheetPresentationController {
            pc.detents = [.large()]
            pc.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    // Legacy entry point kept for existing call sites
    func presentCameraMovementPicker(for cameraEntity: Entity) {
        presentShotPicker(for: cameraEntity)
    }

    // ── Shot Settings presented after picking a shot ──────────────────────────
    func presentShotSettings(selection: ShotSelection, cameraEntity: Entity) {

        let isRotation: Bool
        var presetAxis    = RotationAxis.y
        var presetDegrees: Float = 60

        if case .movement(let p) = selection {
            switch p {
            case .pan:
                isRotation    = true
                presetAxis    = .y
                presetDegrees = 60
            case .tilt:
                isRotation    = true
                presetAxis    = .x
                presetDegrees = -40
            default:
                isRotation = false
            }
        } else {
            isRotation = false
        }

        let shotName: String
        switch selection {
        case .movement(let p): shotName = p.rawValue
        case .static_(let p):  shotName = p.rawValue
        }

        let card: AnimationInputCard

        if isRotation {
            card = AnimationInputCard(mode: .editRotateFull(
                currentStart:    timeline.duration,
                currentDuration: 3.0,
                currentDegrees:  presetDegrees,
                currentAxis:     presetAxis
            ))
            card.onConfirm = { [weak self] startTime, duration, degrees, axis in
                guard let self, duration > 0 else { return }
                self.applyCameraRotationShot(
                    selection:    selection,
                    cameraEntity: cameraEntity,
                    startTime:    startTime,
                    duration:     duration,
                    degrees:      degrees,
                    axis:         axis
                )
            }
        } else {
            var isZoom = false
            if case .static_(let p) = selection, (p == .Zoomin || p == .Zoomout) {
                isZoom = true
            }
            card = AnimationInputCard(mode: .addShot(
                shotName:     shotName,
                defaultStart: timeline.duration,
                isZoom:       isZoom
            ))
            card.onConfirm = { [weak self] startTime, duration, zoomAmount, _ in
                guard let self, duration > 0 else { return }
                switch selection {
                case .movement(let preset):
                    self.applyCameraMovementPreset(preset, to: cameraEntity,
                                                   startTime: startTime, duration: duration)
                case .static_(let preset):
                    self.applyStaticShotPreset(preset, to: cameraEntity,
                                               startTime: startTime, duration: duration, zoomAmount: zoomAmount)
                }
            }
        }

        if let presented = presentedViewController {
            presented.dismiss(animated: true) { [weak self] in
                self?.present(card, animated: false)
            }
        } else {
            present(card, animated: false)
        }
    }

    /// Applies a pan or tilt with user-specified degrees and axis.
    /// Includes clip conflict detection/resolution identical to motion-path clips.
    private func applyCameraRotationShot(
        selection:    ShotSelection,
        cameraEntity: Entity,
        startTime:    Float,
        duration:     Float,
        degrees:      Float,
        axis:         RotationAxis
    ) {
        var cameraRoot: Entity = cameraEntity
        var cur: Entity? = cameraEntity.parent
        while let p = cur {
            if p.name.hasPrefix("SceneCameraRoot_") { cameraRoot = p; break }
            cur = p.parent
        }

        if baseTransforms[cameraRoot.name] == nil {
            baseTransforms[cameraRoot.name] = cameraRoot.transform
        }

        let candidateClip = AnimationClip(
            entityName: cameraRoot.name,
            entityID:   cameraRoot.components[EntityIDComponent.self]?.id,
            type:       .rotate,
            track:      .rotation,
            easing:     .easeInOut,
            startTime:  startTime,
            duration:   duration,
            fromValue:  axis.simdAxis,
            toValue:    SIMD3<Float>(degrees * (.pi / 180), 0, 0)
        )

        // ── Conflict check ────────────────────────────────────────────────────
        if let conflict = detectClipConflict(editedClip: candidateClip, replacingID: UUID()) {
            // Use a "fake" old clip index — for new clips we append, so pass count as sentinel.
            // commitClipTimingChange handles appending when index == clips.count.
            let insertIndex = timeline.clips.count
            presentClipConflictResolution(
                editedClip:      candidateClip,
                replacingID:     candidateClip.id,   // new clip — no old ID to replace
                conflicting:     conflict,
                clipIndex:       insertIndex,
                originalEndTime: startTime           // no previous end; gap = conflict.start - startTime
            )
        } else {
            timeline.addClip(candidateClip)
            if let entity = arView.scene.findEntity(named: cameraRoot.name) {
                showRotationArc(for: candidateClip, on: entity)
            }
        }
        debugPrintTimeline()
    }

    // ── Camera Movement Application ───────────────────────────────────────────
    func applyCameraMovementPreset(
        _ preset: CameraMovementPreset,
        to cameraEntity: Entity,
        startTime: Float,
        duration: Float
    ) {
        var cameraRoot: Entity = cameraEntity
        var cur: Entity? = cameraEntity.parent
        while let p = cur {
            if p.name.hasPrefix("SceneCameraRoot_") { cameraRoot = p; break }
            cur = p.parent
        }

        if baseTransforms[cameraRoot.name] == nil {
            baseTransforms[cameraRoot.name] = cameraRoot.transform
        }

        // ── Chain origin: use the end-position of the last motion-path clip
        //    for this camera, just like regular entities do. If no prior clip
        //    exists, fall back to the camera's current world position.
        let chainedOrigin = lastMotionPathEndPosition(for: cameraRoot.name)
                         ?? cameraRoot.position(relativeTo: nil)

        let motionPath = generateCameraMovementPath(
            preset: preset,
            camera: cameraRoot,
            origin: chainedOrigin
        )

        let track:     AnimationTrack
        let fromValue: SIMD3<Float>
        let toValue:   SIMD3<Float>

        switch preset {
        case .pan:
            track     = .rotation
            fromValue = RotationAxis.y.simdAxis
            toValue   = SIMD3<Float>(.pi / 3, 0, 0)
        case .tilt:
            track     = .rotation
            fromValue = RotationAxis.x.simdAxis
            toValue   = SIMD3<Float>(-.pi / 4.5, 0, 0)
        case .dollyIn, .dollyOut, .crane:
            track     = .position
            fromValue = .zero
            toValue   = .zero
        }

        let candidateClip = AnimationClip(
            entityName: cameraRoot.name,
            entityID:   cameraRoot.components[EntityIDComponent.self]?.id,
            type:       track == .rotation ? .rotate : .move,
            track:      track,
            easing:     .easeInOut,
            startTime:  startTime,
            duration:   duration,
            fromValue:  fromValue,
            toValue:    toValue,
            motionPath: motionPath
        )

        // ── Conflict check ────────────────────────────────────────────────────
        if let conflict = detectClipConflict(editedClip: candidateClip, replacingID: UUID()) {
            let insertIndex = timeline.clips.count
            presentClipConflictResolution(
                editedClip:      candidateClip,
                replacingID:     candidateClip.id,
                conflicting:     conflict,
                clipIndex:       insertIndex,
                originalEndTime: startTime
            )
        } else {
            timeline.addClip(candidateClip)
            if candidateClip.motionPath != nil {
                showMotionPath(for: candidateClip)
            }
            if track == .rotation, let entity = arView.scene.findEntity(named: cameraRoot.name) {
                showRotationArc(for: candidateClip, on: entity)
            }
        }
        debugPrintTimeline()
    }

    // ── Static Shot Application ────────────────────────────────────────────────
    func applyStaticShotPreset(
        _ preset: StaticShotPreset,
        to cameraEntity: Entity,
        startTime: Float,
        duration: Float,
        zoomAmount: Float = 0
    ) {
        var cameraRoot: Entity = cameraEntity
        var cur: Entity? = cameraEntity.parent
        while let p = cur {
            if p.name.hasPrefix("SceneCameraRoot_") { cameraRoot = p; break }
            cur = p.parent
        }

        if baseTransforms[cameraRoot.name] == nil {
            baseTransforms[cameraRoot.name] = cameraRoot.transform
        }

        // Static shots also chain from the last known end position
        let pos = lastMotionPathEndPosition(for: cameraRoot.name)
                ?? cameraRoot.position(relativeTo: nil)

        let candidateClip: AnimationClip
        switch preset {
        case .establishing:
            candidateClip = AnimationClip(
                entityName: cameraRoot.name,
                entityID:   cameraRoot.components[EntityIDComponent.self]?.id,
                type:       .move,
                track:      .position,
                easing:     .easeInOut,
                startTime:  startTime,
                duration:   duration,
                fromValue:  .zero,
                toValue:    .zero,
                motionPath: BezierMotionPath(start: pos, control1: pos, control2: pos, end: pos)
            )
            
        case .Zoomin, .Zoomout:
            // Read the camera's actual current FOV so the animation starts exactly
            // from the lens's current field of view, not a hard-coded value.
            let currentCamera = cameraRoot.children.compactMap { $0 as? PerspectiveCamera }.first
            let currentFOV: Float = currentCamera?.camera.fieldOfViewInDegrees ?? 60.0

            // Zoom In  → FOV decreases (telephoto / narrower angle of view)
            // Zoom Out → FOV increases (wide-angle / broader angle of view)
            // zoomAmount is the target FOV chosen by the user in AnimationInputCard.
            // If unset (0), fall back to sensible per-direction defaults.
            let endFOV: Float
            if zoomAmount > 0 {
                endFOV = zoomAmount
            } else {
                endFOV = (preset == .Zoomin) ? max(currentFOV * 0.5, 20.0)
                                             : min(currentFOV * 1.5, 90.0)
            }

            candidateClip = AnimationClip(
                entityName: cameraRoot.name,
                entityID:   cameraRoot.components[EntityIDComponent.self]?.id,
                type:       .zoom,
                track:      .fov,
                easing:     .easeInOut,
                startTime:  startTime,
                duration:   duration,
                fromValue:  SIMD3<Float>(currentFOV, 0, 0),
                toValue:    SIMD3<Float>(endFOV,     0, 0),
                motionPath: nil
            )
        }

        // ── Conflict check ────────────────────────────────────────────────────
        if let conflict = detectClipConflict(editedClip: candidateClip, replacingID: UUID()) {
            let insertIndex = timeline.clips.count
            presentClipConflictResolution(
                editedClip:      candidateClip,
                replacingID:     candidateClip.id,
                conflicting:     conflict,
                clipIndex:       insertIndex,
                originalEndTime: startTime
            )
        } else {
            timeline.addClip(candidateClip)
            // Only show a motion-path overlay for clips that actually have a path
            // (FOV / zoom clips have motionPath == nil, so skip showMotionPath for them)
            if candidateClip.motionPath != nil {
                showMotionPath(for: candidateClip)
            }
        }
        debugPrintTimeline()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Chained Origin Helper
    // ─────────────────────────────────────────────────────────────────────────

    /// Returns the world-space end position of the last motion-path clip for
    /// `entityName`, so that a newly-added path starts exactly where the
    /// previous one finishes — mirroring the behaviour for regular entities.
    ///
    /// Returns `nil` when no prior motion-path clips exist.
    func lastMotionPathEndPosition(for entityName: String) -> SIMD3<Float>? {
        let lastPathClip = timeline.clips
            .filter { $0.entityName == entityName && $0.motionPath != nil }
            .sorted { $0.startTime < $1.startTime }
            .last
        return lastPathClip?.motionPath?.end
    }

    // ── Path Generator ────────────────────────────────────────────────────────

    /// Generates a `BezierMotionPath` for `preset` starting at `origin`.
    ///
    /// `origin` is supplied by the caller (either the camera's current position
    /// or the chained end of the previous clip) so this function stays pure and
    /// testable without touching the entity hierarchy.
    func generateCameraMovementPath(
        preset: CameraMovementPreset,
        camera: Entity,
        origin: SIMD3<Float>
    ) -> BezierMotionPath? {
        // Walk up to the SceneCameraRoot_ so orientation is correct even when
        // `camera` is a visual-model child entity.
        var root: Entity = camera
        var current: Entity? = camera.parent
        while let p = current {
            if p.name.hasPrefix("SceneCameraRoot_") { root = p; break }
            current = p.parent
        }

        let rot     = root.orientation(relativeTo: nil)
        let forward = rot.act(SIMD3<Float>( 0,  0,  1))
        let up      = rot.act(SIMD3<Float>( 0,  1,  0))

        switch preset {
        case .pan, .tilt: return nil
        case .dollyIn:
            return BezierMotionPath(
                start: origin, control1: origin + forward * 0.5,
                control2: origin + forward * 1.5, end: origin + forward * 2.0)
        case .dollyOut:
            return BezierMotionPath(
                start: origin, control1: origin - forward * 0.5,
                control2: origin - forward * 1.5, end: origin - forward * 2.0)
        case .crane:
            let lift = up * 1.5
            return BezierMotionPath(
                start: origin, control1: origin + up * 0.5,
                control2: origin + lift + forward * 0.3, end: origin + lift + forward * 0.5)
        }
    }

    // Overload kept for call sites that don't yet pass an explicit origin.
    // It reads the current entity position, matching legacy behaviour.
    func generateCameraMovementPath(
        preset: CameraMovementPreset,
        camera: Entity
    ) -> BezierMotionPath? {
        var root: Entity = camera
        var current: Entity? = camera.parent
        while let p = current {
            if p.name.hasPrefix("SceneCameraRoot_") { root = p; break }
            current = p.parent
        }
        return generateCameraMovementPath(preset: preset, camera: root,
                                          origin: root.position(relativeTo: nil))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Conflict resolution override for NEW clips
//
// commitClipTimingChange assumes an existing index to overwrite. For brand-new
// camera clips the "index" sentinel is timeline.clips.count (append).
// We extend ClipConflict to handle this case gracefully.
// ─────────────────────────────────────────────────────────────────────────────

extension CanvasViewController {

    /// Variant of commitClipTimingChange used when adding a brand-new clip
    /// (no existing clip to replace). The clip is simply appended and visuals
    /// are shown if needed.
    func commitNewCameraClip(_ clip: AnimationClip) {
        timeline.addClip(clip)
        if clip.motionPath != nil {
            showMotionPath(for: clip)
        }
        if clip.track == .rotation,
           let entity = arView.scene.findEntity(named: clip.entityName) {
            showRotationArc(for: clip, on: entity)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ShotPickerViewController
// ─────────────────────────────────────────────────────────────────────────────

final class ShotPickerViewController: UIViewController {

    private let cameraEntity: Entity
    private let onSelect: (ShotSelection) -> Void

    private let scrollView   = UIScrollView()
    private let contentStack = UIStackView()

    private let movementPresets = CameraMovementPreset.allCases
    private let staticPresets   = StaticShotPreset.allCases

    private let cardSize    = CGSize(width: 220, height: 200)
    private let cardSpacing: CGFloat = 12

    init(cameraEntity: Entity, onSelect: @escaping (ShotSelection) -> Void) {
        self.cameraEntity = cameraEntity
        self.onSelect     = onSelect
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add Shot"
        view.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(dismissSelf)
        )

        setupScrollLayout()
        buildSections()
    }

    private func setupScrollLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        contentStack.axis      = .vertical
        contentStack.spacing   = 28
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func buildSections() {
        let movSection = makeSectionView(
            title: "Camera Movements",
            cards: movementPresets.map { preset in
                ShotCardView(
                    imageName: preset.imageName,
                    fallbackSymbol: preset.fallbackSFSymbol,
                    label: preset.rawValue
                ) { [weak self] in
                    self?.dismiss(animated: true) {
                        self?.onSelect(.movement(preset))
                    }
                }
            }
        )
        contentStack.addArrangedSubview(movSection)

        let staticSection = makeSectionView(
            title: "Static Shots",
            cards: staticPresets.map { preset in
                ShotCardView(
                    imageName: preset.imageName,
                    fallbackSymbol: preset.fallbackSFSymbol,
                    label: preset.rawValue
                ) { [weak self] in
                    self?.dismiss(animated: true) {
                        self?.onSelect(.static_(preset))
                    }
                }
            }
        )
        contentStack.addArrangedSubview(staticSection)
    }

    private func makeSectionView(title: String, cards: [ShotCardView]) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)

        let row = UIStackView()
        row.axis    = .horizontal
        row.spacing = cardSpacing
        row.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(row)

        let inset: CGFloat = 20
        cards.forEach { card in
            card.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                card.widthAnchor.constraint(equalToConstant: cardSize.width),
                card.heightAnchor.constraint(equalToConstant: cardSize.height),
            ])
            row.addArrangedSubview(card)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),

            scroll.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.heightAnchor.constraint(equalToConstant: cardSize.height),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            row.topAnchor.constraint(equalTo: scroll.topAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: inset),
            row.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -inset),
            row.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.heightAnchor),
        ])

        return container
    }

    @objc private func dismissSelf() { dismiss(animated: true) }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ShotCardView
// ─────────────────────────────────────────────────────────────────────────────

final class ShotCardView: UIView {

    private let onTap: () -> Void

    init(imageName: String, fallbackSymbol: String, label: String, onTap: @escaping () -> Void) {
        self.onTap = onTap
        super.init(frame: .zero)

        backgroundColor    = UIColor(red: 18/255, green: 18/255, blue: 28/255, alpha: 1)
        layer.cornerRadius = 16
        layer.borderWidth  = 1
        layer.borderColor  = UIColor.white.withAlphaComponent(0.1).cgColor
        clipsToBounds      = true

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor   = UIColor(red: 177/255, green: 32/255, blue: 57/255, alpha: 1)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        if let namedImage = UIImage(named: imageName) {
            imageView.image = namedImage
        } else {
            let cfg = UIImage.SymbolConfiguration(pointSize: 56, weight: .light)
            imageView.image = UIImage(systemName: fallbackSymbol, withConfiguration: cfg)
        }
        addSubview(imageView)

        let nameLabel = UILabel()
        nameLabel.text          = label
        nameLabel.textColor     = .white
        nameLabel.font          = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            imageView.bottomAnchor.constraint(equalTo: nameLabel.topAnchor, constant: -8),

            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            nameLabel.heightAnchor.constraint(equalToConstant: 36),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func handleTap() {
        UIView.animate(withDuration: 0.08, animations: {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            self.backgroundColor = UIColor(red: 40/255, green: 40/255, blue: 58/255, alpha: 1)
        }) { _ in
            UIView.animate(withDuration: 0.12) {
                self.transform = .identity
                self.backgroundColor = UIColor(red: 18/255, green: 18/255, blue: 28/255, alpha: 1)
            }
            self.onTap()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: 0.08) {
            self.backgroundColor = UIColor(red: 40/255, green: 40/255, blue: 58/255, alpha: 1)
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.12) {
            self.backgroundColor = UIColor(red: 18/255, green: 18/255, blue: 28/255, alpha: 1)
        }
    }
}
