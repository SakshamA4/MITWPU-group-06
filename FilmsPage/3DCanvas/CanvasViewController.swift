//
//  ViewController.swift
//  3DCanvas
//
//  Created by SDC-USER on 12/01/26.
//

import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit
struct SceneSnapshot {
    var entityTransforms: [String: Transform]
}

// Defines which part of the gizmo is active
enum GizmoAxis {
    case x, y, z, none
}
// Lock Change
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

struct AnimationClip: Identifiable, Codable {

    let id: UUID
    let entityName: String

    let type: AnimationType
    let track: AnimationTrack
    let easing: EasingType

    let startTime: Float
    let duration: Float

    // Track-specific values
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

            // Parallel → no hit
            if abs(denom) < 0.0001 {
                return nil
            }

            let t = simd_dot(point - rayOrigin, normal) / denom

            if t < 0 {
                return nil
            }

            return rayOrigin + rayDirection * t
        }
    }

    init(
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
        self.id = UUID()
        self.entityName = entityName
        self.type = type
        self.track = track
        self.easing = easing
        self.startTime = startTime
        self.duration = duration
        self.fromValue = fromValue
        self.toValue = toValue
        self.motionPath = motionPath
    }
}
struct MotionPathVisual {

    let root: Entity
    let startHandle: ModelEntity?
    let control1Handle: ModelEntity
    let control2Handle: ModelEntity
    let endHandle: ModelEntity

    func update(path: BezierMotionPath) {

        // ✅ Start handle may not exist
        startHandle?.position = .zero

        // ✅ All handles are LOCAL to path.start
        control1Handle.position = path.control1 - path.start
        control2Handle.position = path.control2 - path.start
        endHandle.position = path.end - path.start
    }
}

struct Timeline {
    var clips: [AnimationClip] = []

    var duration: Float {
        clips
            .map { $0.startTime + $0.duration }
            .max() ?? 0
    }

    mutating func addClip(_ clip: AnimationClip) {
        clips.append(clip)
    }

    func clips(at time: Float) -> [AnimationClip] {
        clips.filter {
            time >= $0.startTime && time <= ($0.startTime + $0.duration)
        }
    }
}

extension Timeline {

    func effectiveClips(at time: Float) -> [AnimationClip] {
        clips.filter { clip in
            time >= clip.startTime
        }
    }
}

extension Transform {

    static func interpolate(
        from: Transform,
        to: Transform,
        t: Float
    ) -> Transform {

        let clampedT = max(0, min(1, t))

        let translation = simd_mix(
            from.translation,
            to.translation,
            SIMD3<Float>(repeating: clampedT)
        )

        let scale = simd_mix(
            from.scale,
            to.scale,
            SIMD3<Float>(repeating: clampedT)
        )

        let rotation = simd_slerp(
            from.rotation,
            to.rotation,
            clampedT
        )

        return Transform(
            scale: scale,
            rotation: rotation,
            translation: translation
        )
    }
}

func rayPlaneIntersection(
    rayOrigin: SIMD3<Float>,
    rayDirection: SIMD3<Float>,
    planePoint: SIMD3<Float>,
    planeNormal: SIMD3<Float>
) -> SIMD3<Float>? {

    let denom = simd_dot(planeNormal, rayDirection)

    if abs(denom) < 0.0001 { return nil }

    let t = simd_dot(planePoint - rayOrigin, planeNormal) / denom

    if t < 0 { return nil }

    return rayOrigin + rayDirection * t
}

func applyEasing(_ t: Float, easing: EasingType) -> Float {
    switch easing {
    case .linear:
        return t
    case .easeIn:
        return t * t
    case .easeOut:
        return 1 - pow(1 - t, 2)
    case .easeInOut:
        return t < 0.5
            ? 2 * t * t
            : 1 - pow(-2 * t + 2, 2) / 2
    }
}

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

    lazy var sceneNameLabel: UILabel = {
        let label = UILabel()
        // Accessing the instance property here
        label.text = self.sceneName.uppercased()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    //    var projectName: String = "Untitled Scene"  //new
    var undoStack: [SceneSnapshot] = []
    var redoStack: [SceneSnapshot] = []
    
    enum DragMode {
        case ground  // Moves on X and Z (Horizontal)
        case vertical  // Moves on Y (Elevation)
    }
    
    var currentDragMode: DragMode = .ground
    
    var arView: ARView!
    
    var selectedEntity: Entity?
    var dragStartPosition: SIMD3<Float>?
    var isDraggingObject = false
    var initialRotation: simd_quatf?
    
    var rotationGizmo: RotationRingGizmo?
    
//    enum GizmoPart {
//        case arrowY   // Vertical Movement (Green Arrow)
//        case planeXZ  // Ground Movement (Blue Circles)
//        case none
//    }
    
    // In CanvasViewController.swift
    enum GizmoPart {
        case arrowY   // Vertical Movement (Green Arrow)
        case planeXZ  // Ground Movement (Blue Circles)
        case rotateX  // NEW: Red Ring
        case rotateY  // NEW: Green Ring
        case rotateZ  // NEW: Blue Ring
        case none
    }
    
    var gizmoRoot: Entity?
    var activeGizmoPart: GizmoPart = .none

    // Movement mode toggle button (declared here, configured in setupUI)
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
    
    //camera system
    var editorCamera: PerspectiveCamera!
    var activeCamera: PerspectiveCamera!
    
    var sceneCameras: [PerspectiveCamera] = []
    var cameraPreviewTimer: Timer?
    var cameraToVisualMap: [PerspectiveCamera: Entity] = [:]
    
    var lastGestureRotation: Float = 0
    var accumulatedRotation: Float = 0
    
    var backgroundPlane: ModelEntity?
    var backgroundCounter = 0
    
    var currentAxis: GizmoAxis = .none
    
    var currentActionMenu: EntityActionMenu?
    
    struct SceneCameraItem {
        let camera: PerspectiveCamera
        let cameraRoot: Entity
    }
    
    var sceneCameraItems: [SceneCameraItem] = []
    var cameraCollectionView: UICollectionView!

    // MARK: - Top Right UI Components
    let shotBreakdownBtn: UIButton = {
        let btn = UIButton(type: .system)
        var config = UIButton.Configuration.filled()

        // 1. Icon setup
        config.image = UIImage(systemName: "list.bullet.indent")
        config.preferredSymbolConfigurationForImage =
            UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)

        // 2. Exact same look as Layers Button
        config.baseBackgroundColor = UIColor(
            red: 11 / 255,
            green: 11 / 255,
            blue: 22 / 255,
            alpha: 1
        )
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule

        btn.configuration = config
        btn.translatesAutoresizingMaskIntoConstraints = false

        // 3. Match shadow depth
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.3
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 4

        return btn
    }()
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCameraPreviewUpdates()
    }
    //  PLACE THIS AT CLASS LEVEL (NOT INSIDE ANOTHER FUNC)

//    // 5. The Application Function (Receives the Struct)
     func applySnapshot(_ snapshot: SceneSnapshot) {
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }
        let currentEntities = anchor.children
        
        // 1. REMOVE: If an entity is in the scene but NOT in the snapshot (Rollback addition)
        for entity in currentEntities {
            if entity.name == "Grid" || entity.name == "EditorCamera" { continue }
            if snapshot.entityTransforms[entity.name] == nil {
                entity.removeFromParent()
            }
        }
        
        // 2. RESTORE/UPDATE: If an entity is in the snapshot
        for (name, transform) in snapshot.entityTransforms {
            if let entity = arView.scene.findEntity(named: name) {
                // Case A: Entity exists, just update its transform
                entity.transform = transform
            } else {
                // Case B: Entity is MISSING from scene but present in snapshot (Redo addition)
                // 📍 THE FIX: Re-spawn the item using its stored name
                self.restoreEntity(named: name, with: transform)
            }
        }
        
        refreshSidebarContent()
    }
    
    //undo redo ends
    
    //Scene Hierarchy properties starts
    
    let sidebarWidth: CGFloat = 210
    var isSidebarVisible = false
    var sidebarLeadingConstraint: NSLayoutConstraint!
    
    let sidebarView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray5
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.3
        view.layer.shadowRadius = 5
        return view
    }()
    
    let hierarchyStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    let layersButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(
            pointSize: 20,
            weight: .regular
        )
        b.setImage(
            UIImage(systemName: "square.stack.3d.down.right"),
            for: .normal
        )
        b.tintColor = .white
        b.backgroundColor = UIColor(
            red: 11 / 255,
            green: 11 / 255,
            blue: 22 / 255,
            alpha: 1
        )
        b.layer.cornerRadius = 20
        b.clipsToBounds = true
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    //Scene Hierarchy properties ends
    
    var activeDraggedClipID: UUID?
    var activeDraggedHandleName: String?
    
    var timelineContainer: UIView!
    var playButton: UIButton!
    var stopButton: UIButton!
    var pauseButton: UIButton!
    var playbackButtonStack: UIStackView!
    var scrubber: UISlider!
    var displayLink: CADisplayLink?
    var playbackStartTime: CFTimeInterval = 0
    var currentTimelineTime: Float = 0
    
    enum PlaybackState {
        case stopped
        case playing
        case paused
    }
    
    var playbackState: PlaybackState = .stopped
    var baseTransforms: [String: Transform] = [:]
    var selectedPathClipID: UUID?
    
    // MARK: - Motion Path Rendering
    // MARK: - Motion Path Handle Ownership
    
    struct MotionPathHandleComponent: Component {
        let clipID: UUID
    }
    // MARK: - Timeline
    var timeline = Timeline()
    
    // MARK: - Motion Path
    
    // MARK: - World-Space Path Dragging
    
    var lastWorldDragPoint: SIMD3<Float>?
    
    var activeDragPlaneNormal: SIMD3<Float>?
    var activeDragPlanePoint: SIMD3<Float>?
    
    var initialHandleOffset: SIMD3<Float> = .zero
    
    var activeMotionPaths: [UUID: MotionPathVisual] = [:]

    // Stores the rotation arc Entity for each rotation AnimationClip.
    // Keyed by clip UUID — mirrors the activeMotionPaths pattern.
    var activeRotationArcs: [UUID: RotationArcVisual] = [:]

    // Arc handle drag state — mirrors activeHandleEntity / dragStartPosition pattern
    // for motion path handles.
    var activeArcHandle: Entity?          // the handle entity currently being dragged
    var activeArcClipID: UUID?            // which clip the dragging arc belongs to
    var arcDragStartAngle: Float = 0      // the angle (radians) when drag began
    
    // MARK: - Editor Mode
    var editorMode: EditorMode = .edit
    
    enum EditorMode {
        case edit
        case timeline
    }
    // MARK: - Animation UI
    
    var animationPanel: UIStackView!
    
    enum InteractionMode {
        case move
        case rotate
        case none
    }
    
    var interactionMode: InteractionMode = .move
    
    
    // MARK: - Gizmo Setup & Logic
    
    //Lifecycle
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
        self.sceneNameLabel.text = self.sceneName
    }

        // Add this method anywhere inside the CanvasViewController class
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    
    @objc func backButtonTapped() {
        let currentID =
            self.currentSceneID ?? self.currentSceneObject?.id ?? UUID()

        // Handle Template check as you currently do
        let isTemplate = ScenesDataStore.shared.currentTemplates.contains {
            $0.id == currentID
        }

        if isTemplate {
            ScenesDataStore.shared.saveTemplateNote(
                id: currentID,
                notes: self.sceneNotes
            )
        } else {
            // 1. Update Recent Scenes (Global)
            let updatedRecent = ScenesModel(
                id: currentID,
                name: self.sceneName,
                image: self.sceneImageName ?? "Image",
                notes: self.sceneNotes
            )
            ScenesDataStore.shared.addToRecent(scene: updatedRecent)

            if var projectScene = self.currentSceneObject {
                projectScene.name = self.sceneName
            }
        }

        self.dismiss(animated: true)
    }
    
    //Setup
    func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Stop RealityKit auto-starting its own AR session (prevents background grid artefact)
        arView.automaticallyConfigureSession = false
        // Disable post-processing so editor stays crisp and AR has no blurry-wave ghosting
        arView.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableHDR]
        arView.debugOptions = []
        arView.environment.background = .color(.white)
        view.addSubview(arView)
    }
    
    func setupInitialScene() {
        let anchor = AnchorEntity(world: .zero)
        anchor.name = "MainAnchor"
        
        let editorGrid = makeGrid(size: 100, spacing: 0.2)
        editorGrid.name = "Grid"
        anchor.addChild(editorGrid)
        
        editorCamera = PerspectiveCamera()
        editorCamera.name = "EditorCamera"
        editorCamera.isEnabled = true
        anchor.addChild(editorCamera)
        
        activeCamera = editorCamera
        arView.scene.addAnchor(anchor)
        
        updateEditorCamera()
        
    }
    
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

        // Handle Sky separately
        if toolType == .sky {
            applySky(type: item.modelFileName)
            return
        }

        Task {
            do {
                // 1. Initial Checks for Special Types
                let checkName = (customName ?? item.modelFileName).lowercased()

                if checkName.contains("ground") {
                    spawnGround()
                    return
                }
                if checkName.contains("wall") || item.modelFileName == "cube" {
                    spawnWall()
                    return
                }
                if checkName.contains("scenecamera") || item.modelFileName == "cam1" {
                    spawnSceneCamera()
                    return
                }
                if item.isBackground {
                    spawnBackgroundPlane(item)
                    return
                }

                // 2. Load the Entity
                let entity = try await Entity(named: item.modelFileName)

                // 📍 STEP A: NORMALIZE
                let bounds = entity.visualBounds(relativeTo: nil)
                let maxDim = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                if maxDim > 0.0001 {
                    entity.scale = SIMD3(repeating: 1.0 / maxDim)
                }

                // 📍 STEP B: APPLY PROP-SPECIFIC SCALES
                var verticalOffset: Float = 0.0
                if item.modelFileName == "Spotlight" {
                    entity.scale = SIMD3(repeating: 0.01)
                    verticalOffset = 0.25
                } else if item.modelFileName.contains("LED") {
                    entity.scale = SIMD3(repeating: 0.01)
                } else if item.modelFileName.contains("Lantern") {
                    entity.scale = SIMD3(repeating: 0.0025)
                    verticalOffset = 0.25
                } else if item.modelFileName.contains("Plant") {
                    entity.scale = SIMD3(repeating: 0.01)
                } else {
                    entity.scale = SIMD3<Float>(repeating: scale)
                }

                // 📍 STEP C: APPLY POSITION
                let randomX = Float.random(in: -1...1)
                let randomZ = Float.random(in: -1...1)
                let finalBounds = entity.visualBounds(relativeTo: nil)
                let liftToGround = -finalBounds.min.y
                let finalY = verticalOffset > 0 ? verticalOffset : liftToGround

                // Assign a unique name so multiple instances of the same model
                // don't collide in findEntity(named:) lookups.
                let baseName = customName ?? item.modelFileName
                let uniqueName: String = {
                    guard let anchor = arView.scene.findEntity(named: "MainAnchor") else {
                        return baseName
                    }
                    let existing = anchor.children.filter {
                        $0.name == baseName || $0.name.hasPrefix(baseName + "_")
                    }.count
                    return existing == 0 ? baseName : "\(baseName)_\(existing + 1)"
                }()
                entity.name = uniqueName
                entity.position = [randomX, finalY, randomZ]

                // 3. Components & Light Attachment
                entity.components.set(CategoryComponent(toolType: toolType))
                entity.generateCollisionShapes(recursive: true)
                entity.components.set(InputTargetComponent())

                if item.title.lowercased() == "light" || item.modelFileName == "Spotlight" {
                    addRealLightToModel(entity)
                } else if item.title.lowercased() == "light" || item.modelFileName == "LED Panel" {
                    addLEDPanel(to: entity)
                } else if item.title.lowercased() == "lantern" || item.modelFileName == "Lantern" {
                    addLantern(to: entity)
                }

                // 4. Add to Scene
                if let anchor = arView.scene.findEntity(named: "MainAnchor") {
                    anchor.addChild(entity)
                    self.refreshSidebarContent()
                }
            } catch {
                print("Failed to load \(item.modelFileName): \(error)")
            }
        }
    }

    // 2. The Renderer Function
    
    struct BackgroundComponent: Component {
        var width: Float
        var height: Float
    }
    
    //Export logic starts
    // STEP 1: Implement the logic to capture the 3D ARView
    
    // STEP 2: Update your button tap to show the Project's ExportVC
    
    //export logic ends
    
    //light part starts here
    
    //light part end
    
    //new: scene hierarchy starts
    
    var pathEditToolbar: UIView?
    
    struct WallComponent: Component {
        var width: Float = 1.5
        var height: Float = 1.2
    }
    
    struct GroundComponent: Component {
        var width: Float
        var depth: Float
    }
    
    //Gestures

    @objc func handlePathLongPress(
        _ gesture: UILongPressGestureRecognizer
    ) {
        guard gesture.state == .began else { return }
        
        let location = gesture.location(in: arView)
        
        guard let hit = arView.entity(at: location) else { return }
        
        // Case 1: Long-press on a path HANDLE
        if let handle = hit.components[MotionPathHandleComponent.self],
            let pathRoot = hit.parent
        {
            showPathContextMenu(
                clipID: handle.clipID,
                pathRoot: pathRoot
            )
            return
        }
        
        // Case 2: Long-press on the PATH CURVE itself
        if hit.name == "MotionPath",
            let pathRoot = hit.parent,
            let handle = pathRoot
                .children
                .compactMap({ $0.components[MotionPathHandleComponent.self] })
                .first
        {
            showPathContextMenu(
                clipID: handle.clipID,
                pathRoot: pathRoot
            )
            return
        }
    }

    //     let location = gesture.location(in: arView)

    //     // ─────────────────────────────────────────────
    //     // STEP 1 — MOTION PATH HANDLE DRAGGING
    //     // ─────────────────────────────────────────────
    //     if let hit = arView.entity(at: location),
    //        hit.name.hasPrefix("path."),
    //        let handleData = hit.components[MotionPathHandleComponent.self]
    //     {
    //         // Block if locked
    //         guard
    //             let pathRoot = hit.parent,
    //             let lock = pathRoot.components[LockComponent.self],
    //             lock.isLocked == false
    //         else { return }

    //         // Only selected path editable
    //         guard handleData.clipID == selectedPathClipID else { return }

    //         guard
    //             let visual = activeMotionPaths[handleData.clipID],
    //             let clipIndex = timeline.clips.firstIndex(where: { $0.id == handleData.clipID }),
    //             var path = timeline.clips[clipIndex].motionPath
    //         else { return }

    //         switch gesture.state {

    //         case .began:
    //             lastWorldDragPoint = nil

    //             let cameraForward = -SIMD3<Float>(
    //                 arView.cameraTransform.matrix.columns.2.x,
    //                 arView.cameraTransform.matrix.columns.2.y,
    //                 arView.cameraTransform.matrix.columns.2.z
    //             )

    //             activeDragPlaneNormal = cameraForward
    //             activeDragPlanePoint = hit.position(relativeTo: nil)
    //             return

    //         case .changed:
    //             guard
    //                 let planeNormal = activeDragPlaneNormal,
    //                 let planePoint = activeDragPlanePoint,
    //                 let rayDirection = arView.ray(through: location)?.direction
    //             else { return }

    //             let rayOrigin = arView.cameraTransform.translation

    //             guard let worldPoint = rayPlaneIntersection(
    //                 rayOrigin: rayOrigin,
    //                 rayDirection: rayDirection,
    //                 planePoint: planePoint,
    //                 planeNormal: planeNormal
    //             ) else { return }

    //             if lastWorldDragPoint == nil {
    //                 lastWorldDragPoint = worldPoint
    //                 return
    //             }

    //             let delta = worldPoint - lastWorldDragPoint!
    //             lastWorldDragPoint = worldPoint

    //             // ───────── Modify CURRENT path ─────────
    //             switch hit.name {

    //             case "path.start":
    //                 path.start += delta
    //                 path.control1 += delta
    //                 path.control2 += delta
    //                 path.end += delta

    //             case "path.c1":
    //                 path.control1 += delta

    //             case "path.c2":
    //                 path.control2 += delta

    //             case "path.end":
    //                 let oldStart = path.start
    //                 let oldEnd = path.end

    //                 let oldDir = oldEnd - oldStart
    //                 let oldLen = simd_length(oldDir)
    //                 guard oldLen > 0.0001 else { return }

    //                 let oldDirN = simd_normalize(oldDir)
    //                 let c1Rel = path.control1 - oldStart
    //                 let c2Rel = path.control2 - oldStart

    //                 path.end += delta

    //                 let newDir = path.end - oldStart
    //                 let newLen = simd_length(newDir)
    //                 guard newLen > 0.0001 else { return }

    //                 let scale = newLen / oldLen
    //                 let rot = simd_quatf(from: oldDirN, to: simd_normalize(newDir))

    //                 path.control1 = oldStart + rot.act(c1Rel * scale)
    //                 path.control2 = oldStart + rot.act(c2Rel * scale)

    //             default:
    //                 return
    //             }

    //             // ✅ Move later paths ONLY if path POSITION changed
    //             if hit.name == "path.start" || hit.name == "path.end" {
    //                 moveLaterPaths(
    //                     after: clipIndex,
    //                     entityName: timeline.clips[clipIndex].entityName,
    //                     delta: delta
    //                 )
    //             }


    //             // ───────── Update THIS visual ─────────
    //             visual.root.position = path.start
    //             visual.startHandle?.position = .zero
    //             visual.control1Handle.position = path.control1 - path.start
    //             visual.control2Handle.position = path.control2 - path.start
    //             visual.endHandle.position = path.end - path.start

    //             path.rebuildArcLengthTable()
    //             timeline.clips[clipIndex].motionPath = path

    //             if let pathEntity =
    //                 visual.root.findEntity(named: "MotionPath") as? ModelEntity {
    //                 MotionPathRenderer.updatePathMesh(entity: pathEntity, path: path)
    
//    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
//
//            let location = gesture.location(in: arView)
//
//            // ──────────────────────────────────────────────
//            // STEP 1 — SMOOTH WORLD-SPACE PATH HANDLE DRAG
//            // (Existing Path Logic - Unchanged)
//            // ──────────────────────────────────────────────
//
//            if let hit = arView.entity(at: location),
//               hit.name.hasPrefix("path."),
//               let handleData = hit.components[MotionPathHandleComponent.self]
//            {
//                // 🚫 BLOCK DRAGGING IF PATH IS LOCKED
//                guard
//                    let pathRoot = hit.parent,
//                    let lock = pathRoot.components[LockComponent.self],
//                    lock.isLocked == false
//                else { return }
//
//                // ONLY EDIT SELECTED (RED) PATH
//                guard handleData.clipID == selectedPathClipID else { return }
//
//                guard
//                    let visual = activeMotionPaths[handleData.clipID],
//                    let clipIndex = timeline.clips.firstIndex(where: { $0.id == handleData.clipID }),
//                    var path = timeline.clips[clipIndex].motionPath
//                else { return }
//
//                switch gesture.state {
//                case .began:
//                    lastWorldDragPoint = nil
//
//                    // Camera-facing drag plane
//                    let cameraForward = -SIMD3<Float>(
//                        arView.cameraTransform.matrix.columns.2.x,
//                        arView.cameraTransform.matrix.columns.2.y,
//                        arView.cameraTransform.matrix.columns.2.z
//                    )
//                    activeDragPlaneNormal = cameraForward
//                    activeDragPlanePoint = hit.position(relativeTo: nil)
//
//                case .changed:
//                    // ... (Your existing Path Drag logic) ...
//                    guard let planeNormal = activeDragPlaneNormal,
//                          let planePoint = activeDragPlanePoint else { return }
//
//                    let rayOrigin = arView.cameraTransform.translation
//                    guard let rayDirection = arView.ray(through: location)?.direction else { return }
//
//                    guard let worldPoint = rayPlaneIntersection(
//                        rayOrigin: rayOrigin,
//                        rayDirection: rayDirection,
//                        planePoint: planePoint,
//                        planeNormal: planeNormal
//                    ) else { return }
//
//                    if lastWorldDragPoint == nil {
//                        lastWorldDragPoint = worldPoint
//                        return
//                    }
//
//                    let delta = worldPoint - lastWorldDragPoint!
//                    lastWorldDragPoint = worldPoint
//
//                    switch hit.name {
//                    case "path.start":
//                        path.start += delta
//                        path.control1 += delta
//                        path.control2 += delta
//                        path.end += delta
//                    case "path.c1":
//                        path.control1 += delta
//                    case "path.c2":
//                        path.control2 += delta
//                    case "path.end":
//                        // Keynote-style end handle drag logic
//                        let oldStart = path.start
//                        let oldEnd = path.end
//                        let oldDir = oldEnd - oldStart
//                        let oldLength = simd_length(oldDir)
//
//                        if oldLength > 0.0001 {
//                            let oldDirNorm = simd_normalize(oldDir)
//                            let c1Rel = path.control1 - oldStart
//                            let c2Rel = path.control2 - oldStart
//
//                            path.end += delta
//
//                            let newEnd = path.end
//                            let newDir = newEnd - oldStart
//                            let newLength = simd_length(newDir)
//
//                            if newLength > 0.0001 {
//                                let newDirNorm = simd_normalize(newDir)
//                                let scale = newLength / oldLength
//                                let rotation = simd_quatf(from: oldDirNorm, to: newDirNorm)
//
//                                path.control1 = oldStart + rotation.act(c1Rel * scale)
//                                path.control2 = oldStart + rotation.act(c2Rel * scale)
//                            }
//                        }
//
//                        // Continuity logic for next clip
//                        let thisClip = timeline.clips[clipIndex]
//                        if let nextIndex = timeline.clips.enumerated().first(where: {
//                            $0.offset > clipIndex && $0.element.entityName == thisClip.entityName && $0.element.motionPath != nil
//                        })?.offset {
//                            var nextPath = timeline.clips[nextIndex].motionPath!
//                            let nextDelta = path.end - nextPath.start
//                            nextPath.start += nextDelta
//                            nextPath.end += nextDelta
//                            nextPath.control1 += nextDelta
//                            nextPath.control2 += nextDelta
//                            nextPath.rebuildArcLengthTable()
//                            timeline.clips[nextIndex].motionPath = nextPath
//
//                            if let nextVisual = activeMotionPaths[timeline.clips[nextIndex].id] {
//                                nextVisual.root.position = nextPath.start
//                                nextVisual.startHandle?.position = .zero
//                                nextVisual.control1Handle.position = nextPath.control1 - nextPath.start
//                                nextVisual.control2Handle.position = nextPath.control2 - nextPath.start
//                                nextVisual.endHandle.position = (nextPath.end - nextPath.start) + SIMD3<Float>(0, 0.02, 0)
//                                if let entity = nextVisual.root.findEntity(named: "MotionPath") as? ModelEntity {
//                                    MotionPathRenderer.updatePathMesh(entity: entity, path: nextPath)
//                                }
//                            }
//                        }
//                    default: return
//                    }
//
//                    // Update Visuals
//                    visual.root.position = path.start
//                    visual.startHandle?.position = .zero
//                    visual.control1Handle.position = path.control1 - path.start
//                    visual.control2Handle.position = path.control2 - path.start
//                    visual.endHandle.position = path.end - path.start
//                    path.rebuildArcLengthTable()
//                    timeline.clips[clipIndex].motionPath = path
//
//                    if let pathEntity = visual.root.findEntity(named: "MotionPath") as? ModelEntity {
//                        MotionPathRenderer.updatePathMesh(entity: pathEntity, path: path)
//                    }
//
//                case .ended, .cancelled:
//                    activeDragPlaneNormal = nil
//                    activeDragPlanePoint = nil
//                    lastWorldDragPoint = nil
//
//                    // Finalize continuity
//                    if hit.name == "path.end" {
//                        let thisClip = timeline.clips[clipIndex]
//                        if let nextIndex = timeline.clips.enumerated().first(where: {
//                            $0.offset > clipIndex && $0.element.entityName == thisClip.entityName && $0.element.motionPath != nil
//                        })?.offset {
//                            var nextPath = timeline.clips[nextIndex].motionPath!
//                            nextPath.start = path.end
//                            nextPath.rebuildArcLengthTable()
//                            timeline.clips[nextIndex].motionPath = nextPath
//                            // ... update next visual ...
//                            if let nextVisual = activeMotionPaths[timeline.clips[nextIndex].id] {
//                                nextVisual.root.position = nextPath.start
//                                // ... (Sync visual positions) ...
//                                if let entity = nextVisual.root.findEntity(named: "MotionPath") as? ModelEntity {
//                                    MotionPathRenderer.updatePathMesh(entity: entity, path: nextPath)
//                                }
//                            }
//                        }
//                    }
//                default: break
//                }
//                return
//            }
//
//            // ──────────────────────────────────────────────
//            // STEP 2 — NORMAL OBJECT / GIZMO DRAGGING
//            // (This is the part we fixed)
//            // ──────────────────────────────────────────────
//
//            switch gesture.state {
//
//            case .began:
//                saveCurrentStateToUndo()
//
//                // 1. HIT TEST
//                let hits = arView.hitTest(location)
//
//                // 2. CHECK FOR GIZMO PARTS (Priority)
//                if let gizmoHit = hits.first(where: {
//                    $0.entity.name == "Gizmo_Arrow_Y" ||
//                    $0.entity.name == "Gizmo_Plane_XZ" ||
//                    $0.entity.parent?.name == "Gizmo_Arrow_Y" || // Handle parent group hits
//                    $0.entity.parent?.name == "PlaneHandle"
//                }) {
//                    let name = gizmoHit.entity.name
//                    let parentName = gizmoHit.entity.parent?.name ?? ""
//
//                    if name == "Gizmo_Arrow_Y" || parentName == "Gizmo_Arrow_Y" {
//                        activeGizmoPart = .arrowY
//                        highlightGizmoPart(.arrowY)
//                    } else if name == "Gizmo_Plane_XZ" || parentName == "PlaneHandle" {
//                        activeGizmoPart = .planeXZ
//                        highlightGizmoPart(.planeXZ)
//                    }
//
//                    dragStartPosition = selectedEntity?.position
//                    isDraggingObject = true
//                    return
//                }
//
//                // 3. STANDARD OBJECT SELECTION (Fallback)
//                // If we didn't hit a gizmo, check if we hit an object
//                if let hit = arView.entity(at: location) {
//
//                    // Old Handle Logic (Keep if you still use old handles, otherwise safe to ignore)
//                    if hit.name == GizmoNames.xHandle { currentAxis = .x }
//                    else if hit.name == GizmoNames.yHandle { currentAxis = .y }
//                    else if hit.name == GizmoNames.zHandle { currentAxis = .z }
//                    else { currentAxis = .none }
//
//                    // Find Root
//                    var root: Entity? = hit
//                    while let parent = root?.parent, parent.name != "MainAnchor" {
//                        root = parent
//                    }
//
//                    selectedEntity = root
//                    dragStartPosition = root?.position
//                    initialRotation = root?.orientation
//
//                    if interactionMode == .none {
//                        interactionMode = .move
//                    }
//
//                    // If hitting the object body, we are NOT using the gizmo part logic
//                    activeGizmoPart = .none
//                }
//
//            case .changed:
//                guard editorMode == .edit else { return }
//
//                // 🔒 Lock Check
//                if let entity = selectedEntity {
//                    let isLocked = entity.components[LockComponent.self]?.isLocked ?? false
//                    if isLocked {
//                        handleCameraOrbit(gesture)
//                        return
//                    }
//                }
//
//                guard let entity = selectedEntity, let startPos = dragStartPosition else {
//                    handleCameraOrbit(gesture)
//                    return
//                }
//
//                let translation = gesture.translation(in: arView)
//
//                // ──────────────────────────────────────────────
//                // NEW GIZMO DRAG LOGIC
//                // ──────────────────────────────────────────────
//                if activeGizmoPart != .none {
//
//                    let dist = simd_distance(entity.position, activeCamera.position)
//                    let sensitivity: Float = 0.001 * dist
//
//                    var newPos = startPos
//
//                    if activeGizmoPart == .arrowY {
//                        // Vertical Drag (Y Axis)
//                        // Inverting translation.y because screen Y goes down, but 3D Y goes up
//                        newPos.y = startPos.y - (Float(translation.y) * sensitivity)
//
//                    } else if activeGizmoPart == .planeXZ {
//                        // Plane Drag (X/Z Axis) - Similar to your Ground Drag Mode logic
//                        let camOri = arView.cameraTransform.rotation
//                        let right = camOri.act([1, 0, 0])
//                        let forward = camOri.act([0, 0, -1])
//
//                        let flatForward = simd_normalize(SIMD3<Float>(forward.x, 0, forward.z))
//                        let flatRight = simd_normalize(SIMD3<Float>(right.x, 0, right.z))
//
//                        let dx = Float(translation.x) * sensitivity
//                        let dy = Float(translation.y) * sensitivity
//
//                        // Combine vectors to move on the floor plane
//                        let movement = (flatRight * dx) - (flatForward * dy)
//
//                        newPos.x = startPos.x + movement.x
//                        newPos.z = startPos.z + movement.z
//                    }
//
//                    entity.position = newPos
//                    updateGizmoPosition() // 🔄 Keep gizmo attached!
//                    return
//                }
//
//                // ──────────────────────────────────────────────
//                // STANDARD BODY DRAG LOGIC (Existing)
//                // ──────────────────────────────────────────────
//                let mouseDelta = SIMD2<Float>(Float(translation.x), Float(translation.y))
//
//                switch interactionMode {
//                case .move:
//                    var newPosition = startPos
//
//                    if currentAxis != .none {
//                        // Old handle logic
//                        let moveDelta = calculateAxisMovement(entity: entity, axis: currentAxis, mouseDelta: mouseDelta, view: arView)
//                        newPosition += moveDelta
//                    } else {
//                        // Body Dragging (Ground vs Vertical Toggle)
//                        let sensitivity: Float = 0.005
//                        let dx = mouseDelta.x * sensitivity
//                        let dy = -mouseDelta.y * sensitivity
//
//                        if currentDragMode == .ground {
//                            let camOri = arView.cameraTransform.rotation
//                            let right = camOri.act([1, 0, 0])
//                            let forward = camOri.act([0, 0, -1])
//
//                            let flatForward = simd_normalize(SIMD3<Float>(forward.x, 0, forward.z))
//                            let flatRight = simd_normalize(SIMD3<Float>(right.x, 0, right.z))
//
//                            newPosition += (flatRight * dx) + (flatForward * dy)
//                            newPosition.y = startPos.y
//                        } else {
//                            newPosition.x = startPos.x
//                            newPosition.z = startPos.z
//                            newPosition.y = startPos.y + (dy * 2.0)
//                        }
//                    }
//                    entity.position = newPosition
//                    updateGizmoPosition() // Update gizmo here too
//
//                case .rotate:
//                    let angle = Float(translation.x) * 0.01
//                    let rotation = simd_quatf(angle: angle, axis: [0, 1, 0])
//                    entity.orientation = rotation * (initialRotation ?? simd_quatf())
//
//                case .none:
//                    break
//                }
//
//            case .ended, .cancelled:
//                dragStartPosition = nil
//                initialRotation = nil
//                currentAxis = .none
//                activeGizmoPart = .none // Reset gizmo part
//                isDraggingObject = false
//                resetGizmoColors() // Reset colors
//
//            default:
//                break
//            }
//        }
//
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        
        let location = gesture.location(in: arView)

        // ──────────────────────────────────────────────
        // STEP 1 — ROTATION ARC HANDLE DRAGGING
        // Mirrors the motion path handle drag pattern exactly:
        //   .began  → confirm the drag started on an arc handle tip
        //   .changed → compute new angle from drag delta, update clip + rebuild arc
        //   .ended  → clear arc drag state
        // ──────────────────────────────────────────────

        // If we already locked onto an arc handle, keep routing here until .ended
        if activeArcHandle != nil {
            switch gesture.state {
            case .changed:
                guard
                    let handle  = activeArcHandle,
                    let clipID  = activeArcClipID,
                    let clipIdx = timeline.clips.firstIndex(where: { $0.id == clipID }),
                    let visual  = activeRotationArcs[clipID]
                else { break }

                // Convert screen drag to an angle delta on the XZ plane.
                // Horizontal drag → rotate; one full screen width ≈ 2π.
                let dx = Float(gesture.translation(in: arView).x)
                let angleDelta = dx * 0.01   // radians per point

                let isEndHandle = handle.name == "arcHandle.end"
                var clip = timeline.clips[clipIdx]

                if isEndHandle {
                    let newToAngle = arcDragStartAngle + angleDelta
                    timeline.clips[clipIdx] = AnimationClip(
                        entityName: clip.entityName,
                        type:       clip.type,
                        track:      clip.track,
                        easing:     clip.easing,
                        startTime:  clip.startTime,
                        duration:   clip.duration,
                        fromValue:  clip.fromValue,
                        toValue:    SIMD3<Float>(0, newToAngle, 0),
                        motionPath: clip.motionPath
                    )
                } else {
                    // start handle — shift fromValue
                    let newFromAngle = arcDragStartAngle + angleDelta
                    timeline.clips[clipIdx] = AnimationClip(
                        entityName: clip.entityName,
                        type:       clip.type,
                        track:      clip.track,
                        easing:     clip.easing,
                        startTime:  clip.startTime,
                        duration:   clip.duration,
                        fromValue:  SIMD3<Float>(0, newFromAngle, 0),
                        toValue:    clip.toValue,
                        motionPath: clip.motionPath
                    )
                }

                // Rebuild the arc visual with updated angles
                clip = timeline.clips[clipIdx]
                if let entity = arView.scene.findEntity(named: clip.entityName) {
                    RotationArcRenderer.update(visual: visual, clip: clip, entity: entity)
                }

            case .ended, .cancelled:
                activeArcHandle    = nil
                activeArcClipID    = nil
                arcDragStartAngle  = 0

            default: break
            }
            return  // consumed — don't fall through to gizmo/camera handling
        }

        // On .began, check if this touch starts on an arc handle tip
        if gesture.state == .began,
           let hit = arView.entity(at: location),
           let arcComp = hit.components[RotationArcComponent.self]
        {
            activeArcHandle   = hit
            activeArcClipID   = arcComp.clipID
            // Record the handle's current angle as the drag baseline
            if let visual = activeRotationArcs[arcComp.clipID] {
                let isEnd = hit.name == "arcHandle.end"
                if let clipIdx = timeline.clips.firstIndex(where: { $0.id == arcComp.clipID }) {
                    arcDragStartAngle = isEnd
                        ? timeline.clips[clipIdx].toValue.y
                        : timeline.clips[clipIdx].fromValue.y
                }
            }
            saveCurrentStateToUndo()
            return
        }

        // ──────────────────────────────────────────────
        // STEP 2 — GIZMO DRAGGING (move gizmo + rotation rings)
        // ──────────────────────────────────────────────

        switch gesture.state {

        case .began:
            saveCurrentStateToUndo()

            // 1. HIT TEST
            let hits = arView.hitTest(location)

            // 2. CHECK FOR GIZMO PARTS (move arrows, plane circles, rotation rings)
            if let gizmoHit = hits.first(where: {
                $0.entity.name == "Gizmo_Arrow_Y" ||
                $0.entity.name == "Gizmo_Plane_XZ" ||
                $0.entity.parent?.name == "Gizmo_Arrow_Y" ||
                $0.entity.parent?.name == "PlaneHandle" ||
                $0.entity.name == "xRing" ||
                $0.entity.name == "yRing" ||
                $0.entity.name == "zRing"
            }) {
                let name = gizmoHit.entity.name
                let parentName = gizmoHit.entity.parent?.name ?? ""

                // Move gizmo parts
                if name == "Gizmo_Arrow_Y" || parentName == "Gizmo_Arrow_Y" {
                    activeGizmoPart = .arrowY
                    highlightGizmoPart(.arrowY)
                } else if name == "Gizmo_Plane_XZ" || parentName == "PlaneHandle" {
                    activeGizmoPart = .planeXZ
                    highlightGizmoPart(.planeXZ)
                // Rotation rings
                } else if name == "xRing" {
                    activeGizmoPart = .rotateX
                    activeRotationAxis = [1, 0, 0]
                    highlightGizmoPart(.rotateX)
                } else if name == "yRing" {
                    activeGizmoPart = .rotateY
                    activeRotationAxis = [0, 1, 0]
                    highlightGizmoPart(.rotateY)
                } else if name == "zRing" {
                    activeGizmoPart = .rotateZ
                    activeRotationAxis = [0, 0, 1]
                    highlightGizmoPart(.rotateZ)
                }

                // dragStartPosition: use handle entity if gizmo is on a handle, else selectedEntity
                if let handle = activeHandleEntity {
                    dragStartPosition = handle.position(relativeTo: arView.scene.findEntity(named: "MainAnchor"))
                } else {
                    dragStartPosition = selectedEntity?.position
                }
                lastPanLocation = location
                isDraggingObject = true
                return
            }

            // 3. STANDARD OBJECT SELECTION (no body drag)
            if let hit = arView.entity(at: location) {
                var root: Entity? = hit
                while let parent = root?.parent, parent.name != "MainAnchor" {
                    root = parent
                }
                if root?.name != "GizmoRoot" {
                    selectedEntity = root
                }
                activeGizmoPart = .none
            }

        case .changed:
            guard editorMode == .edit else { return }

            // Lock Check
            if let entity = selectedEntity {
                let isLocked = entity.components[LockComponent.self]?.isLocked ?? false
                if isLocked {
                    handleCameraOrbit(gesture)
                    return
                }
            }

            // Must have a gizmo part grabbed
            guard activeGizmoPart != .none,
                  let startPos = dragStartPosition else {
                handleCameraOrbit(gesture)
                return
            }

            // ROTATION RINGS
            if activeGizmoPart == .rotateX || activeGizmoPart == .rotateY || activeGizmoPart == .rotateZ {
                guard let axis = activeRotationAxis,
                      let selected = selectedEntity else {
                    handleCameraOrbit(gesture)
                    return
                }
                let dx = Float(location.x - lastPanLocation.x)
                let dy = Float(location.y - lastPanLocation.y)
                let drag = abs(dx) > abs(dy) ? dx : -dy
                let angle = drag * 0.01
                guard angle.isFinite else { return }
                let rotation = simd_quatf(angle: angle, axis: axis)
                selected.transform.rotation = simd_normalize(rotation * selected.transform.rotation)
                lastPanLocation = location
                return
            }

            // MOVE GIZMO
            let translation = gesture.translation(in: arView)
            let isMovingHandle = activeHandleEntity != nil
            let targetEntity: Entity? = isMovingHandle ? activeHandleEntity : selectedEntity
            guard let target = targetEntity else { return }

            let dist = simd_distance(target.position(relativeTo: nil), activeCamera.position)
            let sensitivity: Float = max(0.001, 0.001 * dist)

            var newPos = startPos

            if activeGizmoPart == .arrowY {
                newPos.y = startPos.y - (Float(translation.y) * sensitivity)
            } else if activeGizmoPart == .planeXZ {
                let camOri = arView.cameraTransform.rotation
                let right = camOri.act([1, 0, 0])
                let forward = camOri.act([0, 0, -1])
                let flatForward = simd_normalize(SIMD3<Float>(forward.x, 0, forward.z))
                let flatRight = simd_normalize(SIMD3<Float>(right.x, 0, right.z))
                let dx = Float(translation.x) * sensitivity
                let dy = Float(translation.y) * sensitivity
                let movement = (flatRight * dx) - (flatForward * dy)
                newPos.x = startPos.x + movement.x
                newPos.z = startPos.z + movement.z
            }

            if isMovingHandle {
                // Move the handle in world space and keep gizmo in sync
                if let anchor = arView.scene.findEntity(named: "MainAnchor") {
                    target.setPosition(newPos, relativeTo: anchor)
                    if let gizmo = gizmoRoot {
                        gizmo.position = target.position(relativeTo: anchor)
                    }
                }
                // Redraw the bezier path with the updated handle position
                if let handleComp = target.components[MotionPathHandleComponent.self],
                   let clipIndex = timeline.clips.firstIndex(where: { $0.id == handleComp.clipID }),
                   var path = timeline.clips[clipIndex].motionPath,
                   let visual = activeMotionPaths[handleComp.clipID] {
                    switch target.name {
                    case "path.start":
                        let delta = newPos - path.start
                        path.start += delta; path.control1 += delta
                        path.control2 += delta; path.end += delta
                        // Glue previous clip's end to this new start
                        if clipIndex > 0,
                           timeline.clips[clipIndex - 1].entityName == timeline.clips[clipIndex].entityName,
                           var prevPath = timeline.clips[clipIndex - 1].motionPath {
                            let oldVecP = prevPath.end - prevPath.start  // capture BEFORE move
                            let oldLenP = simd_length(oldVecP)
                            prevPath.end = path.start                    // move end to new start
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
                                func reframePrevS2(_ p: SIMD3<Float>) -> SIMD3<Float> {
                                    let v = p - prevPath.start
                                    let tx = simd_dot(v, oPx) / oldLenP
                                    let ty = simd_dot(v, oPy) / oldLenP
                                    let tz = simd_dot(v, oPz) / oldLenP
                                    return prevPath.start + (nPx*tx + nPy*ty + nPz*tz) * newLenP
                                }
                                prevPath.control1 = reframePrevS2(prevPath.control1)
                                prevPath.control2 = reframePrevS2(prevPath.control2)
                            }
                            prevPath.rebuildArcLengthTable()
                            timeline.clips[clipIndex - 1].motionPath = prevPath
                            if let prevVisual = activeMotionPaths[timeline.clips[clipIndex - 1].id] {
                                prevVisual.root.position = prevPath.start
                                prevVisual.control1Handle.position = prevPath.control1 - prevPath.start
                                prevVisual.control2Handle.position = prevPath.control2 - prevPath.start
                                prevVisual.endHandle.position = prevPath.end - prevPath.start
                                if let pathMesh = prevVisual.root.findEntity(named: "MotionPath") as? ModelEntity {
                                    MotionPathRenderer.updatePathMesh(entity: pathMesh, path: prevPath)
                                }
                            }
                        }
                        // Glue ALL subsequent clips to this path's new end
                        let thisClipS2Start = timeline.clips[clipIndex]
                        for nextIdx in (clipIndex + 1)..<timeline.clips.count {
                            let nextClip = timeline.clips[nextIdx]
                            guard nextClip.entityName == thisClipS2Start.entityName,
                                  var nextPath = nextClip.motionPath else { continue }
                            nextPath.start += delta
                            nextPath.end += delta
                            nextPath.control1 += delta
                            nextPath.control2 += delta
                            nextPath.rebuildArcLengthTable()
                            timeline.clips[nextIdx].motionPath = nextPath
                            if let nextVisual = activeMotionPaths[timeline.clips[nextIdx].id] {
                                nextVisual.root.position = nextPath.start
                                nextVisual.startHandle?.position = .zero
                                nextVisual.control1Handle.position = nextPath.control1 - nextPath.start
                                nextVisual.control2Handle.position = nextPath.control2 - nextPath.start
                                nextVisual.endHandle.position = nextPath.end - nextPath.start
                                if let pathMesh = nextVisual.root.findEntity(named: "MotionPath") as? ModelEntity {
                                    MotionPathRenderer.updatePathMesh(entity: pathMesh, path: nextPath)
                                }
                            }
                        }
                    case "path.c1":
                        path.control1 = newPos
                    case "path.c2":
                        path.control2 = newPos
                    case "path.end":
                        // Keynote-style curvature preservation
                        let oldEnd = path.end
                        let oldVec2 = path.end - path.start
                        let oldLen2 = simd_length(oldVec2)
                        path.end = newPos
                        let newVec2 = path.end - path.start
                        let newLen2 = simd_length(newVec2)
                        if oldLen2 > 0.0001 && newLen2 > 0.0001 {
                            let oX = simd_normalize(oldVec2)
                            let up2: SIMD3<Float> = abs(oX.y) < 0.99 ? [0,1,0] : [1,0,0]
                            let oZ = simd_normalize(simd_cross(oX, up2))
                            let oY = simd_cross(oZ, oX)
                            let nX = simd_normalize(newVec2)
                            let nZ = simd_normalize(simd_cross(nX, up2))
                            let nY = simd_cross(nZ, nX)
                            func reframe2(_ p: SIMD3<Float>) -> SIMD3<Float> {
                                let v = p - path.start
                                let tx = simd_dot(v, oX) / oldLen2
                                let ty = simd_dot(v, oY) / oldLen2
                                let tz = simd_dot(v, oZ) / oldLen2
                                return path.start + (nX*tx + nY*ty + nZ*tz) * newLen2
                            }
                            path.control1 = reframe2(path.control1)
                            path.control2 = reframe2(path.control2)
                        }
                        // Shift ALL subsequent paths by the end-handle delta
                        let endDelta = path.end - oldEnd
                        let thisClipS2 = timeline.clips[clipIndex]
                        for nextIdx in (clipIndex + 1)..<timeline.clips.count {
                            let nextClip = timeline.clips[nextIdx]
                            guard nextClip.entityName == thisClipS2.entityName,
                                  var nextPath = nextClip.motionPath else { continue }
                            nextPath.start += endDelta
                            nextPath.end += endDelta
                            nextPath.control1 += endDelta
                            nextPath.control2 += endDelta
                            nextPath.rebuildArcLengthTable()
                            timeline.clips[nextIdx].motionPath = nextPath
                            if let nextVisual = activeMotionPaths[timeline.clips[nextIdx].id] {
                                nextVisual.root.position = nextPath.start
                                nextVisual.startHandle?.position = .zero
                                nextVisual.control1Handle.position = nextPath.control1 - nextPath.start
                                nextVisual.control2Handle.position = nextPath.control2 - nextPath.start
                                nextVisual.endHandle.position = nextPath.end - nextPath.start
                                if let pathMesh = nextVisual.root.findEntity(named: "MotionPath") as? ModelEntity {
                                    MotionPathRenderer.updatePathMesh(entity: pathMesh, path: nextPath)
                                }
                            }
                        }
                    default: break
                    }
                    path.rebuildArcLengthTable()
                    timeline.clips[clipIndex].motionPath = path
                    visual.root.position = path.start
                    visual.startHandle?.position = .zero
                    visual.control1Handle.position = path.control1 - path.start
                    visual.control2Handle.position = path.control2 - path.start
                    visual.endHandle.position = path.end - path.start
                    if let pathMesh = visual.root.findEntity(named: "MotionPath") as? ModelEntity {
                        MotionPathRenderer.updatePathMesh(entity: pathMesh, path: path)
                    }
                }
            } else {
                target.position = newPos
                updateGizmoPosition()
            }

        case .ended, .cancelled:
            dragStartPosition = nil
            initialRotation = nil
            activeGizmoPart = .none
            activeRotationAxis = nil
            isDraggingObject = false
            activeHandleEntity = nil
            resetGizmoColors()

        default:
            break
        }
    }


        //  OLD STEP 2 — NORMAL OBJECT / GIZMO DRAGGING (SAKSHAM)

}



extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}
