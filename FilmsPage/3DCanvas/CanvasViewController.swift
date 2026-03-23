//
//  CanvasViewController.swift
//  3DCanvas
//
//  Created by SDC-USER on 12/01/26.
//

import Combine
import PhotosUI
import RealityKit

// MARK: - DisplayLink retain-cycle proxy (Fix 1)
// CADisplayLink retains its target strongly. Using a weak-reference proxy
// breaks the retain cycle so CanvasViewController can be deallocated normally
// when the modal is dismissed even if stopPlayback() was never called.
final class DisplayLinkProxy: NSObject {
    weak var target: CanvasViewController?
    @objc func tick(_ link: CADisplayLink) { target?.updatePlayback() }
}
import UIKit
import ARKit

// MARK: - SceneSnapshot (undo/redo)

struct SceneSnapshot {
    var entityTransforms: [String: Transform]
}

// MARK: - Gizmo / Interaction types

enum GizmoAxis {
    case x, y, z, none
}

struct LockComponent: Component {
    var isLocked: Bool = false
}

struct GizmoNames {
    static let xHandle = "Gizmo_Handle_X"
    static let yHandle = "Gizmo_Handle_Y"
    static let zHandle = "Gizmo_Handle_Z"
}

class SceneState: ObservableObject {
    @Published var entitiesToSpawn: [String] = []
}

// MARK: - Animation types

enum AnimationType: String, Codable {
    case move
    case rotate
}

enum EasingType: String, Codable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
}

enum AnimationTrack: String, Codable {
    case position
    case rotation
    case scale
}

// MARK: - AnimationClip
// FIX: Added `id` parameter to the designated initialiser so clips restored from
// persistence can carry their original stable UUID. All new clips still get a
// fresh UUID via the default argument.

struct AnimationClip: Identifiable, Codable {

    let id: UUID
    let entityName: String
    let type: AnimationType
    let track: AnimationTrack
    let easing: EasingType
    let startTime: Float
    let duration: Float
    let fromValue: SIMD3<Float>
    let toValue: SIMD3<Float>
    var motionPath: BezierMotionPath?

    struct DragPlane {
        var normal: SIMD3<Float>
        var point: SIMD3<Float>

        func intersect(
            rayOrigin: SIMD3<Float>,
            rayDirection: SIMD3<Float>
        ) -> SIMD3<Float>? {
            let denom = simd_dot(normal, rayDirection)
            guard abs(denom) >= 0.0001 else { return nil }
            let t = simd_dot(point - rayOrigin, normal) / denom
            guard t >= 0 else { return nil }
            return rayOrigin + rayDirection * t
        }
    }

    // FIX: `id` now has a default of `UUID()` so existing call-sites that omit it
    // continue to work, while ScenePersistenceService can supply the saved UUID.
    init(
        id: UUID = UUID(),
        entityName: String,
        type: AnimationType,
        track: AnimationTrack,
        easing: EasingType,
        startTime: Float,
        duration: Float,
        fromValue: SIMD3<Float>,
        toValue: SIMD3<Float>,
        motionPath: BezierMotionPath? = nil
    ) {
        self.id         = id
        self.entityName = entityName
        self.type       = type
        self.track      = track
        self.easing     = easing
        self.startTime  = startTime
        self.duration   = duration
        self.fromValue  = fromValue
        self.toValue    = toValue
        self.motionPath = motionPath
    }
}

// MARK: - MotionPathVisual

struct MotionPathVisual {
    let root: Entity
    let startHandle: ModelEntity?
    let control1Handle: ModelEntity
    let control2Handle: ModelEntity
    let endHandle: ModelEntity

    func update(path: BezierMotionPath) {
        startHandle?.position    = .zero
        control1Handle.position  = path.control1 - path.start
        control2Handle.position  = path.control2 - path.start
        endHandle.position       = path.end - path.start
    }
}

// MARK: - Timeline

struct Timeline {
    var clips: [AnimationClip] = []

    var duration: Float {
        clips.map { $0.startTime + $0.duration }.max() ?? 0
    }

    mutating func addClip(_ clip: AnimationClip) {
        clips.append(clip)
    }

    func clips(at time: Float) -> [AnimationClip] {
        clips.filter { time >= $0.startTime && time <= ($0.startTime + $0.duration) }
    }

    mutating func removeAll() {
        clips.removeAll()
    }
}

extension Timeline {
    func effectiveClips(at time: Float) -> [AnimationClip] {
        clips.filter { time >= $0.startTime }
    }
}

// MARK: - Transform interpolation

extension Transform {
    static func interpolate(from: Transform, to: Transform, t: Float) -> Transform {
        let ct  = max(0, min(1, t))
        let rep = SIMD3<Float>(repeating: ct)
        return Transform(
            scale:       simd_mix(from.scale, to.scale, rep),
            rotation:    simd_slerp(from.rotation, to.rotation, ct),
            translation: simd_mix(from.translation, to.translation, rep)
        )
    }
}

// MARK: - Ray-plane intersection (free function)

func rayPlaneIntersection(
    rayOrigin: SIMD3<Float>,
    rayDirection: SIMD3<Float>,
    planePoint: SIMD3<Float>,
    planeNormal: SIMD3<Float>
) -> SIMD3<Float>? {
    let denom = simd_dot(planeNormal, rayDirection)
    guard abs(denom) >= 0.0001 else { return nil }
    let t = simd_dot(planePoint - rayOrigin, planeNormal) / denom
    guard t >= 0 else { return nil }
    return rayOrigin + rayDirection * t
}

// MARK: - Easing

func applyEasing(_ t: Float, easing: EasingType) -> Float {
    switch easing {
    case .linear:    return t
    case .easeIn:    return t * t
    case .easeOut:   return 1 - pow(1 - t, 2)
    case .easeInOut: return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}

// MARK: - CanvasViewController

class CanvasViewController: UIViewController, UIGestureRecognizerDelegate {

    // MARK: - AR Mode
    var isARModeActive: Bool = false
    weak var arModeButton: UIButton?

    // MARK: - Scene identity
    var currentSceneObject: Scene?
    var sceneName: String = "Untitled Scene"
    var filmName: String?
    var sequenceName: String?
    var sceneNotes: String = ""
    var lastEditedDate: Date = Date()
    var sceneImageName: String?
    var currentSceneID: UUID?

    // MARK: - Cached anchor reference
    // FIX: Cache MainAnchor so we avoid a full scene-graph DFS on every access.
    // Set once in setupInitialScene(), never nil after that.
    private(set) var mainAnchor: AnchorEntity?

    // FIX 8: Set to true during scene load so that the many intermediate
    // refreshSidebarContent() call sites don't each trigger a full UI rebuild.
    // The persistence service resets it to false and calls refreshSidebarContent once at Phase 9.
    var isBatchLoading: Bool = false

    // FIX 6: Dedicated container for PathRoot_ entities so they don't appear in
    // sidebar, undo snapshots, or save documents (they are always reconstructed
    // from the timeline clips at load time).
    var pathAnchor: Entity?

    // MARK: - Undo / redo
    // FIX: Capped at 30 steps to prevent unbounded memory growth.
    private let undoLimit = 30
    var undoStack: [SceneSnapshot] = []
    var redoStack: [SceneSnapshot] = []

    // MARK: - Drag state
    enum DragMode { case ground; case vertical }
    var currentDragMode: DragMode = .ground

    var arView: ARView!
    var selectedEntity: Entity?
    var dragStartPosition: SIMD3<Float>?
    var isDraggingObject = false
    var initialRotation: simd_quatf?

    // FIX: Cached sibling bounds for overlap detection — rebuilt at drag start,
    // reused every .changed event so we don't call visualBounds inside a per-frame loop.
    private var cachedSiblingBounds: [(entity: Entity, bounds: BoundingBox)] = []

    // MARK: - Gizmo
    var rotationGizmo: RotationRingGizmo?

    enum GizmoPart {
        case arrowY
        case planeXZ
        case rotateX
        case rotateY
        case rotateZ
        case none
    }

    var gizmoRoot: Entity?
    var activeGizmoPart: GizmoPart = .none

    lazy var movementToggleButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "arrow.left.and.right"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
        btn.layer.cornerRadius = 20
        btn.clipsToBounds = true
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // MARK: - Camera
    var yaw: Float       = 0.5
    var pitch: Float     = 0.5
    var distance: Float  = 5.0
    var cameraTarget     = SIMD3<Float>(0, 0, 0)

    var editorCamera: PerspectiveCamera!
    var activeCamera: PerspectiveCamera!

    var sceneCameras: [PerspectiveCamera] = []
    var isCameraPanelExpanded: Bool = false
    var cameraToVisualMap: [PerspectiveCamera: Entity] = [:]

    var lastGestureRotation: Float = 0
    var accumulatedRotation: Float = 0

    var backgroundPlane: ModelEntity?
    var backgroundCounter = 0

    // FIX E: Counts async background-texture Tasks that are still in flight.
    // saveAndExit() polls this counter and delays the JSON save until it reaches
    // zero, preventing the race where cachedImage is nil because TextureResource
    // upload hasn't completed yet.
    var pendingBackgroundTasks: Int = 0

    var currentAxis: GizmoAxis = .none
    var currentActionMenu: EntityActionMenu?

    struct SceneCameraItem {
        let camera: PerspectiveCamera
        let cameraRoot: Entity
        var previewImage: UIImage?   // snapshot taken from this camera's POV; nil until first capture
    }

    var sceneCameraItems: [SceneCameraItem] = []
    var cameraCollectionView: UICollectionView!

    // MARK: - Top Right UI
    let shotBreakdownBtn: UIButton = {
        let btn = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "list.bullet.indent")
        config.preferredSymbolConfigurationForImage =
            UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        config.baseBackgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        btn.configuration = config
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.layer.shadowColor   = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.3
        btn.layer.shadowOffset  = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius  = 4
        return btn
    }()

    // MARK: - Sidebar
    let sidebarWidth: CGFloat = 210
    var isSidebarVisible = false
    var sidebarLeadingConstraint: NSLayoutConstraint!

    let sidebarView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray5
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.shadowColor   = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.3
        view.layer.shadowRadius  = 5
        return view
    }()

    let hierarchyStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis    = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    let layersButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "square.stack.3d.down.right"), for: .normal)
        b.tintColor       = .white
        b.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
        b.layer.cornerRadius = 20
        b.clipsToBounds   = true
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    lazy var sceneNameLabel: UILabel = {
        let label = UILabel()
        label.text          = self.sceneName.uppercased()
        label.font          = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor     = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Timeline properties
    var activeDraggedClipID: UUID?
    var activeDraggedHandleName: String?

    var timelineContainer: UIView!
    var playButton: UIButton!
    var stopButton: UIButton!
    var pauseButton: UIButton!
    var playbackButtonStack: UIStackView!
    var scrubber: UISlider!

    // FIX: displayLink is tracked as a property so it can be reliably invalidated on teardown.
    var displayLink: CADisplayLink?

    /// Repeating 3fps timer that drives the off-screen camera preview snapshots.
    var cameraPreviewTimer: Timer?

    var playbackStartTime: CFTimeInterval = 0
    var currentTimelineTime: Float = 0

    enum PlaybackState { case stopped; case playing; case paused }
    var playbackState: PlaybackState = .stopped

    var baseTransforms: [String: Transform] = [:]
    var selectedPathClipID: UUID?

    // MARK: - Motion path state
    struct MotionPathHandleComponent: Component {
        let clipID: UUID
    }

    /// Stable per-entity UUID assigned at spawn time and persisted in EntityRecord.
    /// Survives save/load cycles so AnimationClip bindings can be re-keyed by ID
    /// instead of mutable name if names ever drift.
    struct EntityIDComponent: Component {
        let id: UUID
    }

    var timeline = Timeline()

    var lastWorldDragPoint: SIMD3<Float>?
    var activeDragPlaneNormal: SIMD3<Float>?
    var activeDragPlanePoint: SIMD3<Float>?
    var initialHandleOffset: SIMD3<Float> = .zero
    var activeMotionPaths: [UUID: MotionPathVisual] = [:]

    // MARK: - Rotation arc state
    var activeRotationArcs: [UUID: RotationArcVisual] = [:]
    var selectedArcClipID: UUID?
    var draggingArcHandle: Entity?
    var draggingArcClipID: UUID?
    var draggingArcRole: RotationArcComponent.Role?
    var arcDragLastAngle: Float = 0
    var arcDragCentre: SIMD3<Float>?

    // MARK: - Editor mode
    var editorMode: EditorMode = .edit

    enum EditorMode { case edit; case timeline }

    var animationPanel: UIStackView!

    enum InteractionMode { case move; case rotate; case none }
    var interactionMode: InteractionMode = .move

    // MARK: - Pan drag state
    var activeRotationAxis: SIMD3<Float>?
    var lastPanLocation: CGPoint = .zero
    var lastDragPoint: SIMD3<Float>?
    var activeHandleEntity: Entity?
    var lastUndoTime: CFTimeInterval = 0
    var pathRebuildFrameCount: Int = 0

    /// Entity lookup cache for evaluateTimeline — rebuilt in enterTimelineMode(),
    /// cleared in exitTimelineMode(). Avoids O(n) findEntity DFS every display-link tick.
    var timelineEntityCache: [String: Entity] = [:]

    /// Authoritative store for background UIImages, keyed by entity name.
    /// BackgroundComponent.cachedImage can become nil if TextureResource upload fails
    /// on first restore.  This dictionary survives that failure and lets save() always
    /// find the original UIImage so the JPEG is never silently dropped.
    /// Populated by applyBackgroundImage() and restoreEntity(). Cleared by clearSceneState().
    var backgroundImageCache: [String: UIImage] = [:]

    // MARK: - Geometry components

    // FIX: BackgroundComponent now carries a `cachedImage` so the persistence
    // service can extract the texture without a round-trip through TextureResource.
    struct BackgroundComponent: Component {
        var width: Float
        var height: Float
        var cachedImage: UIImage?   // retained reference to the original UIImage
    }

    var pathEditToolbar: UIView?

    struct WallComponent: Component {
        var width: Float = 1.5
        var height: Float = 1.2
    }

    struct GroundComponent: Component {
        var width: Float
        var depth: Float
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupARView()
        setupInitialScene()
        setupUI()
        setupGestures()
        setupTimelineControls()
        setupNavigationBar()
        setupTopControlsUI()
        setupGizmo()
        updateGizmoMode()

        BackgroundStore.shared.onImageSelected = { [weak self] pickedImage in
            DispatchQueue.main.async {
                self?.applyBackgroundImage(pickedImage)
            }
        }
        sceneNameLabel.text = sceneName
        setupAnimationPanel()
        // Scene is loaded in viewDidAppear so the ARView gets a rendered frame first.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Defer scene load until the view is fully on screen.
        // This lets RealityKit finish its initial render pass before we
        // start deserialising entities, preventing the black-screen stall
        // that occurred when loadSceneIfSaved() ran synchronously in viewDidLoad.
        loadSceneIfSaved()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // FIX: Always invalidate the display link on disappear to prevent it from
        // running against a deallocated view controller, which caused the slowdown
        // observed after save→exit→reload.
        displayLink?.invalidate()
        displayLink = nil
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.cameraCollectionView?.collectionViewLayout.invalidateLayout()
        })
    }


    deinit {
        // Safety net: ensure the display link is gone even if viewWillDisappear was skipped.
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Pinch and rotation always coexist (standard two-finger simultaneous feel)
        if gestureRecognizer is UIPinchGestureRecognizer
            || otherGestureRecognizer is UIPinchGestureRecognizer { return true }
        if gestureRecognizer is UIRotationGestureRecognizer
            || otherGestureRecognizer is UIRotationGestureRecognizer { return true }

        // FIX: Block 1-finger pan from firing simultaneously with 2-finger pan.
        // Without this, camera orbit and object drag conflicted — objects jumped
        // while orbiting, and the camera orbited while dragging objects.
        if let pan   = gestureRecognizer as? UIPanGestureRecognizer,
           let other = otherGestureRecognizer as? UIPanGestureRecognizer {
            // If either pan requires 2+ touches it is the camera-orbit/pan gesture.
            // The 1-touch object-drag must not fire at the same time.
            if pan.minimumNumberOfTouches >= 2 || other.minimumNumberOfTouches >= 2 {
                return false
            }
        }
        return true
    }

    // MARK: - Navigation

    @objc func backButtonTapped() {
        promptSaveAndExit()
    }

    // MARK: - Setup

    func setupARView() {
        // Single .ar ARView — initialises one Metal pipeline.
        // Editor mode: white background, idle session (renders frames for Metal).
        // AR mode: .cameraFeed() background, session with plane detection.
        arView = ARView(frame: view.bounds,
                        cameraMode: .ar,
                        automaticallyConfigureSession: false)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.renderOptions    = [.disableMotionBlur, .disableDepthOfField, .disableHDR]
        arView.debugOptions     = []
        arView.environment.background = .color(.white)   // solid white canvas in editor
        view.addSubview(arView)

        // Start idle session so Metal pipeline produces frames → white renders immediately.
        // Without this, .ar mode shows black because no frames are being generated.
        let idleConfig = ARWorldTrackingConfiguration()
        idleConfig.planeDetection = []
        idleConfig.isLightEstimationEnabled = false
        arView.session.run(idleConfig)
    }


    func setupInitialScene() {
        let anchor = AnchorEntity(world: .zero)
        anchor.name = "MainAnchor"

        // FIX: size argument removed — makeGrid now defaults to size:20, giving 82
        // line entities instead of 402 (a ~5× draw-call reduction). See makeGrid().
        let editorGrid = makeGrid(spacing: 0.2)
        editorGrid.name = "Grid"
        anchor.addChild(editorGrid)

        editorCamera       = PerspectiveCamera()
        editorCamera.name  = "EditorCamera"
        editorCamera.isEnabled = true
        anchor.addChild(editorCamera)

        // FIX 6: PathContainer holds all PathRoot_ entities so they are excluded
        // from sidebar, undo snapshots, and save documents automatically.
        let pathContainer = Entity()
        pathContainer.name = "PathContainer"
        anchor.addChild(pathContainer)

        activeCamera = editorCamera
        arView.scene.addAnchor(anchor)

        // FIX: Cache the anchor reference once — avoids O(n) scene-graph DFS on every access.
        mainAnchor = anchor
        pathAnchor = pathContainer

        updateEditorCamera()
    }

    // MARK: - Spawn

    func spawnEntity(
        item: SpawnItem,
        toolType: ToolType,
        customName: String? = nil,
        scale: Float = 1.0,
        isRestoring: Bool = false
    ) {
        if !isRestoring {
            saveCurrentStateToUndo()
        }

        if toolType == .sky {
            if item.modelFileName == "none" {
                removeSky()
            } else {
                applySky(type: item.modelFileName)
            }
            return
        }

        Task {
            do {
                let checkName = (customName ?? item.modelFileName).lowercased()

                if checkName.contains("ground") { spawnGround(); return }
                if checkName.contains("wall") || item.modelFileName == "cube" { spawnWall(); return }
                if checkName.contains("scenecamera") || item.modelFileName == "cam1" { spawnSceneCamera(); return }
                if item.isBackground { spawnBackgroundPlane(item); return }

                let entity = try await Entity(named: item.modelFileName)

                var verticalOffset: Float = 0.0

                if isARModeActive {
                    // ── AR: 1:1 physical scale ──
                    // Keep native USDZ metric scale so a 6ft character = 6ft in AR.
                    // No normalisation, no prop-specific overrides.
                    // Just lift to ground plane.
                } else {
                    // ── Editor: normalise + prop-specific scales ──
                    let bounds = entity.visualBounds(relativeTo: nil)
                    let maxDim = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                    if maxDim > 0.0001 {
                        entity.scale = SIMD3(repeating: 1.0 / maxDim)
                    }

                    if item.modelFileName == "Spotlight" {
                        entity.scale   = SIMD3(repeating: 0.01); verticalOffset = 0.25
                    } else if item.modelFileName.contains("LED") {
                        entity.scale   = SIMD3(repeating: 0.01)
                    } else if item.modelFileName.contains("Lantern") {
                        entity.scale   = SIMD3(repeating: 0.0025); verticalOffset = 0.25
                    } else if item.modelFileName.contains("Plant") {
                        entity.scale   = SIMD3(repeating: 0.01)
                    } else {
                        entity.scale   = SIMD3<Float>(repeating: scale)
                    }
                }

                // Position — AR-aware (see CanvasViewController+ARInteraction.swift)
                let finalBounds = entity.visualBounds(relativeTo: nil)
                let liftToGround = -finalBounds.min.y
                let spawnX: Float
                let spawnZ: Float
                let finalY: Float

                if isARModeActive {
                    let pos = arSpawnPosition(verticalOffset: verticalOffset, liftToGround: liftToGround)
                    spawnX = pos.x; finalY = pos.y; spawnZ = pos.z
                } else {
                    spawnX = Float.random(in: -1...1)
                    spawnZ = Float.random(in: -1...1)
                    finalY = verticalOffset > 0 ? verticalOffset : liftToGround
                }

                // Unique name — FIX: use cached mainAnchor instead of scene DFS
                let baseName   = customName ?? item.modelFileName
                let uniqueName: String = {
                    guard let anchor = mainAnchor else { return baseName }
                    let existing = anchor.children.filter {
                        $0.name == baseName || $0.name.hasPrefix(baseName + "_")
                    }.count
                    return existing == 0 ? baseName : "\(baseName)_\(existing + 1)"
                }()

                entity.name     = uniqueName
                entity.position = [spawnX, finalY, spawnZ]

                entity.components.set(CategoryComponent(toolType: toolType))
                entity.components.set(EntityIDComponent(id: UUID()))
                entity.generateCollisionShapes(recursive: true)
                entity.components.set(InputTargetComponent())

                if item.title.lowercased() == "light" || item.modelFileName == "Spotlight" {
                    addRealLightToModel(entity)
                } else if item.title.lowercased() == "light" || item.modelFileName == "LED Panel" {
                    addLEDPanel(to: entity)
                } else if item.title.lowercased() == "lantern" || item.modelFileName == "Lantern" {
                    addLantern(to: entity)
                }

                // FIX: use cached mainAnchor
                if let anchor = mainAnchor {
                    anchor.addChild(entity)
                    refreshSidebarContent()
                }
            } catch {
                print("Failed to load \(item.modelFileName): \(error)")
            }
        }
    }

    // MARK: - Undo / Redo

    func applySnapshot(_ snapshot: SceneSnapshot) {
        guard let anchor = mainAnchor else { return }

        // Remove entities that aren't in the snapshot
        for entity in anchor.children {
            guard entity.name != "Grid", entity.name != "EditorCamera",
                  entity.name != "PathContainer" else { continue }  // FIX 6
            if snapshot.entityTransforms[entity.name] == nil {
                entity.removeFromParent()
            }
        }

        // Restore / update entities in the snapshot
        for (name, transform) in snapshot.entityTransforms {
            if let entity = anchor.findEntity(named: name) {
                entity.transform = transform
            } else {
                restoreEntity(named: name, with: transform)
            }
        }

        refreshSidebarContent()
    }

    func saveCurrentStateToUndo() {
        guard let anchor = mainAnchor else { return }
        var transforms: [String: Transform] = [:]
        for entity in anchor.children {
            guard entity.name != "Grid", entity.name != "EditorCamera",
                  entity.name != "PathContainer" else { continue }  // FIX 6
            transforms[entity.name] = entity.transform
        }
        undoStack.append(SceneSnapshot(entityTransforms: transforms))
        // FIX: Cap undo history to prevent unbounded memory growth
        if undoStack.count > undoLimit { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    // MARK: - Pan gesture

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: arView)

        // ── Arc handle dragging ─────────────────────────────────────────────

        if gesture.state == .began,
           let hit     = arView.entity(at: location),
           let arcComp = hit.components[RotationArcComponent.self],
           let anchor  = mainAnchor,
           let clipIdx = timeline.clips.firstIndex(where: { $0.id == arcComp.clipID }),
           let entity  = anchor.findEntity(named: timeline.clips[clipIdx].entityName)
        {
            saveCurrentStateToUndo()
            draggingArcHandle = hit
            draggingArcClipID = arcComp.clipID
            draggingArcRole   = arcComp.role
            arcDragCentre     = entity.position(relativeTo: anchor)
            arcDragLastAngle  = arcComp.role == .end
                ? timeline.clips[clipIdx].toValue.y
                : timeline.clips[clipIdx].fromValue.y
            return
        }

        if gesture.state == .changed,
           draggingArcHandle != nil,
           let clipID  = draggingArcClipID,
           let role    = draggingArcRole,
           let centre  = arcDragCentre,
           let visual  = activeRotationArcs[clipID],
           let anchor  = mainAnchor,
           let clipIdx = timeline.clips.firstIndex(where: { $0.id == clipID }),
           let entity  = anchor.findEntity(named: timeline.clips[clipIdx].entityName)
        {
            guard let ray = arView.ray(through: location) else { return }
            let planePoint  = entity.position(relativeTo: nil)
            let planeNormal = SIMD3<Float>(0, 1, 0)
            guard let hitWorld = rayPlaneIntersection(
                rayOrigin: ray.origin, rayDirection: ray.direction,
                planePoint: planePoint, planeNormal: planeNormal
            ) else { return }

            let anchorWP = anchor.position(relativeTo: nil)
            let hitLocal = hitWorld - anchorWP
            let offset   = SIMD3<Float>(hitLocal.x - centre.x, 0, hitLocal.z - centre.z)
            guard simd_length(offset) > 0.001 else { return }
            let newAngle = atan2(offset.x, offset.z)

            let lineName = role == .end ? "endLine" : "startLine"
            if let lineRoot = visual.root.findEntity(named: lineName) {
                lineRoot.orientation = simd_quatf(angle: newAngle, axis: [0, 1, 0])
            }

            let old = timeline.clips[clipIdx]
            // FIX: preserve the existing stable clip ID when rebuilding the clip struct
            timeline.clips[clipIdx] = AnimationClip(
                id:         old.id,
                entityName: old.entityName, type: old.type, track: old.track,
                easing:     old.easing, startTime: old.startTime, duration: old.duration,
                fromValue:  role == .end ? old.fromValue : SIMD3<Float>(0, newAngle, 0),
                toValue:    role == .end ? SIMD3<Float>(0, newAngle, 0) : old.toValue,
                motionPath: old.motionPath
            )

            let updated = timeline.clips[clipIdx]
            RotationPathRenderer.updateArcCurveOnly(
                visual:    visual,
                fromAngle: updated.fromValue.y,
                toAngle:   updated.toValue.y)

            arcDragLastAngle = newAngle
            return
        }

        if (gesture.state == .ended || gesture.state == .cancelled),
           draggingArcHandle != nil
        {
            draggingArcHandle = nil
            draggingArcClipID = nil
            draggingArcRole   = nil
            arcDragCentre     = nil
            arcDragLastAngle  = 0
            return
        }

        // ── Gizmo / object dragging ─────────────────────────────────────────

        switch gesture.state {

        case .began:
            // FIX 5: Do NOT call saveCurrentStateToUndo() unconditionally here.
            // Camera-orbit pans (no gizmo/entity hit) would pollute the undo stack
            // with redundant identical snapshots. The call is moved inside each real
            // interaction branch below.
            let hits = arView.hitTest(location)

            if let gizmoHit = hits.first(where: {
                $0.entity.name == "Gizmo_Arrow_Y"   ||
                $0.entity.name == "Gizmo_Plane_XZ"  ||
                $0.entity.parent?.name == "Gizmo_Arrow_Y" ||
                $0.entity.parent?.name == "PlaneHandle"   ||
                $0.entity.name == "xRing" ||
                $0.entity.name == "yRing" ||
                $0.entity.name == "zRing"
            }) {
                saveCurrentStateToUndo()   // FIX 5: only when a real gizmo is hit
                let name       = gizmoHit.entity.name
                let parentName = gizmoHit.entity.parent?.name ?? ""

                if name == "Gizmo_Arrow_Y" || parentName == "Gizmo_Arrow_Y" {
                    activeGizmoPart = .arrowY;  highlightGizmoPart(.arrowY)
                } else if name == "Gizmo_Plane_XZ" || parentName == "PlaneHandle" {
                    activeGizmoPart = .planeXZ; highlightGizmoPart(.planeXZ)
                } else if name == "xRing" {
                    activeGizmoPart = .rotateX; activeRotationAxis = [1, 0, 0]; highlightGizmoPart(.rotateX)
                } else if name == "yRing" {
                    activeGizmoPart = .rotateY; activeRotationAxis = [0, 1, 0]; highlightGizmoPart(.rotateY)
                } else if name == "zRing" {
                    activeGizmoPart = .rotateZ; activeRotationAxis = [0, 0, 1]; highlightGizmoPart(.rotateZ)
                }

                if let handle = activeHandleEntity {
                    dragStartPosition = handle.position(relativeTo: mainAnchor)
                } else {
                    dragStartPosition = selectedEntity?.position
                }
                lastPanLocation  = location
                isDraggingObject = true

                // FIX: Build sibling bounds cache here at drag start (once per drag)
                // so .changed never calls visualBounds inside a per-frame loop.
                buildSiblingBoundsCache()
                return
            }

            // FIX 11: Reuse the existing `hits` from hitTest — don't call arView.entity(at:)
            // for a second independent ray cast on the same location.
            if let hit = hits.first?.entity {
                saveCurrentStateToUndo()   // FIX 5: only when an entity is actually hit
                var root: Entity? = hit
                while let parent = root?.parent, parent.name != "MainAnchor" {
                    root = parent
                }
                if root?.name != "GizmoRoot" { selectedEntity = root }
                activeGizmoPart = .none
            }

        case .changed:
            guard editorMode == .edit else { return }

            if let entity = selectedEntity,
               entity.components[LockComponent.self]?.isLocked == true {
                handleCameraOrbit(gesture)
                return
            }

            guard activeGizmoPart != .none,
                  let startPos = dragStartPosition else {
                handleCameraOrbit(gesture)
                return
            }

            // Rotation rings
            if activeGizmoPart == .rotateX || activeGizmoPart == .rotateY || activeGizmoPart == .rotateZ {
                guard let axis = activeRotationAxis, let selected = selectedEntity else {
                    handleCameraOrbit(gesture)
                    return
                }
                let dx    = Float(location.x - lastPanLocation.x)
                let dy    = Float(location.y - lastPanLocation.y)
                let drag  = abs(dx) > abs(dy) ? dx : -dy
                let angle = drag * 0.01
                guard angle.isFinite else { return }
                let rotation = simd_quatf(angle: angle, axis: axis)
                selected.transform.rotation = simd_normalize(rotation * selected.transform.rotation)
                lastPanLocation = location
                return
            }

            // Move gizmo
            let translation     = gesture.translation(in: arView)
            let isMovingHandle  = activeHandleEntity != nil
            let targetEntity: Entity? = isMovingHandle ? activeHandleEntity : selectedEntity
            guard let target = targetEntity else { return }

            let dist        = simd_distance(target.position(relativeTo: nil), activeCamera.position)
            let sensitivity = max(0.001, 0.001 * dist)
            var newPos      = startPos

            if activeGizmoPart == .arrowY {
                newPos.y = startPos.y - (Float(translation.y) * sensitivity)
            } else if activeGizmoPart == .planeXZ {
                let camOri      = arView.cameraTransform.rotation
                let right       = camOri.act([1, 0, 0])
                let forward     = camOri.act([0, 0, -1])
                let flatForward = simd_normalize(SIMD3<Float>(forward.x, 0, forward.z))
                let flatRight   = simd_normalize(SIMD3<Float>(right.x, 0, right.z))
                let dx          = Float(translation.x) * sensitivity
                let dy          = Float(translation.y) * sensitivity
                let movement    = (flatRight * dx) - (flatForward * dy)
                newPos.x        = startPos.x + movement.x
                newPos.z        = startPos.z + movement.z
            }

            if isMovingHandle {
                if let anchor = mainAnchor {
                    target.setPosition(newPos, relativeTo: anchor)
                    gizmoRoot?.position = target.position(relativeTo: anchor)
                }
                if let handleComp = target.components[MotionPathHandleComponent.self],
                   let clipIndex = timeline.clips.firstIndex(where: { $0.id == handleComp.clipID }),
                   var path = timeline.clips[clipIndex].motionPath,
                   let visual = activeMotionPaths[handleComp.clipID] {
                    updateMotionPathHandle(
                        target: target, newPos: newPos,
                        clipIndex: clipIndex, path: &path, visual: visual
                    )
                }
            } else {
                target.position = clampPositionAvoidingOverlap(
                    entity: target, proposedPosition: newPos
                )
                updateGizmoPosition()
            }

        case .ended, .cancelled:
            // If the user just moved or rotated a scene camera, refresh its preview
            // so the cell reflects the new position/orientation.
            if let movedEntity = selectedEntity,
               movedEntity.components[CategoryComponent.self]?.toolType == .camera,
               let idx = sceneCameraItems.firstIndex(where: { $0.cameraRoot === movedEntity }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.capturePreview(forCameraAt: idx)
                }
            }

            dragStartPosition    = nil
            initialRotation      = nil
            activeGizmoPart      = .none
            activeRotationAxis   = nil
            isDraggingObject     = false
            activeHandleEntity   = nil
            cachedSiblingBounds  = []   // release cached bounds
            pathRebuildFrameCount = 0   // reset throttle counter between drags
            resetGizmoColors()

        default:
            break
        }
    }

    // MARK: - Motion path handle update (extracted to keep handlePan readable)

    private func updateMotionPathHandle(
        target: Entity,
        newPos: SIMD3<Float>,
        clipIndex: Int,
        path: inout BezierMotionPath,
        visual: MotionPathVisual
    ) {
        switch target.name {
        case "path.start":
            let delta = newPos - path.start
            path.start    += delta; path.control1 += delta
            path.control2 += delta; path.end      += delta

            if clipIndex > 0,
               timeline.clips[clipIndex - 1].entityName == timeline.clips[clipIndex].entityName,
               var prevPath = timeline.clips[clipIndex - 1].motionPath {
                let oldVecP = prevPath.end - prevPath.start
                let oldLenP = simd_length(oldVecP)
                prevPath.end = path.start
                let newVecP = prevPath.end - prevPath.start
                let newLenP = simd_length(newVecP)
                if oldLenP > 0.0001 && newLenP > 0.0001 {
                    let oPx = simd_normalize(oldVecP)
                    let upP: SIMD3<Float> = abs(oPx.y) < 0.99 ? [0,1,0] : [1,0,0]
                    let oPz = simd_normalize(simd_cross(oPx, upP))
                    let oPy = simd_cross(oPz, oPx)
                    let nPx = simd_normalize(newVecP)
                    let nPz = simd_normalize(simd_cross(nPx, upP))
                    let nPy = simd_cross(nPz, nPx)
                    func reframePrev(_ p: SIMD3<Float>) -> SIMD3<Float> {
                        let v = p - prevPath.start
                        let tx = simd_dot(v, oPx) / oldLenP
                        let ty = simd_dot(v, oPy) / oldLenP
                        let tz = simd_dot(v, oPz) / oldLenP
                        return prevPath.start + (nPx*tx + nPy*ty + nPz*tz) * newLenP
                    }
                prevPath.control1 = reframePrev(prevPath.control1)
                prevPath.control2 = reframePrev(prevPath.control2)
            }
            // FIX 10: Throttle cascade arc-length rebuilds to every 4 frames.
            // The primary path always rebuilds (below) so spatial accuracy is preserved
            // for the dragged handle; the adjacent-clip cascade only needs periodic updates.
            if pathRebuildFrameCount % 4 == 0 {
                prevPath.rebuildArcLengthTable()
            }
            timeline.clips[clipIndex - 1].motionPath = prevPath
                if let prevVisual = activeMotionPaths[timeline.clips[clipIndex - 1].id] {
                    prevVisual.root.position = prevPath.start
                    prevVisual.control1Handle.position = prevPath.control1 - prevPath.start
                    prevVisual.control2Handle.position = prevPath.control2 - prevPath.start
                    prevVisual.endHandle.position      = prevPath.end - prevPath.start
                    if let pathMesh = prevVisual.root.findEntity(named: "MotionPath") as? ModelEntity {
                        updatePathMeshThrottled(entity: pathMesh, path: prevPath)
                    }
                }
            }

            let thisClip = timeline.clips[clipIndex]
            for nextIdx in (clipIndex + 1)..<timeline.clips.count {
                let nextClip = timeline.clips[nextIdx]
                guard nextClip.entityName == thisClip.entityName,
                      var nextPath = nextClip.motionPath else { continue }
                let delta2 = newPos - path.start + (newPos - path.start)
                nextPath.start    += delta2; nextPath.end      += delta2
                nextPath.control1 += delta2; nextPath.control2 += delta2
                // FIX 10: Throttle cascade rebuild
                if pathRebuildFrameCount % 4 == 0 {
                    nextPath.rebuildArcLengthTable()
                }
                timeline.clips[nextIdx].motionPath = nextPath
                if let nextVisual = activeMotionPaths[timeline.clips[nextIdx].id] {
                    nextVisual.root.position               = nextPath.start
                    nextVisual.startHandle?.position       = .zero
                    nextVisual.control1Handle.position     = nextPath.control1 - nextPath.start
                    nextVisual.control2Handle.position     = nextPath.control2 - nextPath.start
                    nextVisual.endHandle.position          = nextPath.end - nextPath.start
                    if let pathMesh = nextVisual.root.findEntity(named: "MotionPath") as? ModelEntity {
                        updatePathMeshThrottled(entity: pathMesh, path: nextPath)
                    }
                }
            }

        case "path.c1":
            path.control1 = newPos

        case "path.c2":
            path.control2 = newPos

        case "path.end":
            let oldEnd  = path.end
            let oldVec2 = path.end - path.start
            let oldLen2 = simd_length(oldVec2)
            path.end    = newPos
            let newVec2 = path.end - path.start
            let newLen2 = simd_length(newVec2)
            if oldLen2 > 0.0001 && newLen2 > 0.0001 {
                let oX  = simd_normalize(oldVec2)
                let up2: SIMD3<Float> = abs(oX.y) < 0.99 ? [0,1,0] : [1,0,0]
                let oZ  = simd_normalize(simd_cross(oX, up2))
                let oY  = simd_cross(oZ, oX)
                let nX  = simd_normalize(newVec2)
                let nZ  = simd_normalize(simd_cross(nX, up2))
                let nY  = simd_cross(nZ, nX)
                func reframe2(_ p: SIMD3<Float>) -> SIMD3<Float> {
                    let v  = p - path.start
                    let tx = simd_dot(v, oX) / oldLen2
                    let ty = simd_dot(v, oY) / oldLen2
                    let tz = simd_dot(v, oZ) / oldLen2
                    return path.start + (nX*tx + nY*ty + nZ*tz) * newLen2
                }
                path.control1 = reframe2(path.control1)
                path.control2 = reframe2(path.control2)
            }
            let endDelta   = path.end - oldEnd
            let thisClipE  = timeline.clips[clipIndex]
            for nextIdx in (clipIndex + 1)..<timeline.clips.count {
                let nextClip = timeline.clips[nextIdx]
                guard nextClip.entityName == thisClipE.entityName,
                      var nextPath = nextClip.motionPath else { continue }
                nextPath.start    += endDelta; nextPath.end      += endDelta
                nextPath.control1 += endDelta; nextPath.control2 += endDelta
                // FIX 10: Throttle cascade rebuild
                if pathRebuildFrameCount % 4 == 0 {
                    nextPath.rebuildArcLengthTable()
                }
                timeline.clips[nextIdx].motionPath = nextPath
                if let nextVisual = activeMotionPaths[timeline.clips[nextIdx].id] {
                    nextVisual.root.position           = nextPath.start
                    nextVisual.startHandle?.position   = .zero
                    nextVisual.control1Handle.position = nextPath.control1 - nextPath.start
                    nextVisual.control2Handle.position = nextPath.control2 - nextPath.start
                    nextVisual.endHandle.position      = nextPath.end - nextPath.start
                    if let pathMesh = nextVisual.root.findEntity(named: "MotionPath") as? ModelEntity {
                        updatePathMeshThrottled(entity: pathMesh, path: nextPath)
                    }
                }
            }

        default:
            break
        }

        path.rebuildArcLengthTable()
        timeline.clips[clipIndex].motionPath = path
        visual.root.position               = path.start
        visual.startHandle?.position       = .zero
        visual.control1Handle.position     = path.control1 - path.start
        visual.control2Handle.position     = path.control2 - path.start
        visual.endHandle.position          = path.end - path.start
        if let pathMesh = visual.root.findEntity(named: "MotionPath") as? ModelEntity {
            updatePathMeshThrottled(entity: pathMesh, path: path)
        }
    }

    // MARK: - Long press (path / arc context menus)

    @objc func handlePathLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let location = gesture.location(in: arView)
        guard let hit = arView.entity(at: location) else { return }

        // Arc tip
        if let arcComp = hit.components[RotationArcComponent.self],
           let arcRoot = activeRotationArcs[arcComp.clipID]?.root {
            showRotationArcContextMenu(clipID: arcComp.clipID, arcRoot: arcRoot)
            return
        }

        // Arc curve / shaft — walk up to arcRoot
        var walkArc: Entity? = hit
        while let e = walkArc {
            if e.name.hasPrefix("RotationArc_") {
                let uuidStr = e.name.replacingOccurrences(of: "RotationArc_", with: "")
                if let clipID = UUID(uuidString: uuidStr) {
                    showRotationArcContextMenu(clipID: clipID, arcRoot: e)
                }
                return
            }
            walkArc = e.parent
        }

        // Motion path handle
        if let handle = hit.components[MotionPathHandleComponent.self],
           let pathRoot = hit.parent {
            showPathContextMenu(clipID: handle.clipID, pathRoot: pathRoot)
            return
        }

        // Motion path curve
        if hit.name == "MotionPath",
           let pathRoot = hit.parent,
           let handle   = pathRoot.children
               .compactMap({ $0.components[MotionPathHandleComponent.self] }).first {
            showPathContextMenu(clipID: handle.clipID, pathRoot: pathRoot)
        }
    }
}

// MARK: - Collision Prevention Helper

extension CanvasViewController {

    /// Builds a snapshot of sibling bounds at drag start.
    /// Called once in handlePan(.began) so .changed never traverses the scene graph per frame.
    private func buildSiblingBoundsCache() {
        guard let anchor = mainAnchor else { cachedSiblingBounds = []; return }
        cachedSiblingBounds = anchor.children.compactMap { sibling in
            guard sibling !== selectedEntity,
                  sibling.name != "GizmoRoot",
                  !sibling.children.isEmpty || sibling is ModelEntity
            else { return nil }
            return (sibling, sibling.visualBounds(relativeTo: nil))
        }
    }

    /// Clamps `proposedPosition` to avoid overlapping any sibling entity.
    /// Uses `cachedSiblingBounds` so this is O(n) with no extra scene-graph work.
    func clampPositionAvoidingOverlap(
        entity: Entity,
        proposedPosition: SIMD3<Float>
    ) -> SIMD3<Float> {
        guard !cachedSiblingBounds.isEmpty else { return proposedPosition }

        // Temporarily move entity to proposed position to compute its bounds there
        let originalPosition = entity.position
        entity.position      = proposedPosition
        let selfBounds       = entity.visualBounds(relativeTo: nil)
        entity.position      = originalPosition

        var resolved = proposedPosition

        for (_, otherBounds) in cachedSiblingBounds {
            let overlapX = selfBounds.max.x > otherBounds.min.x && selfBounds.min.x < otherBounds.max.x
            let overlapY = selfBounds.max.y > otherBounds.min.y && selfBounds.min.y < otherBounds.max.y
            let overlapZ = selfBounds.max.z > otherBounds.min.z && selfBounds.min.z < otherBounds.max.z
            guard overlapX && overlapY && overlapZ else { continue }

            let penRight  = selfBounds.max.x  - otherBounds.min.x
            let penLeft   = otherBounds.max.x  - selfBounds.min.x
            let penTop    = selfBounds.max.y  - otherBounds.min.y
            let penBottom = otherBounds.max.y  - selfBounds.min.y
            let penFront  = selfBounds.max.z  - otherBounds.min.z
            let penBack   = otherBounds.max.z  - selfBounds.min.z
            let minPen    = min(penRight, penLeft, penTop, penBottom, penFront, penBack)

            switch minPen {
            case penRight:  resolved.x -= penRight
            case penLeft:   resolved.x += penLeft
            case penTop:    resolved.y -= penTop
            case penBottom: resolved.y += penBottom
            case penFront:  resolved.z -= penFront
            default:        resolved.z += penBack
            }
        }

        return resolved
    }
}

// MARK: - SIMD4 helper

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}
