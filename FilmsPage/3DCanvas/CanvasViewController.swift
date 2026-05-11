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
    case walk
    case zoom
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
    case fov
}

// MARK: - AnimationClip
// FIX: Added `id` parameter to the designated initialiser so clips restored from
// persistence can carry their original stable UUID. All new clips still get a
// fresh UUID via the default argument.

struct AnimationClip: Identifiable, Codable {

    let id: UUID
    let entityName: String
    let entityID: UUID?
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
        entityID: UUID? = nil,
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
        self.entityID   = entityID
        self.type       = type
        self.track      = track
        self.easing     = easing
        self.startTime  = startTime
        self.duration   = duration
        self.fromValue  = fromValue
        self.toValue    = toValue
        self.motionPath = motionPath
    }

    /// UUID-preserving copy — use when mutating angle/timing in-place so that
    /// activeMotionPaths / activeRotationArcs dictionary lookups keep working.
    init(
        preservingID existing: AnimationClip,
        fromValue: SIMD3<Float>? = nil,
        toValue: SIMD3<Float>? = nil,
        startTime: Float? = nil,
        duration: Float? = nil,
        motionPath: BezierMotionPath? = nil,
        entityID: UUID? = nil
    ) {
        self.id         = existing.id
        self.entityName = existing.entityName
        self.entityID   = entityID ?? existing.entityID
        self.type       = existing.type
        self.track      = existing.track
        self.easing     = existing.easing
        self.startTime  = startTime  ?? existing.startTime
        self.duration   = duration   ?? existing.duration
        self.fromValue  = fromValue  ?? existing.fromValue
        self.toValue    = toValue    ?? existing.toValue
        self.motionPath = motionPath ?? existing.motionPath
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

    // MARK: - NEW Properties

    //Ata
    var activeRotationAxis: SIMD3<Float>?
    var lastPanLocation: CGPoint = .zero
    var lastDragPoint: SIMD3<Float>?
    /// Non-nil when the gizmo is sitting on a path handle instead of a scene entity
    var activeHandleEntity: Entity?
    
    
    var currentSceneObject: Scene?
    var sceneName: String = "Untitled Scene"
    var filmName: String?
    var sequenceName: String?
    var sceneNotes: String = ""
    var lastEditedDate: Date = Date()
    var sceneImageName: String?
    var currentSceneID: UUID?
    
    // FIX: Track whether the scene has been loaded to prevent reloading it
    // multiple times when returning from navigation (e.g., shot breakdown).
    // Reset to false when exiting the scene.
    // Internal access (not private) so extensions can access it
    var hasSceneBeenLoaded: Bool = false

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
    
    
    // Camera State
    var yaw: Float = 0.5
    var pitch: Float = 0.5
    var distance: Float = 5.0
    var cameraTarget = SIMD3<Float>(0, 0, 0)
    /// Snapshot of yaw at the start of a twist gesture — used for accumulated yaw rotation
    var initialCameraYaw: Float? = nil

    // ── Camera framing animation state ────────────────────────────────────────
    var framingDisplayLink: CADisplayLink? = nil
    var framingStartTarget: SIMD3<Float>   = .zero
    var framingEndTarget:   SIMD3<Float>   = .zero
    var framingStartDist:   Float          = 5.0
    var framingEndDist:     Float          = 5.0
    var framingStartTime:   CFTimeInterval = 0
    var framingDuration:    CFTimeInterval = 0.35
    
    //camera system
    var editorCamera: PerspectiveCamera!
    var activeCamera: PerspectiveCamera!
    
    var isCameraPanelExpanded: Bool = false
    
    var sceneCameras: [PerspectiveCamera] = []
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
    weak var colorPickerTargetEntity: ModelEntity?

     struct SceneCameraItem {
         let id: UUID          // Unique identifier for backend distinction
         let camera: PerspectiveCamera
         let cameraRoot: Entity
         var previewImage: UIImage?   // snapshot taken from this camera's POV; nil until first capture
         /// Human-readable name shown in the sidebar and preview panel, e.g. "Camera 1".
         /// Assigned once at spawn time from the monotonically increasing `cameraCounter`
         /// so it never drifts after deletions or reloads.
         let displayName: String
     }

    var sceneCameraItems: [SceneCameraItem] = []
    /// Monotonically increasing counter — never decremented on delete, so "Camera 3"
    /// is never reused for a newly spawned camera even if Camera 2 was deleted.
    var cameraCounter: Int = 0
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

    //  PLACE THIS AT CLASS LEVEL (NOT INSIDE ANOTHER FUNC)

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

     var selectedPathClipID: UUID?
     
     // ISSUE 4 & 5: Stored constraint references for camera panel layout
     var panelTrailingConstraint: NSLayoutConstraint?
     var panelHeightConstraint: NSLayoutConstraint?
     var panelWidthConstraint: NSLayoutConstraint?
     var topControlsHeight: CGFloat = 56  // Store computed toolbar height

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

    // Camera preview panel — snapshots keyed by camera ObjectIdentifier
    var cameraPreviewSnapshots: [ObjectIdentifier: UIImage] = [:]

    // Which rotation arc clip is currently selected (for long-press context menu).
    var selectedArcClipID: UUID?

    // Arc handle drag state — self-contained, bypasses gizmo system.
    var draggingArcHandle:  Entity?
    var draggingArcClipID:  UUID?
    var draggingArcRole:    RotationArcComponent.Role?
    var arcDragLastAngle:   Float = 0
    var arcDragCentre:      SIMD3<Float>?

    // MARK: - Animation Fix helpers
    var lastUndoTime: TimeInterval = 0
    var pathRebuildFrameCount: Int = 0
    var timelineEntityCache: [String: Entity] = [:]
    var baseTransforms: [String: Transform] = [:]
    var baseFOVs: [String: Float] = [:]
    var activeWalkControllers: [String: AnimationPlaybackController] = [:]

    // MARK: - Editor Mode
    var editorMode: EditorMode = .edit

    enum EditorMode { case edit; case timeline }

    var animationPanel: UIStackView!

    enum InteractionMode { case move; case rotate; case none }
    var interactionMode: InteractionMode = .move

    var backgroundImageCache: [String: UIImage] = [:]

    // MARK: - Geometry components

    // FIX: BackgroundComponent now carries a `cachedImage` so the persistence
    // service can extract the texture without a round-trip through TextureResource.
    struct BackgroundComponent: Component {
        var width: Float
        var height: Float
        var cachedImage: UIImage?   // retained reference to the original UIImage
        var textureResource: TextureResource?  // FIX: Track GPU texture for cleanup
    }

    /// Tracks which 3D model asset (e.g. "cam1") provides the camera's visual
    /// representation. Persisted so the exact same model is restored on load.
    struct CameraVisualComponent: Component {
        var modelName: String          // e.g. "cam1"
        var displayName: String        // e.g. "DSLR"
    }

    var pathEditToolbar: UIView?

    struct WallComponent: Component {
        var width: Float = 1.5
        var height: Float = 1.2
        var thickness: Float = 0.05
        var colorR: Float = 0.83
        var colorG: Float = 0.83
        var colorB: Float = 0.83
        var colorA: Float = 1.0

        /// Cinematic material configuration. nil = legacy color-only mode.
        var materialConfig: CinematicMaterialConfig?

        var uiColor: UIColor {
            get { UIColor(red: CGFloat(colorR), green: CGFloat(colorG), blue: CGFloat(colorB), alpha: CGFloat(colorA)) }
            set {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                newValue.getRed(&r, green: &g, blue: &b, alpha: &a)
                colorR = Float(r); colorG = Float(g); colorB = Float(b); colorA = Float(a)
            }
        }
    }

    struct GroundComponent: Component {
        var width: Float
        var depth: Float
        var colorR: Float = 0.33
        var colorG: Float = 0.33
        var colorB: Float = 0.33
        var colorA: Float = 1.0

        /// Cinematic material configuration. nil = legacy color-only mode.
        var materialConfig: CinematicMaterialConfig?

        var uiColor: UIColor {
            get { UIColor(red: CGFloat(colorR), green: CGFloat(colorG), blue: CGFloat(colorB), alpha: CGFloat(colorA)) }
            set {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                newValue.getRed(&r, green: &g, blue: &b, alpha: &a)
                colorR = Float(r); colorG = Float(g); colorB = Float(b); colorA = Float(a)
            }
        }
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
     
     override func viewDidLayoutSubviews() {
         super.viewDidLayoutSubviews()
         // ISSUE 4 & 5: Update camera panel size on layout changes
         updateCameraPanelLayout()
     }

     override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
         super.viewWillTransition(to: size, with: coordinator)
         coordinator.animate(alongsideTransition: { _ in
             // ISSUE 4 & 5: Recompute panel layout on rotation
             self.updateCameraPanelLayout()
             self.cameraCollectionView?.collectionViewLayout.invalidateLayout()
         })
     }
     
     private func updateCameraPanelLayout() {
         // ISSUE 4 & 5: Recompute sizes based on current device and orientation
         let isLarge = isLargeIPad
         let newPanelWidth: CGFloat = isLarge ? 200 : 176
         let availableHeight = view.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom - topControlsHeight
         let newMaxHeight = min(availableHeight * 0.55, isLarge ? 420 : 340)
         let cellHeight = newPanelWidth * 0.75
         
         // Update stored constraints
         panelWidthConstraint?.constant = newPanelWidth
         panelHeightConstraint?.constant = newMaxHeight
         
         // Update collection view layout item size
         if let layout = cameraCollectionView?.collectionViewLayout as? UICollectionViewFlowLayout {
             layout.itemSize = CGSize(width: newPanelWidth - 16, height: cellHeight)
         }
     }


    // MARK: - Preview ARView Cleanup
    
    /// Cleans up all cloned entities in the offscreen preview ARView.
    /// Called when loading a new scene to prevent memory accumulation from
    /// orphaned preview clones.
    @MainActor
    func cleanupPreviewARView() {
        // Access the previewARView computed property from the Camera extension
        // to clean up any clones that accumulated during preview updates
        let previewView = self.previewARView
        
        print("🧹 Cleaning up preview ARView...")
        previewView.scene.anchors.forEach { anchor in
            anchor.children.forEach { $0.removeFromParent() }
            anchor.removeFromParent()
        }
    }

     deinit {
         // Safety net: ensure the display link is gone even if viewWillDisappear was skipped.
         displayLink?.invalidate()
         displayLink = nil
         
         // FIX: Safety cleanup - evict scene from cache if commitExit() wasn't called normally.
         // This catches edge cases where the VC is dismissed abnormally (e.g., navigation pop),
         // ensuring the scene is cleared from the cache to prevent memory bloat.
         if let sceneID = currentSceneID {
             ScenePersistenceService.shared.evictScene(sceneID)
             print("🗑️ Safety deinit: Scene \(sceneID.uuidString.prefix(8))... evicted from cache")
         }
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
//        let currentID =
//            self.currentSceneID ?? self.currentSceneObject?.id ?? UUID()
//
//        // Handle Template check as you currently do
//        let isTemplate = ScenesDataStore.shared.currentTemplates.contains {
//            $0.id == currentID
//        }
//
//        if isTemplate {
//            ScenesDataStore.shared.saveTemplateNote(
//                id: currentID,
//                notes: self.sceneNotes
//            )
//        } else {
//            // 1. Update Recent Scenes (Global)
//            let updatedRecent = ScenesModel(
//                id: currentID,
//                name: self.sceneName,
//                image: self.sceneImageName ?? "Image",
//                notes: self.sceneNotes
//            )
//            ScenesDataStore.shared.addToRecent(scene: updatedRecent)
//
//            if var projectScene = self.currentSceneObject {
//                projectScene.name = self.sceneName
//            }
//        }
//
//        self.dismiss(animated: true)
    }

    // MARK: - Setup

    func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Use non-AR mode so PerspectiveCamera entities in the scene control
        // the viewpoint — without this, ARKit owns the camera and
        // camera.isEnabled = true has no visible effect.
        arView.cameraMode = .nonAR
        // Stop RealityKit auto-starting its own AR session (prevents background grid artefact)
        arView.automaticallyConfigureSession = false
        // FIX: cameraMode must be .nonAR so RealityKit uses the PerspectiveCamera
        // nodes in the scene (editorCamera / sceneCameras) instead of the device
        // camera.  Without this line the default .ar mode ignores all
        // PerspectiveCamera entities and renders from a zero/identity transform,
        // making every entity invisible or disoriented on load.
        arView.cameraMode = .nonAR
        arView.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableHDR]
        arView.debugOptions  = []
        arView.environment.background = .color(.white)
        view.addSubview(arView)
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

        // Light count guard — RealityKit allows maximum 8 dynamic lights per scene
        if toolType == .light {
            let activeLights = mainAnchor?.children.filter {
                $0.components[LightConfigComponent.self] != nil
            }.count ?? 0
            guard activeLights < 8 else {
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title:   "Light Limit Reached",
                        message: "RealityKit supports a maximum of 8 lights per scene.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
                return
            }
        }

        Task {
            do {
                let checkName = (customName ?? item.modelFileName).lowercased()

                if checkName.contains("ground") {
                    if isRestoring {
                        // Restoring from save: use legacy path
                        if let spawnedEntity = spawnGround() {
                            refreshSidebarContent()
                        }
                    } else {
                        // New creation: show cinematic creation sheet
                        DispatchQueue.main.async { [weak self] in
                            self?.presentGroundCreationSheet()
                        }
                    }
                    return
                }
                if checkName.contains("wall") || item.modelFileName == "cube" {
                    if isRestoring {
                        // Restoring from save: use legacy path
                        if let spawnedEntity = spawnWall() {
                            refreshSidebarContent()
                        }
                    } else {
                        // New creation: show cinematic creation sheet
                        DispatchQueue.main.async { [weak self] in
                            self?.presentWallCreationSheet()
                        }
                    }
                    return
                }
                if checkName.contains("scenecamera") || item.modelFileName == "cam1" { spawnSceneCamera(modelName: item.modelFileName, displayName: item.title); return }
                if item.isBackground { spawnBackgroundPlane(item); return }

                // ── Procedural light — no .usdz to load ──────────────────────
                if toolType == .light, let kind = item.proceduralKind {
                    let entity = buildProceduralLight(
                        kind: kind,
                        colorTemp: LightsDataStore.find(byProceduralKind: kind)?.defaultConfig.colorTemperatureKelvin ?? 5600
                    )

                    // Unique name
                    let baseName = customName ?? item.title
                    let uniqueName: String = {
                        guard let anchor = mainAnchor else { return baseName }
                        let existing = anchor.children.filter {
                            $0.name == baseName || $0.name.hasPrefix(baseName + "_")
                        }.count
                        return existing == 0 ? baseName : "\(baseName)_\(existing + 1)"
                    }()
                    entity.name = uniqueName

                    // Position — procedural geometry is in world metres, no normalisation needed
                    let randomX = Float.random(in: -1...1)
                    let randomZ = Float.random(in: -1...1)
                    let verticalOffset: Float = (kind == .practicalLantern) ? 0.25 : 0.5
                    entity.position = [randomX, verticalOffset, randomZ]

                    entity.components.set(CategoryComponent(toolType: .light))
                    entity.components.set(InputTargetComponent())

                    // Attach light with full config
                    if let lightItem = LightsDataStore.find(byProceduralKind: kind) {
                        let config = LightConfigComponent.from(
                            lightItem.defaultConfig,
                            kind: lightItem.lightKind,
                            proceduralKind: kind
                        )
                        attachLight(to: entity, config: config)
                    }

                    if let anchor = mainAnchor {
                        anchor.addChild(entity)
                        self.refreshSidebarContent()
                    }
                    return
                }

                // FIX: Use the model cache for spawned entities to track memory and enable eviction.
                // This prevents memory accumulation when creating scenes with many of the same model.
                let entity: Entity
                if let currentID = currentSceneID,
                   let cachedEntity = ScenePersistenceService.shared.getCachedModel(item.modelFileName, for: currentID) {
                    // Cache hit: clone the cached entity
                    entity = cachedEntity.clone(recursive: true)
                } else {
                    // Cache miss: load, cache, then clone
                    let loaded = try await Entity(named: item.modelFileName)
                    if let currentID = currentSceneID {
                        ScenePersistenceService.shared.cacheSpawnedModel(loaded, item.modelFileName, for: currentID)
                    }
                    entity = loaded.clone(recursive: true)
                }

                // Normalise
                let bounds = entity.visualBounds(relativeTo: nil)
                let maxDim = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                if maxDim > 0.0001 {
                    entity.scale = SIMD3(repeating: 1.0 / maxDim)
                }

                // Prop-specific scales
                var verticalOffset: Float = 0.0
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

                // Position — compute from CLEAN bounds BEFORE attachLight adds children
                let randomX    = Float.random(in: -1...1)
                let randomZ    = Float.random(in: -1...1)
                let finalBounds = entity.visualBounds(relativeTo: nil)
                let liftToGround = -finalBounds.min.y
                let finalY     = verticalOffset > 0 ? verticalOffset : liftToGround

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
                entity.position = [randomX, finalY, randomZ]

                entity.components.set(CategoryComponent(toolType: toolType))

                // Stamp pose info so the action menu can gate Walk to standing poses only.
                if toolType == .character {
                    entity.components.set(CharacterPoseComponent(modelFileName: item.modelFileName))
                }
                
                entity.generateCollisionShapes(recursive: true)
                entity.components.set(InputTargetComponent())

                // Light attachment — AFTER position is set from clean bounds.
                // attachLight adds children that would corrupt visualBounds if called before.
                if toolType == .light,
                   let lightItem = LightsDataStore.find(byModelFileName: item.modelFileName) {
                    let config = LightConfigComponent.from(lightItem.defaultConfig, kind: lightItem.lightKind)
                    attachLight(to: entity, config: config)
                }

                // FIX: use cached mainAnchor
                if let anchor = mainAnchor {
                    anchor.addChild(entity)
                    // Stop Mixamo's baked auto-animation on spawn.
                    // Walk clips start it explicitly via applyWalkToEntity.
                    if !entity.availableAnimations.isEmpty {
                        let ctrl = entity.playAnimation(
                            entity.availableAnimations[0].repeat(count: 1),
                            transitionDuration: 0,
                            startsPaused: true
                        )
                        ctrl.pause()
                    }
                    self.refreshSidebarContent()
                }            } catch {
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



        // .began — detect arc tip using hitTest (collision-based, works in non-AR mode)
        if gesture.state == .began {
            let hitResults = arView.hitTest(location)
            if let hit     = hitResults.first(where: { $0.entity.components[RotationArcComponent.self] != nil })?.entity,
               let arcComp = hit.components[RotationArcComponent.self],
               let anchor  = arView.scene.findEntity(named: "MainAnchor"),
               let clipIdx = timeline.clips.firstIndex(where: { $0.id == arcComp.clipID }),
               let entity  = arView.scene.findEntity(named: timeline.clips[clipIdx].entityName)
            {
                saveCurrentStateToUndo()
                draggingArcHandle = hit
                draggingArcClipID = arcComp.clipID
                draggingArcRole   = arcComp.role
                arcDragCentre     = entity.position(relativeTo: anchor)

                // Compute the raw atan2 angle of the finger on the disc right now.
                // This becomes the reference; subsequent frames accumulate deltas
                // so the handle can travel past ±180° without wrapping.
                let clip   = timeline.clips[clipIdx]
                let axis   = RotationPathRenderer.axisOf(clip)
                let arcWorldCentre = visual_arcCentre(clip: clip, entity: entity)
                guard let ray0 = arView.ray(through: location),
                      let hw0  = rayPlaneIntersection(
                          rayOrigin: ray0.origin, rayDirection: ray0.direction,
                          planePoint: arcWorldCentre, planeNormal: axis.planeNormal
                      ) else { return }
                arcDragLastAngle = RotationPathRenderer.angleOnDisc(
                    worldPoint: hw0, arcCentre: arcWorldCentre, axis: axis)
                return
            }
        }

        // .changed — accumulated-angle drag: supports >180° and multi-turn
        if gesture.state == .changed,
           draggingArcHandle != nil,
           let clipID  = draggingArcClipID,
           let role    = draggingArcRole,
           let visual  = activeRotationArcs[clipID],
           let anchor  = mainAnchor,
           let clipIdx = timeline.clips.firstIndex(where: { $0.id == clipID }),
           let entity  = anchor.findEntity(named: timeline.clips[clipIdx].entityName)
        {
            let clip       = timeline.clips[clipIdx]
            let axis       = RotationPathRenderer.axisOf(clip)
            let arcCentreW = entity.position(relativeTo: nil)  // world-space arc centre

            // Cast ray onto the arc's plane
            guard let ray = arView.ray(through: location),
                  let hitWorld = rayPlaneIntersection(
                      rayOrigin: ray.origin, rayDirection: ray.direction,
                      planePoint: arcCentreW, planeNormal: axis.planeNormal
                  ) else { return }

            // Raw atan2 angle of finger on disc (-π…+π)
            let rawAngle = RotationPathRenderer.angleOnDisc(
                worldPoint: hitWorld, arcCentre: arcCentreW, axis: axis)

            // Compute shortest angular delta from last frame, then accumulate.
            // This allows the total to exceed ±π (multi-turn support).
            var delta = rawAngle - arcDragLastAngle
            if delta >  .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }

            let currentTotal = RotationPathRenderer.totalRadiansOf(clip)
            let currentStart = RotationPathRenderer.startAngleOf(clip)

            switch role {

            case .end:
                // End handle: totalRadians changes, startAngle is fixed.
                let newTotal = currentTotal + delta
                RotationPathRenderer.updateEndAngle(
                    visual: visual, startAngle: currentStart, totalRadians: newTotal)
                timeline.clips[clipIdx] = AnimationClip(
                    preservingID: clip,
                    fromValue: axis.simdAxis,
                    toValue:   SIMD3<Float>(newTotal, currentStart, 0)
                )

            case .start:
                // Start handle: startAngle shifts, totalRadians stays constant so
                // the arc span (and the actual rotation during playback) is unchanged.
                // The end handle rides along — only the visual reference rotates.
                let newStart = currentStart + delta
                RotationPathRenderer.updateStartAngle(
                    visual: visual, startAngle: newStart, totalRadians: currentTotal)
                timeline.clips[clipIdx] = AnimationClip(
                    preservingID: clip,
                    fromValue: axis.simdAxis,
                    toValue:   SIMD3<Float>(currentTotal, newStart, 0)
                )
            }

            arcDragLastAngle = rawAngle
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
                    activeGizmoPart = .rotateX
                    highlightGizmoPart(.rotateX)
                } else if name == "yRing" {
                    activeGizmoPart = .rotateY
                    highlightGizmoPart(.rotateY)
                } else if name == "zRing" {
                    activeGizmoPart = .rotateZ
                    highlightGizmoPart(.rotateZ)
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

            // 3. ENTITY BODY HIT — select, and if already selected start planeXZ drag
            if let hit = arView.entity(at: location) {
                var root: Entity? = hit
                while let parent = root?.parent, parent.name != "MainAnchor" {
                    root = parent
                }
                if root?.name != "GizmoRoot" {
                    selectedEntity = root
                }
                // If entity is selected (or just became selected) and gizmo is visible,
                // treat body drag as planeXZ so the entity moves with the finger
                if let sel = selectedEntity,
                   gizmoRoot?.isEnabled == true,
                   !(sel.components[LockComponent.self]?.isLocked ?? false) {
                    activeGizmoPart   = .planeXZ
                    dragStartPosition = sel.position
                    isDraggingObject  = true
                    lastPanLocation   = location
                } else {
                    activeGizmoPart = .none
                }
            }

        case .changed:
            guard editorMode == .edit else { return }

            // Lock Check — locked entity: 1-finger drag pans the camera
            if let entity = selectedEntity {
                let isLocked = entity.components[LockComponent.self]?.isLocked ?? false
                if isLocked {
                    let t = gesture.translation(in: arView)
                    panCameraTarget(translation: t)
                    gesture.setTranslation(.zero, in: arView)
                    return
                }
            }

            // Must have a gizmo part grabbed — otherwise 1-finger pans the camera
            guard activeGizmoPart != .none,
                  let startPos = dragStartPosition else {
                let t = gesture.translation(in: arView)
                panCameraTarget(translation: t)
                gesture.setTranslation(.zero, in: arView)
                return
            }

            // Rotation rings
            if activeGizmoPart == .rotateX || activeGizmoPart == .rotateY || activeGizmoPart == .rotateZ {
                guard let selected = selectedEntity,
                      let gizmo   = rotationGizmo else {
                    let t = gesture.translation(in: arView)
                    panCameraTarget(translation: t)
                    gesture.setTranslation(.zero, in: arView)
                    return
                }

                // Look up the ring entity directly and read its current
                // world-space orientation quaternion. The torus mesh is built
                // in the XY plane so its face normal is local [0,0,1].
                // Rotating that by the ring's world quat gives the exact axis
                // the ring is physically lying on right now — even after the
                // entity has been rotated by previous drags.
                let ringName: String
                switch activeGizmoPart {
                case .rotateX: ringName = "xRing"
                case .rotateY: ringName = "yRing"
                default:       ringName = "zRing"
                }

                guard let ring = gizmo.findEntity(named: ringName) else {
                    lastPanLocation = location; return
                }

                let liveAxis = simd_normalize(ring.orientation(relativeTo: nil).act([0, 0, 1]))

                let dx = Float(location.x - lastPanLocation.x)
                let dy = Float(location.y - lastPanLocation.y)
                let drag = abs(dx) > abs(dy) ? dx : -dy
                let angle = -(drag * 0.01)
                guard angle.isFinite else { return }

                // Apply in world space so we never mix coordinate frames.
                let deltaQuat    = simd_quatf(angle: angle, axis: liveAxis)
                let currentWorld = selected.orientation(relativeTo: nil)
                selected.setOrientation(simd_normalize(deltaQuat * currentWorld), relativeTo: nil)
                lastPanLocation = location
                return
            }

            // Move gizmo — per-frame delta, no axis freeze
            //
            // FIX 1 (axis lock): switched from absolute-from-startPos math to per-frame
            // delta using lastPanLocation. Both arrowY and planeXZ now accumulate freely
            // within the same gesture — no more "one direction only" per grab.
            //
            // FIX 2 (handle disconnect): when moving a path handle, pass the entity's
            // true world-space position into updateMotionPathHandle. Bezier path coords
            // are always world-space, so the visual tube root (at path.start) stays
            // locked to the sphere handle throughout the drag.

            let isMovingHandle  = activeHandleEntity != nil
            let targetEntity: Entity? = isMovingHandle ? activeHandleEntity : selectedEntity
            guard let target = targetEntity else { return }

            // Per-frame screen delta (finger movement since the last event)
            let dx2D = Float(location.x - lastPanLocation.x)
            let dy2D = Float(location.y - lastPanLocation.y)

            let worldOrigin = target.position(relativeTo: nil)
            let sensitivityAxis: SIMD3<Float> = (activeGizmoPart == .arrowY) ? [0, 1, 0] : [1, 0, 0]
            var pixelsPerMeter: Float = 200
            if let p0 = arView.project(worldOrigin),
               let p1 = arView.project(worldOrigin + sensitivityAxis) {
                let screenLen = simd_length(SIMD2<Float>(Float(p1.x - p0.x),
                                                          Float(p1.y - p0.y)))
                if screenLen > 1 { pixelsPerMeter = screenLen }
            }
            let metersPerPixel = 1.0 / pixelsPerMeter

            var delta3D = SIMD3<Float>.zero

            if activeGizmoPart == .arrowY {
                // Screen Y up → world Y up (UIKit Y is inverted)
                delta3D.y = -dy2D * metersPerPixel
            } else if activeGizmoPart == .planeXZ {
                let flatRight   = SIMD3<Float>( cos(yaw), 0, -sin(yaw))
                let flatForward = SIMD3<Float>(-sin(yaw), 0, -cos(yaw))
                let dxW = dx2D * metersPerPixel
                let dyW = dy2D * metersPerPixel
                let movement = (flatRight * dxW) - (flatForward * dyW)
                delta3D.x = movement.x
                delta3D.z = movement.z
            }

            // Advance the per-frame baseline NOW so all branches below can return/break safely
            lastPanLocation = location

            // New world position of the target
            var newWorldPos = worldOrigin + delta3D

            // Clamp Y so entity bottom never goes below ground (Y=0)
            // Skip for lights and cameras — they need to float freely in 3D space.
            let skipYClamp: Bool = {
                if let cat = target.components[CategoryComponent.self] {
                    return cat.toolType == .light || cat.toolType == .camera
                }
                return target.name.hasPrefix("SceneCamera") || target.name.contains("Light")
            }()
            if !skipYClamp {
                let clampBounds = target.visualBounds(relativeTo: target)
                let minAllowedY = -clampBounds.min.y
                newWorldPos.y = max(minAllowedY, newWorldPos.y)
            }

            if isMovingHandle {
                target.setPosition(newWorldPos, relativeTo: nil)

                // Reposition gizmo using newWorldPos directly — do NOT read back
                // target.position() here because RealityKit may not propagate the
                // transform in the same frame, returning the stale old position.
                if let anchor = mainAnchor {
                    gizmoRoot?.position = anchor.convert(position: newWorldPos, from: nil)
                }

                // Update drop shadow live so it tracks the handle during drag.
                updateDropShadow(worldPos: newWorldPos)

                // Increment frame counter HERE so the rebuildArcLengthTable throttle
                // guards (% 4 == 0) inside updateMotionPathHandle fire on schedule.
                // Previously the counter only incremented inside updatePathMeshThrottled,
                // AFTER the guards had already evaluated — so they always saw 0 and
                // rebuilt every single frame, causing lag.
                pathRebuildFrameCount += 1

                // Pass newWorldPos directly — same reason as gizmo reposition above.
                if let handleComp = target.components[MotionPathHandleComponent.self],
                   let clipIndex  = timeline.clips.firstIndex(where: { $0.id == handleComp.clipID }),
                   var path       = timeline.clips[clipIndex].motionPath,
                   let visual     = activeMotionPaths[handleComp.clipID] {
                    updateMotionPathHandle(
                        target:    target,
                        newPos:    newWorldPos,
                        clipIndex: clipIndex,
                        path:      &path,
                        visual:    visual
                    )
                }
                // Motion path handle drag is handled above.
                // Rotation arc handles use direct radial drag (see handlePan .began arc block)
                // and never reach this isMovingHandle path.
            } else {
                // Capture world position BEFORE moving so we can compute the true per-frame delta
                let prevWorldPos = target.position(relativeTo: nil)
                target.setPosition(newWorldPos, relativeTo: nil)
                updateGizmoPosition()

                let entityName = target.name
                let frameDelta = newWorldPos - prevWorldPos
                guard simd_length(frameDelta) > 0.00001 else { break }

                // Shift all motion paths by the per-frame delta
                let pathClipIndices = timeline.clips.indices.filter {
                    timeline.clips[$0].entityName == entityName &&
                    timeline.clips[$0].motionPath != nil
                }.sorted { timeline.clips[$0].startTime < timeline.clips[$1].startTime }

                for clipIndex in pathClipIndices {
                    guard var path = timeline.clips[clipIndex].motionPath,
                          let visual = activeMotionPaths[timeline.clips[clipIndex].id]
                    else { continue }
                    path.start    += frameDelta
                    path.control1 += frameDelta
                    path.control2 += frameDelta
                    path.end      += frameDelta
                    path.rebuildArcLengthTable()
                    timeline.clips[clipIndex].motionPath = path
                    visual.root.position           = path.start
                    visual.startHandle?.position   = .zero
                    visual.control1Handle.position = path.control1 - path.start
                    visual.control2Handle.position = path.control2 - path.start
                    visual.endHandle.position      = path.end - path.start
                    if let pathMesh = visual.root.findEntity(named: "MotionPath") as? ModelEntity {
                        MotionPathRenderer.updatePathMesh(entity: pathMesh, path: path)
                    }
                }

                // Shift rotation arcs by the same per-frame delta
                for (clipID, visual) in activeRotationArcs {
                    guard let clipIdx = timeline.clips.firstIndex(where: { $0.id == clipID }),
                          timeline.clips[clipIdx].entityName == entityName else { continue }
                    visual.root.position += frameDelta
                }
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
            // activeHandleEntity intentionally NOT cleared here — clearing it causes
            // the next gizmo-part drag to find targetEntity == nil and silently
            // camera-pan instead of moving the handle. Cleared only in handleTap.
            cachedSiblingBounds   = []
            pathRebuildFrameCount = 0
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
                let delta2 = delta  // 'delta' was computed before path.start was updated above
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

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let location = gesture.location(in: arView)
        guard let hit = arView.entity(at: location) else { return }

        // ── 1. Rotation arc handle (component on the hit entity) ──────────────
        if let arcComp = hit.components[RotationArcComponent.self],
           let arcRoot = activeRotationArcs[arcComp.clipID]?.root {
            showRotationArcContextMenu(clipID: arcComp.clipID, arcRoot: arcRoot)
            return
        }

        // ── 2. Rotation arc curve / shaft — walk up to the arc root ──────────
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

        // ── 3. Motion path handle ─────────────────────────────────────────────
        if let handle = hit.components[MotionPathHandleComponent.self],
           let pathRoot = hit.parent {
            showPathContextMenu(clipID: handle.clipID, pathRoot: pathRoot)
            return
        }

        // ── 4. Motion path curve ──────────────────────────────────────────────
        if hit.name == "MotionPath",
           let pathRoot = hit.parent,
           let handle   = pathRoot.children
               .compactMap({ $0.components[MotionPathHandleComponent.self] }).first {
            showPathContextMenu(clipID: handle.clipID, pathRoot: pathRoot)
            return
        }

        // ── 5. Regular entity — show action menu ──────────────────────────────
        // Walk up to the MainAnchor child (the entity root), skipping any
        // gizmo, path, or arc entities that slipped through the checks above.
        var root: Entity = hit
        while let parent = root.parent, parent.name != "MainAnchor" { root = parent }

        guard !root.name.contains("Gizmo"),
              !root.name.hasPrefix("PathRoot_"),
              !root.name.hasPrefix("RotationArc_")
        else { return }

        // Select the entity if it isn't already, then show the menu.
        if selectedEntity !== root {
            setEntityTransparency(selectedEntity, alpha: 1.0)
            selectedEntity = root
            setEntityTransparency(root, alpha: 0.9)
            updateGizmoMode()
        }
        showActionMenu(at: location)
    }
}

// MARK: - Collision Prevention Helper

extension CanvasViewController {
    
    /// Builds a snapshot of sibling bounds at drag start.
    /// Called once in handlePan(.began) so .changed never traverses the scene graph per frame.
    private func buildSiblingBoundsCache() {
        guard let anchor = mainAnchor else { cachedSiblingBounds = []; return }
        
        // Characters are allowed to overlap everything — skip building the cache.
        if let draggedCategory = selectedEntity?.components[CategoryComponent.self],
           draggedCategory.toolType == .character {
            cachedSiblingBounds = []
            return
        }
        
        cachedSiblingBounds = anchor.children.compactMap { sibling in
            guard sibling !== selectedEntity,
                  sibling.name != "GizmoRoot",
                  sibling.name != "Grid",
                  sibling.name != "EditorCamera",
                  sibling.name != "PathContainer",
                  !sibling.children.isEmpty || sibling is ModelEntity
            else { return nil }
            
            // Also skip characters as collision targets —
            // non-character entities should not be blocked by characters either.
            if let cat = sibling.components[CategoryComponent.self],
               cat.toolType == .character {
                return nil
            }
            
            return (sibling, sibling.visualBounds(relativeTo: nil))
        }
    }
    
    /// Clamps `proposedPosition` to smoothly avoid overlapping any sibling entity.
    /// Uses `cachedSiblingBounds` so this is O(n) with no extra scene-graph work.
    /// Instead of hard-blocking, applies gentle repulsion so colliding objects
    /// smoothly push apart without drastic position changes.
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
            
            // Calculate penetration depths on all axes
            let penRight  = selfBounds.max.x  - otherBounds.min.x
            let penLeft   = otherBounds.max.x  - selfBounds.min.x
            let penTop    = selfBounds.max.y  - otherBounds.min.y
            let penBottom = otherBounds.max.y  - selfBounds.min.y
            let penFront  = selfBounds.max.z  - otherBounds.min.z
            let penBack   = otherBounds.max.z  - selfBounds.min.z
            
            // Find the minimum penetration direction
            let minPen = min(penRight, penLeft, penTop, penBottom, penFront, penBack)
            
            // Apply a fraction (0.4) of the minimum penetration for smooth, gentle repulsion
            // instead of hard-blocking. This lets objects smoothly push apart.
            let repulsionFactor: Float = 0.4
            let gentleRepulsion = minPen * repulsionFactor
            
            if minPen == penRight {
                resolved.x += gentleRepulsion
            } else if minPen == penLeft {
                resolved.x -= gentleRepulsion
            } else if minPen == penTop {
                resolved.y += gentleRepulsion
            } else if minPen == penBottom {
                resolved.y -= gentleRepulsion
            } else if minPen == penFront {
                resolved.z += gentleRepulsion
            } else if minPen == penBack {
                resolved.z -= gentleRepulsion
            }
        }
        
        // Clamp Y floor — entity bottom must not go below ground
        // Skip for lights and cameras — they need to float freely.
        let skipYClamp: Bool = {
            if let cat = entity.components[CategoryComponent.self] {
                return cat.toolType == .light || cat.toolType == .camera
            }
            return entity.name.hasPrefix("SceneCamera") || entity.name.contains("Light")
        }()
        if !skipYClamp {
            let clampBounds = entity.visualBounds(relativeTo: entity)
            resolved.y = max(-clampBounds.min.y, resolved.y)
        }

        return resolved
    }

    /// Returns the world-space centre of the rotation arc for a clip.
    /// The arc root sits at the entity's world position at clip-creation time.
    private func visual_arcCentre(clip: AnimationClip, entity: Entity) -> SIMD3<Float> {
        // If the arc visual already exists, use its root position (most accurate)
        if let visual = activeRotationArcs[clip.id] {
            return visual.root.position(relativeTo: nil)
        }
        return entity.position(relativeTo: nil)
    }


}

// MARK: - SIMD4 helper

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}

// MARK: - ISSUE 6: Entity extension and editor overlay prefixes

extension Entity {
    /// Recursively visits this entity and all descendants, invoking body on each.
    /// Used by snapshot capture and preview generation to filter editor overlay entities.
    func forEachDescendant(_ body: (Entity) -> Void) {
        body(self)
        for child in children {
            child.forEachDescendant(body)
        }
    }
}

extension CanvasViewController {
    /// ISSUE 6: Shared list of entity name prefixes that represent editor-only overlays.
    /// These are filtered out in snapshot captures so they don't appear in exported media.
    static let editorOverlayPrefixes = [
        "PathRoot_",       // Motion path visualizations
        "RotationArc_",    // Rotation arc visualizations
        "GizmoRoot",       // Transform gizmos
    ]
}
