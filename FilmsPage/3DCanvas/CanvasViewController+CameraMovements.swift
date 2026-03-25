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
    // Custom illustrative icon name — falls back to SF Symbol if image not found
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
    case wide         = "Wide Shot"
    case medium       = "Medium Shot"
    case closeUp      = "Close-up"
    case insert       = "Insert/Cutaway"

    var description: String {
        switch self {
        case .establishing: return "Sets up location and context."
        case .wide:         return "Subject in full environment."
        case .medium:       return "Waist-up framing."
        case .closeUp:      return "Tight shot on face or detail."
        case .insert:       return "Cut to a supporting detail."
        }
    }
    var imageName: String {
        switch self {
        case .establishing: return "shot_establishing"
        case .wide:         return "shot_wide"
        case .medium:       return "shot_medium"
        case .closeUp:      return "shot_closeup"
        case .insert:       return "shot_insert"
        }
    }
    var fallbackSFSymbol: String {
        switch self {
        case .establishing: return "mappin.and.ellipse"
        case .wide:         return "rectangle.expand.vertical"
        case .medium:       return "person.crop.rectangle"
        case .closeUp:      return "magnifyingglass"
        case .insert:       return "scissors"
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
            // After user picks a shot, ask for start time + duration
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

        // Determine whether this selection needs rotation controls
        let isRotation: Bool
        var presetAxis    = RotationAxis.y
        var presetDegrees: Float = 60

        if case .movement(let p) = selection {
            switch p {
            case .pan:
                isRotation    = true
                presetAxis    = .y
                presetDegrees = 60   // π/3 in degrees
            case .tilt:
                isRotation    = true
                presetAxis    = .x
                presetDegrees = -40  // −π/4.5 ≈ −40°
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
            // Pan / Tilt — show full rotation card so user can tweak axis + degrees
            card = AnimationInputCard(mode: .editRotateFull(
                currentStart:    timeline.duration,
                currentDuration: 3.0,
                currentDegrees:  presetDegrees,
                currentAxis:     presetAxis
            ))
            card.onConfirm = { [weak self] startTime, duration, degrees, axis in
                guard let self, duration > 0 else { return }
                // Override the clip values with what the user chose
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
            // Dolly / Crane / Static — just timing
            card = AnimationInputCard(mode: .addShot(
                shotName:     shotName,
                defaultStart: timeline.duration
            ))
            card.onConfirm = { [weak self] startTime, duration, _, _ in
                guard let self, duration > 0 else { return }
                switch selection {
                case .movement(let preset):
                    self.applyCameraMovementPreset(preset, to: cameraEntity,
                                                   startTime: startTime, duration: duration)
                case .static_(let preset):
                    self.applyStaticShotPreset(preset, to: cameraEntity,
                                               startTime: startTime, duration: duration)
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
        let clip = AnimationClip(
            entityName: cameraRoot.name,
            type:       .rotate,
            track:      .rotation,
            easing:     .easeInOut,
            startTime:  startTime,
            duration:   duration,
            fromValue:  axis.simdAxis,
            toValue:    SIMD3<Float>(degrees * (.pi / 180), 0, 0)
        )
        timeline.addClip(clip)
        if let entity = arView.scene.findEntity(named: cameraRoot.name) {
            showRotationArc(for: clip, on: entity)
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
        // Resolve to the SceneCameraRoot_ so entityName matches what the timeline
        // and entity-drag code uses. The tapped entity may be the visual model child.
        var cameraRoot: Entity = cameraEntity
        var cur: Entity? = cameraEntity.parent
        while let p = cur {
            if p.name.hasPrefix("SceneCameraRoot_") { cameraRoot = p; break }
            cur = p.parent
        }

        if baseTransforms[cameraRoot.name] == nil {
            baseTransforms[cameraRoot.name] = cameraRoot.transform
        }

        let motionPath = generateCameraMovementPath(preset: preset, camera: cameraRoot)

        let track:     AnimationTrack
        let fromValue: SIMD3<Float>
        let toValue:   SIMD3<Float>

        switch preset {
        case .pan:
            // Y-axis rotation (horizontal pan): totalRadians = pi/3 (~60°)
            track     = .rotation
            fromValue = RotationAxis.y.simdAxis
            toValue   = SIMD3<Float>(.pi / 3, 0, 0)
        case .tilt:
            // X-axis rotation — negative angle tilts down (toward the subject)
            track     = .rotation
            fromValue = RotationAxis.x.simdAxis
            toValue   = SIMD3<Float>(-.pi / 4.5, 0, 0)
        case .dollyIn, .dollyOut, .crane:
            track     = .position
            fromValue = .zero
            toValue   = .zero
        }

        let clip = AnimationClip(
            entityName: cameraRoot.name,
            type:       track == .rotation ? .rotate : .move,
            track:      track,
            easing:     .easeInOut,
            startTime:  startTime,
            duration:   duration,
            fromValue:  fromValue,
            toValue:    toValue,
            motionPath: motionPath
        )
        timeline.addClip(clip)

        if clip.motionPath != nil {
            showMotionPath(for: clip)
        }
        if track == .rotation, let entity = arView.scene.findEntity(named: cameraEntity.name) {
            showRotationArc(for: clip, on: entity)
        }
        debugPrintTimeline()
    }

    // ── Static Shot Application ────────────────────────────────────────────────
    func applyStaticShotPreset(
        _ preset: StaticShotPreset,
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
        let pos = cameraRoot.position(relativeTo: nil)
        let clip = AnimationClip(
            entityName: cameraRoot.name,
            type:       .move,
            track:      .position,
            easing:     .easeInOut,
            startTime:  startTime,
            duration:   duration,
            fromValue:  .zero,
            toValue:    .zero,
            motionPath: BezierMotionPath(start: pos, control1: pos, control2: pos, end: pos)
        )
        timeline.addClip(clip)
        showMotionPath(for: clip)
        debugPrintTimeline()
    }

    // ── Path Generator ────────────────────────────────────────────────────────
    func generateCameraMovementPath(
        preset: CameraMovementPreset,
        camera: Entity
    ) -> BezierMotionPath? {
        // IMPORTANT: `camera` may be the visual model child rather than the root
        // entity tracked by entityName/timeline. Walk up to the entity whose name
        // is registered in the timeline so path.start matches the tracked position.
        // If the root is not a SceneCameraRoot_ we fall back to the passed entity.
        var root: Entity = camera
        var current: Entity? = camera.parent
        while let p = current {
            if p.name.hasPrefix("SceneCameraRoot_") { root = p; break }
            current = p.parent
        }

        let origin = root.position(relativeTo: nil)
        let rot    = root.orientation(relativeTo: nil)

        // The PerspectiveCamera child is rotated 180° around Y so it shoots
        // along +Z (toward the lens front). Use +Z as the camera's forward
        // vector so dolly/crane paths move in the correct direction.
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
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ShotPickerViewController
//
// Card-grid layout matching the provided screenshot:
//   Section 0  — Camera Movements  (horizontal scroll row)
//   Section 1  — Static Shots      (horizontal scroll row)
// ─────────────────────────────────────────────────────────────────────────────

final class ShotPickerViewController: UIViewController {

    private let cameraEntity: Entity
    private let onSelect: (ShotSelection) -> Void

    private let scrollView  = UIScrollView()
    private let contentStack = UIStackView()

    private let movementPresets = CameraMovementPreset.allCases
    private let staticPresets   = StaticShotPreset.allCases

    // Card size matching screenshot proportions
    private let cardSize = CGSize(width: 220, height: 200)
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
        // ── Camera Movements ──────────────────────────────────────────────────
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

        // ── Static Shots ──────────────────────────────────────────────────────
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

    // ── Section builder ────────────────────────────────────────────────────────
    private func makeSectionView(title: String, cards: [ShotCardView]) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Section title
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        // Horizontal scroll
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)

        // Card row
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
//
// Individual card matching the screenshot:
//   • Dark rounded rectangle
//   • Image/illustration fills the top ~75% (uses imageName asset, falls back
//     to SF Symbol rendered large)
//   • Label centred at the bottom
//   • Subtle pressed-state highlight
// ─────────────────────────────────────────────────────────────────────────────

final class ShotCardView: UIView {

    private let onTap: () -> Void

    init(imageName: String, fallbackSymbol: String, label: String, onTap: @escaping () -> Void) {
        self.onTap = onTap
        super.init(frame: .zero)

        backgroundColor   = UIColor(red: 18/255, green: 18/255, blue: 28/255, alpha: 1)
        layer.cornerRadius = 16
        layer.borderWidth  = 1
        layer.borderColor  = UIColor.white.withAlphaComponent(0.1).cgColor
        clipsToBounds      = true

        // ── Image / illustration ─────────────────────────────────────────
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor   = UIColor(red: 177/255, green: 32/255, blue: 57/255, alpha: 1)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        // Try named asset first (for custom illustrations), fall back to SF Symbol
        if let namedImage = UIImage(named: imageName) {
            imageView.image = namedImage
        } else {
            let cfg   = UIImage.SymbolConfiguration(pointSize: 56, weight: .light)
            imageView.image = UIImage(systemName: fallbackSymbol, withConfiguration: cfg)
        }
        addSubview(imageView)

        // ── Label ─────────────────────────────────────────────────────────
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

        // Tap gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func handleTap() {
        // Brief press animation matching screenshot feel
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

    // Highlight on touch down
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
