//
//  ViewController.swift
//  3DCanvas
//
//  Created by SDC-USER on 12/01/26.
//


import UIKit
import RealityKit
import Combine
import PhotosUI


struct SceneSnapshot {
    var entityTransforms: [String: Transform]
}

// Defines which part of the gizmo is active
enum GizmoAxis {
    case x, y, z, none
}

struct GizmoNames {
    static let xHandle = "Gizmo_Handle_X"
    static let yHandle = "Gizmo_Handle_Y"
    static let zHandle = "Gizmo_Handle_Z"
}



struct LockComponent: Component {
    var isLocked: Bool = false
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
    let startHandle: ModelEntity
    let control1Handle: ModelEntity
    let control2Handle: ModelEntity
    let endHandle: ModelEntity

    func update(path: BezierMotionPath) {

        startHandle.position = path.start
        control1Handle.position = path.control1
        control2Handle.position = path.control2
        endHandle.position = path.end
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
            time >= $0.startTime &&
            time <= ($0.startTime + $0.duration)
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

class CanvasViewController: UIViewController {
    
    // MARK: - NEW Properties
        var currentSceneObject: Scene?
        var sceneName: String = "Untitled Scene"
        var filmName: String?
        var sequenceName: String?
        var sceneNotes: String = ""
        var lastEditedDate: Date = Date()
        var sceneImageName: String?
        var currentSceneID: UUID?
    
    private lazy var sceneNameLabel: UILabel = {
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
        func saveCurrentStateToUndo() {
            let allEntities = arView.scene.anchors.flatMap { $0.children }
            var snapshotDict: [String: Transform] = [:]
            
            for entity in allEntities {
                snapshotDict[entity.name] = entity.transform
            }
            
            let snapshot = SceneSnapshot(entityTransforms: snapshotDict)
            
            undoStack.append(snapshot)
            redoStack.removeAll()
        }
    

    enum DragMode {
            case ground     // Moves on X and Z (Horizontal)
            case vertical   // Moves on Y (Elevation)
        }
    
    var currentDragMode: DragMode = .ground
    
    var arView: ARView!

    var selectedEntity: Entity?
    var dragStartPosition: SIMD3<Float>?
    var isDraggingObject = false
    var initialRotation: simd_quatf?


    // Camera State
    var yaw: Float = 0.5
    var pitch: Float = 0.5
    var distance: Float = 5.0
    var cameraTarget = SIMD3<Float>(0, 0, 0)
    
    //camera system
    var editorCamera: PerspectiveCamera!
    var activeCamera: PerspectiveCamera!

    var sceneCameras: [PerspectiveCamera] = []
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
    
    
    @objc func undoTapped() {
            guard let previousState = undoStack.popLast() else { return }
            
            // Save current state to redo before going back
            redoStack.append(createCurrentSnapshot())
            
            applySnapshot(previousState)
        }

        @objc func redoTapped() {
            guard let nextState = redoStack.popLast() else { return }
            
            // Save current state to undo before going forward
            undoStack.append(createCurrentSnapshot())
            
            applySnapshot(nextState)
        }
    
    
    // MARK: - Top Right UI Components
        private let shotBreakdownBtn: UIButton = {
            let btn = UIButton(type: .system)
            var config = UIButton.Configuration.filled()
            
            // 1. Icon setup
            config.image = UIImage(systemName: "list.bullet.indent")
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            
            // 2. Exact same look as Layers Button
            config.baseBackgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
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
        
    //  PLACE THIS AT CLASS LEVEL (NOT INSIDE ANOTHER FUNC)
        func setupTopControlsUI() {
            // 1. Add Breakdown button
            view.addSubview(shotBreakdownBtn)
            
            // 2. Re-anchor Play Button from the old stack
            view.addSubview(playButton)
            playButton.translatesAutoresizingMaskIntoConstraints = false
            
            // 3. Style Play Button to match Breakdown/Layers style
            playButton.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
            playButton.tintColor = .white
            playButton.layer.cornerRadius = 22
            playButton.clipsToBounds = false

            NSLayoutConstraint.activate([
                        shotBreakdownBtn.centerYAnchor.constraint(equalTo: layersButton.centerYAnchor),
                        shotBreakdownBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                        shotBreakdownBtn.widthAnchor.constraint(equalToConstant: 44),
                        shotBreakdownBtn.heightAnchor.constraint(equalToConstant: 44),
                       
                        playButton.centerYAnchor.constraint(equalTo: layersButton.centerYAnchor),
                        playButton.trailingAnchor.constraint(equalTo: shotBreakdownBtn.leadingAnchor, constant: -16),
                        playButton.widthAnchor.constraint(equalToConstant: 44),
                        playButton.heightAnchor.constraint(equalToConstant: 44)
            ])
            
            shotBreakdownBtn.addTarget(self, action: #selector(shotBreakdownTapped), for: .touchUpInside)
        }
    
    
    
    
        // 5. The Application Function (Receives the Struct)
        private func applySnapshot(_ snapshot: SceneSnapshot) {
            // Unwrap the dictionary from the snapshot struct
            for (name, transform) in snapshot.entityTransforms {
                if let entity = arView.scene.findEntity(named: name) {
                    entity.transform = transform
                }
            }
            refreshSidebarContent()
        }

        func createCurrentSnapshot() -> SceneSnapshot {
            var snapshotDict: [String: Transform] = [:]
            let allEntities = arView.scene.anchors.flatMap { $0.children }
            
            for entity in allEntities {
                snapshotDict[entity.name] = entity.transform
            }
            
            // Convert dictionary into a SceneSnapshot struct before returning
            return SceneSnapshot(entityTransforms: snapshotDict)
        }

        

        func saveStateForUndo() {
            undoStack.append(createCurrentSnapshot())
            redoStack.removeAll()
        }
            
        
        //undo redo ends
    
    //Scene Hierarchy properties starts

        private let sidebarWidth: CGFloat = 210
        private var isSidebarVisible = false
        private var sidebarLeadingConstraint: NSLayoutConstraint!
    
        private let sidebarView: UIView = {
            let view = UIView()
            view.backgroundColor = .systemGray5
            view.translatesAutoresizingMaskIntoConstraints = false
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOpacity = 0.3
            view.layer.shadowRadius = 5
            return view
        }()

        private let hierarchyStackView: UIStackView = {
            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 8
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()
        
        let layersButton: UIButton = {
                let b = UIButton(type: .system)
                let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
                b.setImage(UIImage(systemName: "square.stack.3d.down.right"), for: .normal)
                b.tintColor = .white
                b.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
                b.layer.cornerRadius = 22
                b.clipsToBounds = true
                b.translatesAutoresizingMaskIntoConstraints = false
                return b
            }()
        //Scene Hierarchy properties ends


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

    func setupTimelineControls() {

        timelineContainer = UIView()
        timelineContainer.translatesAutoresizingMaskIntoConstraints = false
        timelineContainer.backgroundColor = UIColor.systemGray6
        timelineContainer.layer.borderWidth = 1
        timelineContainer.layer.borderColor = UIColor.systemGray3.cgColor
        timelineContainer.isHidden = true
        
        view.addSubview(timelineContainer)

        playButton = UIButton(type: .system)
        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playButton.tintColor = .white
        playButton.backgroundColor = .systemGreen
        playButton.layer.cornerRadius = 22
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.addTarget(self, action: #selector(playTimeline), for: .touchUpInside)
        
        
        pauseButton = UIButton(type: .system)
        pauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        pauseButton.tintColor = .white
        pauseButton.backgroundColor = .systemOrange
        pauseButton.layer.cornerRadius = 22
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        pauseButton.isHidden = true
        pauseButton.addTarget(self, action: #selector(pauseTimeline), for: .touchUpInside)
        
        
        stopButton = UIButton(type: .system)
        stopButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        stopButton.tintColor = .white
        stopButton.backgroundColor = .systemRed
        stopButton.layer.cornerRadius = 22
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.isHidden = true
        stopButton.addTarget(self, action: #selector(stopTimeline), for: .touchUpInside)
        
        playbackButtonStack = UIStackView(arrangedSubviews: [
            playButton,
            pauseButton,
            stopButton
        ])
        playbackButtonStack.axis = .horizontal
        playbackButtonStack.spacing = 12
        playbackButtonStack.alignment = .center
        playbackButtonStack.distribution = .equalSpacing
        playbackButtonStack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(playbackButtonStack)
        
        // Constraints
        
        NSLayoutConstraint.activate([
            
            // Timeline container (bottom)
            timelineContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            timelineContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            timelineContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            timelineContainer.heightAnchor.constraint(equalToConstant: 120),
            
            // Playback buttons (bottom-left, above timeline)
//            playbackButtonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
//            playbackButtonStack.bottomAnchor.constraint(
//                equalTo: timelineContainer.topAnchor,
//                constant: -12
//            ),
            
            // Button sizes (explicit, consistent)
            playButton.widthAnchor.constraint(equalToConstant: 44),
            playButton.heightAnchor.constraint(equalToConstant: 44),
            
            pauseButton.widthAnchor.constraint(equalToConstant: 44),
            pauseButton.heightAnchor.constraint(equalToConstant: 44),
            
            stopButton.widthAnchor.constraint(equalToConstant: 44),
            stopButton.heightAnchor.constraint(equalToConstant: 44),
        ])
        
        // Scrubber
        
        setupScrubber()
    }
    
    func updatePathSelection() {

        for (clipID, visual) in activeMotionPaths {

            guard
                let pathEntity = visual.root
                    .findEntity(named: "MotionPath") as? ModelEntity
            else { continue }

            let color: UIColor =
                (clipID == selectedPathClipID)
                ? .systemRed
                : .systemBlue

            MotionPathRenderer.setPathColor(
                entity: pathEntity,
                color: color
            )
        }
    }

    
    @objc func playTimeline() {
        
        // RESUME FROM PAUSE
        
        if playbackState == .paused {
            // Adjust start time so playback resumes correctly
            playbackStartTime = CACurrentMediaTime()
            - CFTimeInterval(currentTimelineTime)
            
            startPlayback()
            playbackState = .playing
            
            playButton.isHidden = true
            pauseButton.isHidden = false
            stopButton.isHidden = false
            
            return
        }

        // START FROM BEGINNING
        
        guard editorMode == .edit else { return }
        guard !timeline.clips.isEmpty else { return }
        
        enterTimelineMode()
        
        // Show timeline UI
        timelineContainer.isHidden = false
        playButton.isHidden = true
        pauseButton.isHidden = false
        stopButton.isHidden = false
        
        
        // Setup scrubber
        scrubber.minimumValue = 0
        scrubber.maximumValue = timeline.duration
        scrubber.value = 0
        
        // Reset timeline time
        currentTimelineTime = 0
        playbackStartTime = CACurrentMediaTime()
        playbackState = .playing
        
        // Start playback loop
        startPlayback()
    }
    
    
    @objc func pauseTimeline() {
        guard playbackState == .playing else { return }
        
        stopPlayback()
        playbackState = .paused
        
        pauseButton.isHidden = true
        playButton.isHidden = false
        
    }
    
    
    func startPlayback() {
        stopPlayback() // safety
        
        displayLink = CADisplayLink(
            target: self,
            selector: #selector(updatePlayback)
        )
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopPlayback() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc func updatePlayback() {
        let elapsed = Float(CACurrentMediaTime() - playbackStartTime)
        currentTimelineTime = elapsed
        
        if currentTimelineTime >= timeline.duration {
            stopTimeline()
            return
        }
        
        scrubber.value = currentTimelineTime
        evaluateTimeline(at: currentTimelineTime)
    }
    
    
    @objc func stopTimeline() {
        guard editorMode == .timeline else { return }
        
        stopPlayback()
        playbackState = .stopped
        
        
        scrubber.value = 0
        currentTimelineTime = 0
        playbackStartTime = 0
        
        exitTimelineMode()
        
        timelineContainer.isHidden = true
        playButton.isHidden = false
        stopButton.isHidden = true
        pauseButton.isHidden = true
        
        // Re-evaluate timeline at t = 0 so objects
        // snap back to their initial transforms
        evaluateTimeline(at: 0)
    }
    
    
    func evaluateTimeline(at time: Float) {
        
        let clipsByEntity = Dictionary(
            grouping: timeline.effectiveClips(at: time),
            by: { $0.entityName }
        )
        
        for (entityName, clips) in clipsByEntity {
            
            guard
                let entity = arView.scene.findEntity(named: entityName),
                let baseTransform = baseTransforms[entityName]
            else { continue }
            
            var translation = baseTransform.translation
            var rotation = baseTransform.rotation
            var scale = baseTransform.scale
            
            // Sort clips by start time (important!)
            let sortedClips = clips.sorted { $0.startTime < $1.startTime }
            
            for clip in sortedClips {
                
                let localTime = time - clip.startTime
                
                let progress: Float
                if localTime <= 0 {
                    continue
                } else if localTime >= clip.duration {
                    progress = 1          // 🔑 HOLD FINAL VALUE
                } else {
                    progress = localTime / clip.duration
                }
                
                let eased = applyEasing(progress, easing: clip.easing)
                
                let value = simd_mix(
                    clip.fromValue,
                    clip.toValue,
                    SIMD3<Float>(repeating: eased)
                )
                
                switch clip.track {
                    
                case .position:

                    if let path = clip.motionPath {

                        let t = max(
                            0,
                            min(1,
                                (time - clip.startTime) / clip.duration
                            )
                        )

                        translation = path.evaluateConstantSpeed(t)

                    }

                case .rotation:
                    let delta = simd_quatf(
                        angle: value.y,
                        axis: [0, 1, 0]
                    )
                    rotation = delta * rotation
                    
                case .scale:
                    scale *= value
                }
            }
            
            entity.transform = Transform(
                scale: scale,
                rotation: rotation,
                translation: translation
            )
        }
    }
    
    // MARK: - Motion Path Rendering
    func makePathHandle(
        color: UIColor,
        name: String
    ) -> ModelEntity {

        // small visible handle
        let mesh = MeshResource.generateSphere(radius: 0.04)

        let material = SimpleMaterial(
            color: color,
            roughness: 0.2,
            isMetallic: true
        )

        let handle = ModelEntity(mesh: mesh, materials: [material])
        handle.name = name

        // LARGE invisible touch radius
        let collision = CollisionComponent(
            shapes: [.generateSphere(radius: 0.15)]
        )

        handle.components.set(collision)
        handle.components.set(InputTargetComponent())

        return handle
    }

    func showMotionPath(for clip: AnimationClip) {

        guard let path = clip.motionPath else { return }

        // remove previous
        activeMotionPaths[clip.id]?.root.removeFromParent()

        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else {
            return
        }

        let pathRoot = Entity()
        pathRoot.name = "PathRoot_\(clip.id)"

        pathRoot.position = path.start

        let start = makePathHandle(color: .gray, name: "path.start")
        let c1    = makePathHandle(color: .orange, name: "path.c1")
        let c2    = makePathHandle(color: .orange, name: "path.c2")
        let end   = makePathHandle(color: .systemBlue, name: "path.end")
        
        start.components.set(
            MotionPathHandleComponent(clipID: clip.id)
        )

        c1.components.set(
            MotionPathHandleComponent(clipID: clip.id)
        )

        c2.components.set(
            MotionPathHandleComponent(clipID: clip.id)
        )

        end.components.set(
            MotionPathHandleComponent(clipID: clip.id)
        )


        start.position = .zero
        c1.position = path.control1 - path.start
        c2.position = path.control2 - path.start
        end.position = path.end - path.start


        let curve = MotionPathRenderer.makePathEntity(path: path)
        curve.name = "MotionPath"
        
        curve.position = .zero
        curve.orientation = simd_quatf()
        curve.scale = .one

        pathRoot.addChild(curve)
        pathRoot.addChild(start)
        pathRoot.addChild(c1)
        pathRoot.addChild(c2)
        pathRoot.addChild(end)

        anchor.addChild(pathRoot)

        activeMotionPaths[clip.id] = MotionPathVisual(
            root: pathRoot,
            startHandle: start,
            control1Handle: c1,
            control2Handle: c2,
            endHandle: end
        )
    }

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
        
    func debugPrintTimeline() {
        print("Timeline Clips:")
        for clip in timeline.clips {
            print("""
                ├─ \(clip.type.rawValue.uppercased())
                   Entity: \(clip.entityName)
                   Start: \(clip.startTime)s
                   Duration: \(clip.duration)s
                """)
        }
    }
    
    func setupScrubber() {
        
        scrubber = UISlider()
        scrubber.translatesAutoresizingMaskIntoConstraints = false
        scrubber.minimumValue = 0
        scrubber.maximumValue = 1
        scrubber.value = 0
        
        scrubber.addTarget(
            self,
            action: #selector(scrubberChanged(_:)),
            for: .valueChanged
        )
        
        timelineContainer.addSubview(scrubber)
        
        NSLayoutConstraint.activate([
            scrubber.leadingAnchor.constraint(equalTo: timelineContainer.leadingAnchor, constant: 16),
            scrubber.trailingAnchor.constraint(equalTo: timelineContainer.trailingAnchor, constant: -16),
            scrubber.centerYAnchor.constraint(equalTo: timelineContainer.centerYAnchor)
        ])
    }
    
    @objc func scrubberChanged(_ sender: UISlider) {
        let time = sender.value
        evaluateTimeline(at: time)
    }
    
    func makeRay(from screenPoint: CGPoint)
    -> (origin: SIMD3<Float>, direction: SIMD3<Float>) {

        guard let ray = arView.ray(through: screenPoint) else {

            // fallback forward ray
            let cam = arView.cameraTransform
            let forward = cam.rotation.act([0, 0, -1])
            return (cam.translation, forward)
        }

        return (ray.origin, ray.direction)
    }

    
    
    // MARK: - Editor Mode
    var editorMode: EditorMode = .edit
    
    enum EditorMode {
        case edit
        case timeline
    }
    
    func enterTimelineMode() {
        editorMode = .timeline
        hideAnimationPanel()
        selectedEntity = nil
        
        baseTransforms.removeAll()
        
        for anchor in arView.scene.anchors {
            for entity in anchor.children {
                baseTransforms[entity.name] = entity.transform
            }
        }
    }
    
    
    func exitTimelineMode() {
        editorMode = .edit
        
        for (name, transform) in baseTransforms {
            arView.scene.findEntity(named: name)?.transform = transform
        }
        
        baseTransforms.removeAll()
    }
    // MARK: - Animation UI
    
    var animationPanel: UIStackView!
    
    func setupAnimationPanel() {
        animationPanel = UIStackView()
        animationPanel.axis = .horizontal
        animationPanel.spacing = 12
        animationPanel.alignment = .center
        animationPanel.distribution = .fillEqually
        animationPanel.translatesAutoresizingMaskIntoConstraints = false
        animationPanel.alpha = 0
        
        let moveBtn = makeAnimButton(title: "Move", action: #selector(animateMove))
        let rotateBtn = makeAnimButton(title: "Rotate", action: #selector(animateRotate))
        
        animationPanel.addArrangedSubview(moveBtn)
        animationPanel.addArrangedSubview(rotateBtn)
        
        view.addSubview(animationPanel)
        
        NSLayoutConstraint.activate([
            animationPanel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animationPanel.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -90
            ),
            animationPanel.heightAnchor.constraint(equalToConstant: 44),
            animationPanel.widthAnchor.constraint(equalToConstant: 220)
        ])
    }
    
    func makeAnimButton(title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.backgroundColor = .systemIndigo
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 10
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }
    
    func showAnimationPanel() {
        UIView.animate(withDuration: 0.2) {
            self.animationPanel.alpha = 1
        }
    }
    
    func hideAnimationPanel() {
        UIView.animate(withDuration: 0.2) {
            self.animationPanel?.alpha = 0
        }
    }
    
    @objc func animateMove() {
        presentAnimationPrompt(type: .move)
    }
    
    @objc func animateRotate() {
        presentAnimationPrompt(type: .rotate)
    }
    
    func presentAnimationPrompt(type: AnimationType) {
        guard editorMode == .edit else { return }
        guard let entity = selectedEntity else { return }
        
        let title = "Add \(type.rawValue.capitalized) Animation"
        
        let alert = UIAlertController(
            title: title,
            message: "Enter start time and duration (seconds)",
            preferredStyle: .alert
        )
        
        alert.addTextField { field in
            field.placeholder = "Start Time (e.g. 0.0)"
            field.keyboardType = .decimalPad
            field.text = "0.0"
        }
        
        alert.addTextField { field in
            field.placeholder = "Duration (e.g. 1.0)"
            field.keyboardType = .decimalPad
            field.text = "0.5"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(
            UIAlertAction(title: "Add to Timeline", style: .default) { _ in
                self.handleAnimationPromptConfirm(
                    type: type,
                    entity: entity,
                    alert: alert
                )
            }
        )
        
        present(alert, animated: true)
    }
    
    func handleAnimationPromptConfirm(
        type: AnimationType,
        entity: Entity,
        alert: UIAlertController
    ) {
        guard
            let startText = alert.textFields?[0].text,
            let durationText = alert.textFields?[1].text,
            let startTime = Float(startText),
            let duration = Float(durationText),
            duration > 0
        else {
            return
        }
        
        let easing: EasingType = .easeInOut
        
        var track: AnimationTrack
        var fromValue = SIMD3<Float>.zero
        var toValue = SIMD3<Float>.zero
        var motionPath: BezierMotionPath? = nil
        
        switch type {
            
            // MOVE
        case .move:
            track = .position
            
            let start = entity.position
            let end = start + SIMD3<Float>(2, 0, 0)
            
            motionPath = BezierMotionPath(
                start: start,
                control1: start + SIMD3<Float>(0.5, 0, 0),
                control2: start + SIMD3<Float>(1.5, 0, 0),
                end: end
            )

        case .rotate:
            track = .rotation
            fromValue = SIMD3<Float>(0, 0, 0)
            toValue = SIMD3<Float>(0, .pi / 2, 0)
        }
        
        let clip = AnimationClip(
            entityName: entity.name,
            type: type,
            track: track,
            easing: easing,
            startTime: startTime,
            duration: duration,
            fromValue: fromValue,
            toValue: toValue,
            motionPath: motionPath
        )

        timeline.addClip(clip)

        if clip.motionPath != nil {
            showMotionPath(for: clip)
        }

        debugPrintTimeline()
        
    }
    
        enum InteractionMode {
            case move
            case rotate
            case none
        }

        var interactionMode: InteractionMode = .move

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
                BackgroundStore.shared.onImageSelected = { [weak self] pickedImage in
                    DispatchQueue.main.async {
                        self?.applyBackgroundImage(pickedImage)
                    }
                }
        self.sceneNameLabel.text = self.sceneName
    }
    
    private func setupNavigationBar() {
        
        self.navigationItem.title = self.sceneName
        
        // 1. Back Button Logic

        // This creates a custom back button that pops the view controller
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        
        // 2. Undo & Redo (Moved beside the back button)
        let undoBtn = UIBarButtonItem(
            image: UIImage(systemName: "arrow.uturn.backward"),
            style: .plain,
            target: self,
            action: #selector(undoTapped)
        )
        
        let redoBtn = UIBarButtonItem(
            image: UIImage(systemName: "arrow.uturn.forward"),
            style: .plain,
            target: self,
            action: #selector(redoTapped)
        )
        
        // Combine Back, Undo, Redo on the left
        navigationItem.leftBarButtonItems = [backButton, undoBtn, redoBtn]
        
        // 3. Right Side: Export and 3-Dots
        let exportBtn = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(exportTapped) // Uses your existing export logic
        )
        
        let moreBtn = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(moreTapped)
        )
        
        navigationItem.rightBarButtonItems = [moreBtn, exportBtn]
        
        
        
        // 4. Configure Appearance (Dark background like your image)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
            ]
            
        appearance.titleTextAttributes = titleAttributes // 📍 Apply here
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .systemBlue
        appearance.titleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
            ]
        
    }
    
    @objc func moreTapped() {
        let infoVC = SceneInfoViewController()
                
                // Pass tracked data to the modal
                infoVC.sceneName = self.sceneName
                infoVC.sequenceName = self.sequenceName
                infoVC.filmName = self.filmName
                infoVC.initialNotes = self.sceneNotes
                infoVC.lastEditedDate = self.lastEditedDate
                if let imageName = self.sceneImageName {
                    infoVC.sceneImage = UIImage(named: imageName)
                }
        infoVC.onSave = { [weak self] newName, newNotes in
            guard let self = self else { return }
            
            // 1. Update local UI state
            self.sceneName = newName
            self.sceneNotes = newNotes
            self.lastEditedDate = Date()
            self.sceneNameLabel.text = newName.uppercased()
            self.navigationItem.title = newName
            // 2. 📍 SAVE TO DATABASE: This now works because 'notes' is in ScenesModel
            if var sceneToUpdate = self.currentSceneObject {
                sceneToUpdate.name = newName
                sceneToUpdate.notes = newNotes
                
                // Use your service to save changes permanently
                SceneService.shared.updateScene(sceneToUpdate)
                
                // Update local reference
                self.currentSceneObject = sceneToUpdate
            }
            
            let updatedModel = ScenesModel(name: newName, image: self.sceneImageName ?? "Image", notes: newNotes)
            ScenesDataStore.shared.addToRecent(scene: updatedModel)
            NotificationCenter.default.post(name: NSNotification.Name("scenesUpdated"), object: nil)
        }
        
        // Snapshot logic
        arView.snapshot(saveToHDR: false) { image in
            infoVC.sceneImage = image
        }
        
        infoVC.modalPresentationStyle = .overCurrentContext
        infoVC.modalTransitionStyle = .crossDissolve
        self.present(infoVC, animated: true)
    }
    
    @objc private func backButtonTapped() {
        let currentID = self.currentSceneID ?? self.currentSceneObject?.id ?? UUID()
        
        // Handle Template check as you currently do
        let isTemplate = ScenesDataStore.shared.currentTemplates.contains { $0.id == currentID }
        
        if isTemplate {
            ScenesDataStore.shared.saveTemplateNote(id: currentID, notes: self.sceneNotes)
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
        arView.environment.background = .color(.white)
        view.addSubview(arView)
    }

    func setupInitialScene() {
        let anchor = AnchorEntity(world: .zero)
        anchor.name = "MainAnchor"

        anchor.addChild(makeGrid(size: 100, spacing: 0.2))

        editorCamera = PerspectiveCamera()
        editorCamera.name = "EditorCamera"
        editorCamera.isEnabled = true
        anchor.addChild(editorCamera)

        activeCamera = editorCamera
        arView.scene.addAnchor(anchor)

        updateEditorCamera()

    }

    
func spawnEntity(item: SpawnItem, toolType: ToolType, customName: String? = nil, scale: Float = 1.0) {
        saveCurrentStateToUndo()
        
        Task {
            do {
                // 1. Initial checks (Camera, Wall, Ground)
                if item.modelFileName == "cam1" { spawnSceneCamera(); return }
                if item.modelFileName == "cube" { spawnWall(); return }
                if item.modelFileName == "ground" { spawnGround(); return }
                if item.isBackground { return }

                // 2. Load the Entity
                let entity = try await Entity(named: item.modelFileName)
                
                // 📍 STEP A: NORMALIZE (The Permanent Scaling Fix)
                // We use .relativeTo(nil) to get the true world-space dimensions
                let bounds = entity.visualBounds(relativeTo: nil)
                let maxDim = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                
                if maxDim > 0.0001 { // Safety check for empty models
                    let normalizationFactor = 1.0 / maxDim
                    entity.scale = SIMD3(repeating: normalizationFactor)
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
                    // Now that it's normalized to 1m, 0.5 makes it exactly 50cm
                    entity.scale = SIMD3(repeating: 0.01)
                } else {
                    // Slider scale (1.0 = 1 meter tall/wide)
                    entity.scale = SIMD3<Float>(repeating: scale)
                }

                // 📍 STEP C: APPLY POSITION
                let randomX = Float.random(in: -1...1)
                let randomZ = Float.random(in: -1...1)
                
                // Recalculate grounding lift after the final scale is set
                let finalBounds = entity.visualBounds(relativeTo: nil)
                let liftToGround = -finalBounds.min.y
                
                // Use your manual verticalOffset if it exists, otherwise auto-ground it
                let finalY = verticalOffset > 0 ? verticalOffset : liftToGround
                
                entity.name = customName ?? item.modelFileName
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


    
    

    func applyBackgroundImage(_ image: UIImage) {
            guard let cgImage = image.cgImage,
                  let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }

            do {
                let texture = try TextureResource(image: cgImage, options: .init(semantic: .color))
                var material = UnlitMaterial()
                material.color.texture = .init(texture)
                
                // 2. Increment counter and create unique name
                backgroundCounter += 1
                let uniqueName = "Background \(backgroundCounter)"
                
                // 1. DIMENSIONS
                let aspect = Float(image.size.width / image.size.height)
                let height: Float = 1.5
                let width = height * aspect
                let thickness: Float = 0.05
                
                // 2. BOX MESH (Double-sided and thick)
                let mesh = MeshResource.generateBox(width: width, height: height, depth: thickness)
                let plane = ModelEntity(mesh: mesh, materials: [material])
                plane.name = uniqueName
                
                plane.components.set(BackgroundComponent(width: width, height: height))

                // 3. INTERACTION
                plane.generateCollisionShapes(recursive: true)
                plane.components.set(InputTargetComponent())
                plane.orientation = simd_quatf(angle: 0, axis: [0, 0, 1])

                let offset = Float(backgroundCounter) * 0.1
                plane.position = [offset, height / 2, -2.1 - offset]
                
                // 6. GESTURES & CATEGORY
                plane.components.set(CategoryComponent(toolType: .background))
                
                anchor.addChild(plane)
                self.backgroundPlane = plane
                
                self.refreshSidebarContent()
                
            } catch {
                print("Texture failed: \(error)")
            }
        }

    struct BackgroundComponent: Component {
        var width: Float
        var height: Float
    }


    //Export logic starts
        // STEP 1: Implement the logic to capture the 3D ARView
        private func captureCanvasAndShare(isPNG: Bool) {
            // Hide UI elements you don't want in the final photo
            layersButton.isHidden = true
            playbackButtonStack.isHidden = true
            
            // Use RealityKit's native snapshot for high-quality 3D rendering
            arView.snapshot(saveToHDR: false) { [weak self] image in
                guard let self = self, let image = image else { return }
                
                let data: Data? = isPNG ? image.pngData() : image.jpegData(compressionQuality: 0.9)
                
                guard let exportData = data, let imageToShare = UIImage(data: exportData) else { return }
                
                let activityVC = UIActivityViewController(activityItems: [imageToShare], applicationActivities: nil)
                
                // iPad Support
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = self.view
                    popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                }
                
                self.present(activityVC, animated: true) {
                    // Bring UI back after capture
                    self.layersButton.isHidden = false
                    self.playbackButtonStack.isHidden = false
                }
            }
        }

        // STEP 2: Update your button tap to show the Project's ExportVC
        @objc func exportTapped() {
            let exportVC = ExportVC()
            
            exportVC.projectName = "Film: Project Alpha"
            
            exportVC.onFormatSelected = { [weak self] format in
                guard let self = self else { return }
                
                // 1. Dismiss the modal first
                exportVC.dismiss(animated: true) {
                    // 2. Based on the selection, trigger the capture
                    if format == "JPEG" {
                        self.captureCanvasAndShare(isPNG: false)
                    } else if format == "PNG" {
                        self.captureCanvasAndShare(isPNG: true)
                    } else {
                        // Placeholder for PDF/MP4
                        let alert = UIAlertController(title: "Info", message: "\(format) export coming soon!", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
            
            // 3. Presentation Logic for a nice half-screen sheet
            if let sheet = exportVC.sheetPresentationController {
                sheet.detents = [.medium()] // Only takes up half the screen
                sheet.prefersGrabberVisible = true // Shows the little handle at the top
            }
            
            self.present(exportVC, animated: true)
        }
        
        //export logic ends

    
    //light part starts here
       
        func addRealLightToModel(_ model: Entity) {
            let realLight = SpotLight()
            
            
            // 1. High Intensity & Clear Beam
            realLight.light.intensity = 200000
            realLight.light.innerAngleInDegrees = 10
            realLight.light.outerAngleInDegrees = 30
            realLight.light.attenuationRadius = 20.0
            realLight.shadow = SpotLightComponent.Shadow()
            realLight.orientation = simd_quaternion(Float.pi, [0, 1, 0])
            realLight.position = [0, 0, 0.2]
            
            let lensGlow = ModelEntity(mesh: .generateSphere(radius: 0.1),
                                       materials: [UnlitMaterial(color: .yellow)])
            lensGlow.position = [10, 10, 0.1]
            model.addChild(lensGlow)
            
            // 4. ADD VOLUMETRIC CONE (Visible Beam)
            let beamMesh = MeshResource.generateCone(height: 4.0, radius: 1.0)
            var beamMat = UnlitMaterial(color: .white)
            beamMat.blending = .transparent(opacity: .init(floatLiteral: 0.2))
            let beamVisual = ModelEntity(mesh: beamMesh, materials: [beamMat])
            
            // Rotate and position the cone to match the light path
            beamVisual.orientation = simd_quaternion(-Float.pi / 2, [1, 0, 0])
            beamVisual.position = [0, 0, -2.0]
            realLight.addChild(beamVisual)
            
            model.addChild(realLight)
        }
    
    func addLEDPanel(to model: Entity) {
            let lightGroup = Entity()
            lightGroup.name = "LED_Guts_Group"
            
            // Scale isolation: ensure light math is in meters relative to 0.01 parent scale
            lightGroup.scale = SIMD3(repeating: 80.0)

            // 1. Setup the SpotLight (The actual light emitter)
            let ledWash = SpotLight()
            ledWash.light.intensity = 200000
            ledWash.light.innerAngleInDegrees = 65
            ledWash.light.outerAngleInDegrees = 110
            ledWash.light.color = .white
            
            // 📍 PLACEMENT: 1.6m high (center of panel) and 0.02m back from the very front
            ledWash.position = [0, 1.5, 0.02]
            ledWash.orientation = simd_quaternion(Float.pi - (.pi*2/3), [0, 1, 0])
            
            lightGroup.addChild(ledWash)
            model.addChild(lightGroup)
        }
        
        func addLantern(to model: Entity) {
            let lanternGroup = Entity()
            lanternGroup.name = "Lantern_Guts_Group"
            
            lanternGroup.scale = SIMD3(repeating: 80.0)
            
            let lanternWash = PointLight()
            lanternWash.name = "LanternInternalLight"
            
            lanternWash.light.intensity = 100000
            lanternWash.light.color = .systemYellow
            lanternWash.light.attenuationRadius = 5.0
            lanternWash.position = [0, 0.5, 0]
            
            lanternGroup.addChild(lanternWash)
            model.addChild(lanternGroup)
        }

        func spawnPointLight() {
            let lightEntity = PointLight()
            lightEntity.light.intensity = 12000
            lightEntity.light.color = .systemRed
            lightEntity.light.attenuationRadius = 10.0
            let bulb = ModelEntity(mesh: .generateSphere(radius: 0.1),
                                   materials: [UnlitMaterial(color: .yellow)])
            lightEntity.addChild(bulb)
            lightEntity.name = "DynamicPointLight"
            lightEntity.position = [0, 1.0, 0] // 1 meter
            lightEntity.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.1)]))
            lightEntity.components.set(InputTargetComponent())
            
            if let anchor = arView.scene.findEntity(named: "MainAnchor") {
                anchor.addChild(lightEntity)
                if let interactable = lightEntity as? (Entity & HasCollision & HasTransform) {
                    arView.installGestures([.translation], for: interactable)
                }
            }
        }

        func setPointLightIntensity(_ lumens: Float) {
            guard let light = arView.scene.findEntity(named: "DynamicPointLight") as? PointLight else { return }
            light.light.intensity = lumens
        }
        func moveLight(to position: SIMD3<Float>) {
            arView.scene.findEntity(named: "PointLightSource")?.position = position
        }

        //light part end
    
    //new: scene hierarchy starts
        @objc func didTapLayersButton() {
            if !isSidebarVisible {
                refreshSidebarContent()
            }
            
            isSidebarVisible.toggle()
            sidebarLeadingConstraint.constant = isSidebarVisible ? 0 : -sidebarWidth
            
            UIView.animate(withDuration: 0.2) {
                // Hide the layer button if sidebar is visible, show it if not
                self.layersButton.alpha = self.isSidebarVisible ? 0 : 1
                self.playbackButtonStack.alpha = self.isSidebarVisible ? 0 : 1
                self.playbackButtonStack.isHidden = self.isSidebarVisible
                self.view.layoutIfNeeded()
            }
        }
        
    
    func refreshSidebarContent() {
        hierarchyStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let allEntities = arView.scene.anchors.flatMap { $0.children }

        var itemsByCategory: [ToolType: [Entity]] = [:]
        ToolType.allCases.forEach { itemsByCategory[$0] = [] }

        for entity in allEntities {
            guard
                let category = entity.components[CategoryComponent.self]?.toolType
            else { continue }

            itemsByCategory[category]?.append(entity)
        }

        for tool in ToolType.allCases {
            let entities = itemsByCategory[tool] ?? []
            let header = createHierarchyHeader(
                title: tool.hierarchyTitle,
                count: entities.count
            )
            hierarchyStackView.addArrangedSubview(header)

            for entity in entities {
                let row = createHierarchyItemRow(title: entity.name)
                hierarchyStackView.addArrangedSubview(row)
            }
        }
    }

        
        private func createHierarchyHeader(title: String, count: Int) -> UIView {
            let label = UILabel()
            label.text = "\(title) (\(count))"
            label.font = .systemFont(ofSize: 16, weight: .bold)
            label.textColor = .label
            let container = UIView()
            container.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
            ])
            return container
        }

    private func selectEntityFromSidebar(named name: String) {

        guard let entity = arView.scene.findEntity(named: name) else { return }
        

        self.selectedEntity = entity
        self.refreshSidebarContent()

        if let screenPosition = arView.project(entity.position(relativeTo: nil)) {
        
            currentActionMenu?.removeFromSuperview()

            showActionMenu(at: screenPosition)
            
            if let animation = entity.availableAnimations.first {
                entity.playAnimation(animation.repeat(count: 1))
            }
        }
    }
    
    private func createHierarchyItemRow(title: String) -> UIView {
        // 1. Create a modern Plain configuration
        var config = UIButton.Configuration.plain()
        
        // 2. Set the title and color
        config.title = title
        let isSelected = selectedEntity?.name == title
        config.baseForegroundColor = isSelected ? .systemRed : .label
        
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 32, bottom: 4, trailing: 0)

        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 14)
            return outgoing
        }

        let button = UIButton(configuration: config)
        
        // Alignment still works on the button property
        button.contentHorizontalAlignment = .leading

        // 6. Add the action
        button.addAction(UIAction { [weak self] _ in
            self?.selectEntityFromSidebar(named: title)
        }, for: .touchUpInside)
        
        return button
    }
    
    
    
    func spawnWall() {
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }

        let wallRoot = ModelEntity()
        wallRoot.name = "Wall"
        
        wallRoot.components.set(
            CategoryComponent(toolType: .wall)
        )

        let mesh = MeshResource.generateBox(
            width: 1.5,
            height: 1.2,
            depth: 0.05
        )

        let material = SimpleMaterial(
            color: .lightGray,
            roughness: 0.6,
            isMetallic: false
        )

        wallRoot.model = ModelComponent(mesh: mesh, materials: [material])

        wallRoot.position = [0, 0.6, -2]

        wallRoot.generateCollisionShapes(recursive: true)
        wallRoot.components.set(InputTargetComponent())

        wallRoot.components.set(WallComponent())

        anchor.addChild(wallRoot)
    }

    struct WallComponent: Component {
        var width: Float = 1.5
        var height: Float = 1.2
    }
    
    func spawnGround() {
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }

        let ground = ModelEntity()
        ground.name = "Ground"
        
        ground.components.set(
            CategoryComponent(toolType: .wall)
        )

        let mesh = MeshResource.generatePlane(
            width: 4,
            depth: 4
        )

        let material = SimpleMaterial(
            color: .darkGray.withAlphaComponent(1),
            roughness: 1.0,
            isMetallic: false
        )

        ground.model = ModelComponent(mesh: mesh, materials: [material])

        ground.position = [0, 0, 0]

        ground.generateCollisionShapes(recursive: true)
        ground.components.set(InputTargetComponent())

        ground.components.set(GroundComponent(width: 4, depth: 4))

        anchor.addChild(ground)
    }
    
    struct GroundComponent: Component {
        var width: Float
        var depth: Float
    }


    @objc func deleteSelected() {
        if let camera = selectedEntity?
            .children
            .compactMap({ $0 as? PerspectiveCamera })
            .first {

            sceneCameras.removeAll { $0 == camera }
            cameraToVisualMap[camera] = nil

            if activeCamera === camera {
                activateEditorCamera()
            }
        }

        selectedEntity?.removeFromParent()
        selectedEntity = nil
        
        refreshSidebarContent()
    }


    //Gestures
    func setupGestures() {

        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap(_:))
        )
        arView.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(
            target: self,
            action: #selector(handlePan(_:))
        )
        arView.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(handlePinch(_:))
        )
        arView.addGestureRecognizer(pinch)
        
        _ = UIRotationGestureRecognizer(
            target: self,
            action: #selector(handleRotation(_:))
        )
    }
    

    
    @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
            guard let entity = selectedEntity else { return }
            guard editorMode == .edit else { return }
           
            // LOCK CHECK
            let isLocked = entity.components[LockComponent.self]?.isLocked ?? false
            if isLocked { return }

            if gesture.state == .began {
                saveCurrentStateToUndo()
            }
           
            let snapAngle: Float = .pi / 6
            let rotationSpeed: Float = 0.001
           
            switch gesture.state {
            case .began:
                initialRotation = entity.orientation
                lastGestureRotation = 0

            case .changed:
                let totalGestureRotation = Float(gesture.rotation)
                let smoothedRotation = totalGestureRotation * rotationSpeed
                let snappedRotation = round(smoothedRotation / snapAngle) * snapAngle
               
                if let startRotation = initialRotation {
                    let rotationQuaternion = simd_quatf(
                        angle: -snappedRotation,
                        axis: [0, 1, 0]
                    )
                    entity.orientation = rotationQuaternion * startRotation
                    cameraCollectionView?.reloadData()
                }

            case .ended, .cancelled:
                initialRotation = nil
               
            default:
                break
            }
        }

    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        
        let location = gesture.location(in: arView)
        if let hit = arView.entity(at: location),
           let handle = hit.components[MotionPathHandleComponent.self] {

            selectedPathClipID = handle.clipID
            updatePathSelection()
        }

        currentActionMenu?.removeFromSuperview()
        currentActionMenu = nil
        
        // 2. Perform Hit Test
        guard let hitEntity = arView.entity(at: location) else {
            selectedEntity = nil
            interactionMode = .none
            hideAnimationPanel() // Hides the purple buttons if they were visible
            return
        }
        var root: Entity = hitEntity
        while let parent = root.parent, parent.name != "MainAnchor" {
            root = parent
        }
        selectedEntity = root
        // Select path for this entity
        if let clip = timeline.clips.last(where: {
            $0.entityName == root.name && $0.motionPath != nil
        }) {
            selectedPathClipID = clip.id
            updatePathSelection()
        }

        showActionMenu(at: location)
        
        // 5. Visual Feedback (Animation)
        if let animation = root.availableAnimations.first {
            let singlePlay = animation.repeat(count: 1)
            root.playAnimation(singlePlay)
        }

    }
    
    
    func showActionMenu(at point: CGPoint) {
        let menu = EntityActionMenu()
        menu.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menu)
        
        NSLayoutConstraint.activate([
            menu.centerXAnchor.constraint(equalTo: view.leadingAnchor, constant: point.x),
            menu.bottomAnchor.constraint(equalTo: view.topAnchor, constant: point.y - 40)
        ])
        
        menu.onAction = { [weak self] action in
            guard let self = self else { return }
            
            switch action {
            case .move:
                self.interactionMode = .move
                // Directly trigger the "Add Move Animation" prompt
                self.presentAnimationPrompt(type: .move)
                menu.removeFromSuperview()
                
            case .rotate:
                self.interactionMode = .rotate
                // Directly trigger the "Add Rotate Animation" prompt
                self.presentAnimationPrompt(type: .rotate)
                menu.removeFromSuperview()
                
            case .lock:
                self.interactionMode = .none
                menu.removeFromSuperview()
                
            case .delete:
                self.deleteSelected()
                menu.removeFromSuperview()
            }
        }
        self.currentActionMenu = menu
    }
    
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {

            let location = gesture.location(in: arView)


            //  STEP 1 — SMOOTH WORLD-SPACE PATH HANDLE DRAG
        if let hit = arView.entity(at: location),
           hit.name.hasPrefix("path."),
           let handleData = hit.components[MotionPathHandleComponent.self] {

            //  ONLY EDIT SELECTED (RED) PATH
            guard handleData.clipID == selectedPathClipID else {
                return
            }

            guard
                let visual = activeMotionPaths[handleData.clipID],
                let clipIndex = timeline.clips.firstIndex(
                    where: { $0.id == handleData.clipID }
                ),
                var path = timeline.clips[clipIndex].motionPath
            else { return }

            switch gesture.state {


                // BEGIN DRAG
                case .began:

                    lastWorldDragPoint = nil

                    // Camera-facing drag plane
                    let cameraForward = -SIMD3<Float>(
                        arView.cameraTransform.matrix.columns.2.x,
                        arView.cameraTransform.matrix.columns.2.y,
                        arView.cameraTransform.matrix.columns.2.z
                    )

                    activeDragPlaneNormal = cameraForward
                    activeDragPlanePoint = hit.position(relativeTo: nil)

                    return


                //DRAGGING
                case .changed:

                    guard
                        let planeNormal = activeDragPlaneNormal,
                        let planePoint = activeDragPlanePoint
                    else { return }

                    let rayOrigin = arView.cameraTransform.translation

                    guard let rayDirection =
                        arView.ray(through: location)?.direction
                    else { return }

                    guard let worldPoint = rayPlaneIntersection(
                        rayOrigin: rayOrigin,
                        rayDirection: rayDirection,
                        planePoint: planePoint,
                        planeNormal: planeNormal
                    ) else { return }

                    //  FIRST FRAME — STORE ONLY
                    if lastWorldDragPoint == nil {
                        lastWorldDragPoint = worldPoint
                        return
                    }

                    //  DELTA-BASED MOVEMENT
                    let delta = worldPoint - lastWorldDragPoint!
                    lastWorldDragPoint = worldPoint

                    switch hit.name {

                    case "path.start":

                        // move entire path
                        path.start    += delta
                        path.control1 += delta
                        path.control2 += delta
                        path.end      += delta

                    case "path.c1":
                        path.control1 += delta

                    case "path.c2":
                        path.control2 += delta

                    case "path.end":
                        path.end += delta


                    default:
                        return
                    }


                    //  move root in WORLD SPACE
                    visual.root.position = path.start

                    // handles in LOCAL SPACE
                    visual.startHandle.position = .zero
                    visual.control1Handle.position = path.control1 - path.start
                    visual.control2Handle.position = path.control2 - path.start
                    visual.endHandle.position = path.end - path.start


                    path.rebuildArcLengthTable()

                    // Save path back into this clip only
                    timeline.clips[clipIndex].motionPath = path

                    // 🔥 STEP 13 — GPU vertex update only
                    if let pathEntity = visual.root.findEntity(named: "MotionPath") as? ModelEntity {

                        MotionPathRenderer.updatePathMesh(
                            entity: pathEntity,
                            path: path
                        )
                    }


                    return



                //END DRAG
                case .ended, .cancelled:

                    activeDragPlaneNormal = nil
                    activeDragPlanePoint = nil
                    lastWorldDragPoint = nil
                    return

                default:
                    break
                }
            }


            //  STEP 2 — NORMAL OBJECT / GIZMO DRAGGING

            switch gesture.state {
                
            case .began:
                saveCurrentStateToUndo()
               
                if let hit = arView.entity(at: location) {
                    if hit.name == GizmoNames.xHandle {
                        currentAxis = .x
                    } else if hit.name == GizmoNames.yHandle {
                        currentAxis = .y
                    } else if hit.name == GizmoNames.zHandle {
                        currentAxis = .z
                    } else {
                        currentAxis = .none
                    }
                   
                    var root: Entity? = hit
                    while let parent = root?.parent, parent.name != "MainAnchor" {
                        root = parent
                    }
                   
                    selectedEntity = root
                    dragStartPosition = root?.position
                    initialRotation = root?.orientation
                   
                    if interactionMode == .none {
                        interactionMode = .move
                    }
                }
               
            case .changed:
                guard editorMode == .edit else { return }
               
                //If selected entity is locked, orbit camera instead
                if let entity = selectedEntity {
                    let isLocked = entity.components[LockComponent.self]?.isLocked ?? false
                    if isLocked {
                        handleCameraOrbit(gesture)
                        return
                    }
                }
               
                guard let entity = selectedEntity, let startPos = dragStartPosition else {
                    handleCameraOrbit(gesture)
                    return
                }
               
                let translation = gesture.translation(in: arView)
                let mouseDelta = SIMD2<Float>(Float(translation.x), Float(translation.y))
               
                switch interactionMode {
                   
                case .move:
                    var newPosition = startPos
                   
                    if currentAxis != .none {
                        let moveDelta = calculateAxisMovement(
                            entity: entity,
                            axis: currentAxis,
                            mouseDelta: mouseDelta,
                            view: arView
                        )
                        newPosition += moveDelta
                       
                    } else {
                        let sensitivity: Float = 0.005
                        let dx = mouseDelta.x * sensitivity
                        let dy = -mouseDelta.y * sensitivity
                       
                        if currentDragMode == .ground {
                            let camOri = arView.cameraTransform.rotation
                            let right = camOri.act([1, 0, 0])
                            let forward = camOri.act([0, 0, -1])

                            let flatForward = simd_normalize(SIMD3<Float>(forward.x, 0, forward.z))
                            let flatRight = simd_normalize(SIMD3<Float>(right.x, 0, right.z))

                            newPosition += (flatRight * dx) + (flatForward * dy)
                            newPosition.y = startPos.y
                           
                        } else {
                            newPosition.x = startPos.x
                            newPosition.z = startPos.z
                            newPosition.y = startPos.y + (dy * 2.0)
                        }
                    }
                    entity.position = newPosition
                   
                case .rotate:
                    let angle = Float(translation.x) * 0.01
                    let rotation = simd_quatf(angle: angle, axis: [0, 1, 0])
                    entity.orientation = rotation * (initialRotation ?? simd_quatf())
                   
                case .none:
                    break
                }
               
            case .ended, .cancelled:
                dragStartPosition = nil
                initialRotation = nil
                currentAxis = .none
               
            default:
                break
            }
        }

    
    
    func calculateWorldDragDelta(_ gesture: UIPanGestureRecognizer) -> SIMD3<Float> {
        
        let translation = gesture.translation(in: arView)
        gesture.setTranslation(.zero, in: arView)
        
        let sensitivity: Float = 0.005
        
        let dx = Float(translation.x) * sensitivity
        let dz = Float(translation.y) * sensitivity
        
        let cam = arView.cameraTransform.rotation
        
        let right = cam.act([1, 0, 0])
        let forward = cam.act([0, 0, 1])
        
        return (right * dx) + (forward * dz)
    }
    
            

    
@objc func toggleMovementTapped(_ sender: UIButton) {
    if currentDragMode == .ground {
        currentDragMode = .vertical
        print("Switched to Vertical (Y) Movement")
        // Update button icon here if needed
        sender.setImage(UIImage(systemName: "arrow.up.and.down"), for: .normal)
        sender.tintColor = .yellow // Visual feedback
    } else {
        currentDragMode = .ground
        print("Switched to Ground (XZ) Movement")
        // Update button icon here if needed
        sender.setImage(UIImage(systemName: "arrow.left.and.right"), for: .normal)
        sender.tintColor = .white
    }
}
    
    
      
    func calculateAxisMovement(entity: Entity, axis: GizmoAxis, mouseDelta: SIMD2<Float>, view: ARView) -> SIMD3<Float> {
        

        var axisVector: SIMD3<Float> = [0, 0, 0]
        
        switch axis {
        case .x: axisVector = [1, 0, 0]
        case .y: axisVector = [0, 1, 0]
        case .z: axisVector = [0, 0, 1]
        case .none: return [0, 0, 0]
        }
        
        // 2. Project 3D points to 2D Screen Space to find the "Visual Line"
        let objectWorldPos = entity.position
        // A point slightly further along the axis
        let axisEndWorldPos = objectWorldPos + axisVector
        
        // Project both to screen coordinates
        guard let screenPosCenter = view.project(objectWorldPos),
              let screenPosAxisEnd = view.project(axisEndWorldPos) else {
            return [0,0,0]
        }
        
        // 3. Calculate the Screen Vector (The direction of the arrow on screen)
        let screenVector = SIMD2<Float>(
            Float(screenPosAxisEnd.x - screenPosCenter.x),
            Float(screenPosAxisEnd.y - screenPosCenter.y)
        )
        
        // Normalize to get direction only
        let screenDir = simd_normalize(screenVector)
        
        // 4. Dot Product
        // This tells us how much we moved the mouse *along* that line
        let projection = simd_dot(mouseDelta, screenDir)
        
        // 5. Sensitivity Factor
        // Adjust this to make the movement feel 1:1 or slower
        let sensitivity: Float = 0.002
        
        // 6. Return the 3D delta
        // We multiply the World Axis Vector by the projected amount
        return axisVector * (projection * sensitivity)
    }
    
    // MARK: - Camera
    func handleCameraOrbit(_ gesture: UIPanGestureRecognizer) {
        if selectedEntity != nil { return }
        let translation = gesture.translation(in: arView)

        yaw -= Float(translation.x) * 0.005
        pitch += Float(translation.y) * 0.005
        pitch = max(-1.0, min(1.4, pitch))

        updateEditorCamera()
        gesture.setTranslation(.zero, in: arView)
    }


    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard editorMode == .edit else { return }

        guard let entity = selectedEntity else {
            distance /= Float(gesture.scale)
            distance = max(1.5, min(15, distance))
            updateEditorCamera()
            gesture.scale = 1.0
            return
        }

        let isLocked = entity.components[LockComponent.self]?.isLocked ?? false
        if isLocked { return }

        guard let modelEntity = entity as? ModelEntity else {
            gesture.scale = 1.0
            return
        }

        switch gesture.state {
        case .changed:
            let scaleFactor = Float(gesture.scale)

            if var wall = modelEntity.components[WallComponent.self] {
                wall.width *= scaleFactor
                wall.height *= scaleFactor
                wall.width = max(0.3, min(wall.width, 10))
                wall.height = max(0.3, min(wall.height, 6))

                let newMesh = MeshResource.generateBox(width: wall.width, height: wall.height, depth: 0.05)
                modelEntity.model?.mesh = newMesh
                modelEntity.components.set(wall)
            }
            
            if var bg = modelEntity.components[BackgroundComponent.self] {
                        // 1. Update the component values
                        bg.width *= scaleFactor
                        bg.height *= scaleFactor

                        // 2. Clamp values so it doesn't disappear or get too huge
                        bg.width = max(0.5, min(bg.width, 15))
                        bg.height = max(0.5, min(bg.height, 10))

                        // 3. REGENERATE THE MESH (The most important step)
                        // This builds a new box with a thickness of 0.05
                        modelEntity.model?.mesh = MeshResource.generateBox(width: bg.width, height: bg.height, depth: 0.05)
                        
                        // 4. REFRESH COLLISION
                        // This ensures you can still grab the background after it grows
                        modelEntity.generateCollisionShapes(recursive: true)

                        // 5. Save the updated component back to the entity
                        modelEntity.components.set(bg)
                    }

            if var ground = modelEntity.components[GroundComponent.self] {
                ground.width *= scaleFactor
                ground.depth *= scaleFactor
                ground.width = max(0.5, min(ground.width, 20))
                ground.depth = max(0.5, min(ground.depth, 20))

                let newMesh = MeshResource.generatePlane(width: ground.width, depth: ground.depth)
                modelEntity.model?.mesh = newMesh
                modelEntity.components.set(ground)
            }
            gesture.scale = 1.0
        default:
            break
        }
    }

    
    func updateEditorCamera() {
        guard activeCamera === editorCamera else { return }

        let x = cameraTarget.x + distance * cos(pitch) * sin(yaw)
        let y = cameraTarget.y + distance * sin(pitch)
        let z = cameraTarget.z + distance * cos(pitch) * cos(yaw)

        editorCamera.position = [x, y, z]
        editorCamera.look(
            at: cameraTarget,
            from: editorCamera.position,
            relativeTo: nil
        )
    }

    func makeCameraVisual() -> ModelEntity {
        let body = ModelEntity(
            mesh: .generateBox(size: [0.2, 0.12, 0.1]),
            materials: [SimpleMaterial(color: .darkGray, isMetallic: true)]
        )

        let lens = ModelEntity(
            mesh: .generateCylinder(height: 0.08, radius: 0.03),
            materials: [SimpleMaterial(color: .black, isMetallic: true)]
        )
        lens.position.z = 0.08

        body.addChild(lens)
        return body
    }

    func spawnSceneCamera() {
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }

        let cameraRoot = Entity()
        cameraRoot.name = "SceneCamera_\(sceneCameras.count)"
        
        cameraRoot.components.set(
            CategoryComponent(toolType: .camera)
        )

        // Camera visual
        let visual = makeCameraVisual()
        visual.generateCollisionShapes(recursive: true)
        visual.components.set(InputTargetComponent())

        // Perspective camera
        let camera = PerspectiveCamera()
        camera.isEnabled = false
        


        cameraRoot.addChild(visual)
        cameraRoot.addChild(camera)

        cameraRoot.position = [0, 1, -1.0]
        anchor.addChild(cameraRoot)

        sceneCameras.append(camera)
        cameraToVisualMap[camera] = cameraRoot
        
        sceneCameraItems.append(
            SceneCameraItem(camera: camera, cameraRoot: cameraRoot)
        )
        
        cameraCollectionView?.reloadData()

    }
    
    func activateEditorCamera() {
        for cam in sceneCameras {
            cam.isEnabled = false
        }

        editorCamera.isEnabled = true
        activeCamera = editorCamera
    }
    
    
    func setActiveCamera(_ camera: PerspectiveCamera) {
        for cam in sceneCameras {
            cam.isEnabled = false
        }

        editorCamera.isEnabled = false
        camera.isEnabled = true
        activeCamera = camera
    }




    @objc func setTopView() {activateEditorCamera(); yaw = 0; pitch = 1.45; distance = 6; updateEditorCamera() }
    @objc func setFrontView() {activateEditorCamera(); yaw = 0; pitch = 0.3; distance = 5; updateEditorCamera() }


    func setupUI() {

        // 1. TOP TOOLBAR (Floating)
        let toolbar = UIStackView()
        toolbar.axis = .horizontal
        toolbar.spacing = 6
        toolbar.alignment = .center
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        toolbar.layer.cornerRadius = 35
        toolbar.isLayoutMarginsRelativeArrangement = true
        toolbar.layoutMargins = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        toolbar.layer.shadowColor = UIColor.black.cgColor
        toolbar.layer.shadowOpacity = 0.1
        toolbar.layer.shadowRadius = 8

        for tool in ToolType.allCases {
            let btn = makeIconToolbarButton(
                title: tool.title,
                systemImage: tool.icon
            )
            btn.addAction(UIAction { _ in
                self.presentToolSheet(tool: tool)
            }, for: .touchUpInside)
            toolbar.addArrangedSubview(btn)
        }



        // 3. 2D / 3D BUTTONS (Bottom-Right)
        let viewModeControl = UISegmentedControl(items: ["2D", "3D"])
        viewModeControl.selectedSegmentIndex = 1
        viewModeControl.translatesAutoresizingMaskIntoConstraints = false
        viewModeControl.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        viewModeControl.selectedSegmentTintColor = UIColor(red: 177/255 , green: 32/255,blue:57/255,alpha: 1.0)
        viewModeControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.white],
            for: .selected
        )
        viewModeControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.label],
            for: .normal
        )

        viewModeControl.addAction(UIAction { _ in
            if viewModeControl.selectedSegmentIndex == 0 {
                self.setTopView()
            } else {
                self.setFrontView()
            }
        }, for: .valueChanged)

        view.addSubview(viewModeControl)

//         4. ROTATE BUTTON (Bottom-Left - Blue Button)
        let rotateBtn = UIButton(type: .system)
        rotateBtn.setImage(UIImage(systemName: "rotate.right"), for: .normal)
        rotateBtn.tintColor = .white
        rotateBtn.backgroundColor = .systemBlue
        rotateBtn.layer.cornerRadius = 22
        rotateBtn.translatesAutoresizingMaskIntoConstraints = false

        rotateBtn.addAction(UIAction { _ in
            self.toggleRotationMode(rotateBtn)
        }, for: .touchUpInside)
        

        let movementToggleButton = UIButton(type: .system)
//        // Default state: Ground Mode icon
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        movementToggleButton.setImage(UIImage(systemName: "arrow.left.and.right", withConfiguration: config), for: .normal)
//        
//        // Styling
        movementToggleButton.tintColor = .white
        movementToggleButton.backgroundColor = .systemBlue
        movementToggleButton.layer.cornerRadius = 20
//        
//        // Shadow
        movementToggleButton.layer.shadowColor = UIColor.black.cgColor
        movementToggleButton.layer.shadowOpacity = 0.3
        movementToggleButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        movementToggleButton.layer.shadowRadius = 4
        
        movementToggleButton.translatesAutoresizingMaskIntoConstraints = false
        movementToggleButton.addTarget(self, action: #selector(toggleMovementTapped(_:)), for: .touchUpInside)
        
//                let undoBtn = UIButton(type: .system)
//                undoBtn.setImage(UIImage(systemName: "arrow.uturn.backward"), for: .normal) // Standard icon
//                undoBtn.tintColor = .white
//                undoBtn.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
//                undoBtn.layer.cornerRadius = 20
//                undoBtn.translatesAutoresizingMaskIntoConstraints = false
//                undoBtn.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
//
//                let redoBtn = UIButton(type: .system)
//                redoBtn.setImage(UIImage(systemName: "arrow.uturn.forward"), for: .normal)
//                redoBtn.tintColor = .white
//                redoBtn.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
//                redoBtn.layer.cornerRadius = 20
//                redoBtn.translatesAutoresizingMaskIntoConstraints = false
//                redoBtn.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)
//        
//                let exportBtn = UIButton(type: .system)
//                exportBtn.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
//                exportBtn.tintColor = .white
//                exportBtn.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
//                exportBtn.layer.cornerRadius = 20
//                exportBtn.translatesAutoresizingMaskIntoConstraints = false
//                exportBtn.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
//                
//                view.addSubview(exportBtn)
//                view.addSubview(undoBtn)
//                view.addSubview(redoBtn)

        // 6. ADD TO VIEW
        view.addSubview(toolbar)
        view.addSubview(rotateBtn)
        view.addSubview(movementToggleButton)
        

        // 7. CONSTRAINTS
        NSLayoutConstraint.activate([

            // Toolbar (Top Center)
            toolbar.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 12
            ),
            toolbar.centerXAnchor.constraint(equalTo: view.centerXAnchor),



            // 2D / 3D Control (Bottom Right)
            viewModeControl.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -16
            ),
            viewModeControl.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -20
            ),
            viewModeControl.heightAnchor.constraint(equalToConstant: 32),
            viewModeControl.widthAnchor.constraint(equalToConstant: 120),

            // Rotate Button (Bottom Left)
            rotateBtn.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 16
            ),
            rotateBtn.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -20
            ),
            rotateBtn.widthAnchor.constraint(equalToConstant: 40),
            rotateBtn.heightAnchor.constraint(equalToConstant: 40),
            
            // Movement Toggle Button (Right of Rotate Button)
            movementToggleButton.leadingAnchor.constraint(equalTo: rotateBtn.trailingAnchor, constant: 20),
            movementToggleButton.centerYAnchor.constraint(equalTo: rotateBtn.centerYAnchor),
            movementToggleButton.widthAnchor.constraint(equalToConstant: 40),
            movementToggleButton.heightAnchor.constraint(equalToConstant: 40)

        ])

        // 8. CAMERA COLLECTION VIEW (Right Side)
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = CGSize(width: 120, height: 120)
        layout.minimumLineSpacing = 10

        cameraCollectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )

        cameraCollectionView.register(
            CameraPreviewCell.self,
            forCellWithReuseIdentifier: CameraPreviewCell.reuseID
        )

        cameraCollectionView.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        cameraCollectionView.layer.cornerRadius = 14
        cameraCollectionView.translatesAutoresizingMaskIntoConstraints = false

        cameraCollectionView.dataSource = self
        cameraCollectionView.delegate = self

        view.addSubview(cameraCollectionView)

        NSLayoutConstraint.activate([
            cameraCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            cameraCollectionView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cameraCollectionView.widthAnchor.constraint(equalToConstant: 140),
            cameraCollectionView.heightAnchor.constraint(equalToConstant: 320)
        ])
        
        // 9. SIDEBAR & HIERARCHY
        view.addSubview(sidebarView)
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.addSubview(scrollView)
        scrollView.addSubview(hierarchyStackView)

        sidebarLeadingConstraint = sidebarView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -sidebarWidth)

        NSLayoutConstraint.activate([
            sidebarView.topAnchor.constraint(equalTo: toolbar.topAnchor),
            sidebarView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarView.widthAnchor.constraint(equalToConstant: sidebarWidth),
            sidebarLeadingConstraint,
            
            scrollView.topAnchor.constraint(equalTo: sidebarView.safeAreaLayoutGuide.topAnchor, constant: 60),
            scrollView.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: sidebarView.bottomAnchor),
            
            hierarchyStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hierarchyStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hierarchyStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hierarchyStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hierarchyStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
                
        view.addSubview(layersButton)
        layersButton.addTarget(self, action: #selector(didTapLayersButton), for: .touchUpInside)
        NSLayoutConstraint.activate([
            layersButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            layersButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            layersButton.widthAnchor.constraint(equalToConstant: 44),
            layersButton.heightAnchor.constraint(equalToConstant: 44),
            layersButton.widthAnchor.constraint(equalToConstant: 44),
            layersButton.heightAnchor.constraint(equalToConstant: 44)
        ])
                
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        closeBtn.tintColor = .white
        closeBtn.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
        closeBtn.layer.cornerRadius = 22
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(didTapLayersButton), for: .touchUpInside)

        sidebarView.addSubview(closeBtn)
        NSLayoutConstraint.activate([
            closeBtn.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -16),
            closeBtn.widthAnchor.constraint(equalToConstant: 44),
            closeBtn.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Ensure the sidebar stays on top of the 3D scene
        view.bringSubviewToFront(sidebarView)
        view.bringSubviewToFront(layersButton)

        
    }
    
    @objc private func shotBreakdownTapped() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        print("🎬 Shot Breakdown Tapped")
        
    }
    
    func presentToolSheet(tool: ToolType) {
        let sheet = ToolSheetViewController(tool: tool) { [weak self] item in
            self?.spawnEntity(item: item, toolType: tool)
        }
        present(sheet, animated: true)
    }

    
    @objc func toggleRotationMode(_ button: UIButton) {
        interactionMode = (interactionMode == .move) ? .rotate : .move

        button.backgroundColor = interactionMode == .rotate
            ? .systemOrange
            : .systemBlue
    }

    
    func makeIconToolbarButton(title: String, systemImage: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: systemImage)?
            .applyingSymbolConfiguration(
                UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            )
        config.imagePlacement = .top
        config.imagePadding = 2
        config.title = title
        config.baseForegroundColor = .label

        let button = UIButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 10, weight: .medium)
        return button
    }

    
        func makeViewModeButton(title: String) -> UIButton {
    
            var config = UIButton.Configuration.plain()
            config.title = title
            config.baseForegroundColor = .label
            config.contentInsets = NSDirectionalEdgeInsets(
                top: 6,
                leading: 14,
                bottom: 6,
                trailing: 14
            )
    
            let button = UIButton(configuration: config)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
    
            return button
        }
    

    // MARK: - Grid
    func makeGrid(size: Int, spacing: Float) -> Entity {
        let container = Entity()
        let length = Float(size) * spacing * 2

        for i in -size...size {
            let isMajor = i % 5 == 0

            var xColor: UIColor = isMajor ? .gray : .lightGray.withAlphaComponent(0.8)
            var zColor: UIColor = isMajor ? .gray : .lightGray.withAlphaComponent(0.8)

            if i == 0 {
                xColor = .red
                zColor = .blue
            }

            let xLine = ModelEntity(
                mesh: .generateBox(size: [length, 0.002, 0.002]),
                materials: [SimpleMaterial(color: xColor, isMetallic: false)]
            )
            xLine.position = [0, 0, Float(i) * spacing]
            container.addChild(xLine)

            let zLine = ModelEntity(
                mesh: .generateBox(size: [0.002, 0.002, length]),
                materials: [SimpleMaterial(color: zColor, isMetallic: false)]
            )
            zLine.position = [Float(i) * spacing, 0, 0]
            container.addChild(zLine)
        }

        return container
    }
}

extension CanvasViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sceneCameraItems.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CameraPreviewCell.reuseID,
            for: indexPath
        ) as! CameraPreviewCell

        let cameraItem = sceneCameraItems[indexPath.item]

        guard let mainAnchor =
            arView.scene.findEntity(named: "MainAnchor") as? AnchorEntity
        else { return cell }

        cell.configure(
            sourceAnchor: mainAnchor,
            sourceCamera: cameraItem.camera,
            name: "Camera \(indexPath.item + 1)"
        )

        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let item = sceneCameraItems[indexPath.item]
        setActiveCamera(item.camera)
    }
    
    func setupCameraPreview(
        arView: ARView,
        cameraItem: SceneCameraItem
    ) {

        arView.scene.anchors.removeAll()

        let previewAnchor = AnchorEntity(world: .zero)

        if let mainAnchor = arView.scene.findEntity(named: "MainAnchor") {
            let clone = mainAnchor.clone(recursive: true)
            previewAnchor.addChild(clone)
        }

        let previewCamera = PerspectiveCamera()
        previewCamera.transform = cameraItem.camera.transform
        previewCamera.isEnabled = true

        previewAnchor.addChild(previewCamera)
        arView.scene.addAnchor(previewAnchor)
    }
    
    func spawnCharacter(item: SpawnItem, scale: Float) {

        guard !item.modelFileName.isEmpty else {
            print(" Empty modelFileName")
            return
        }

        do {
            let entity = try Entity.load(named: item.modelFileName)
            entity.scale = SIMD3(repeating: scale)

            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(entity)
            arView.scene.addAnchor(anchor)

            print(" Character spawned successfully")

        } catch {
            print("Failed to load character model:", error)
        }
    }

    
}


// In CanvasViewController.swift

extension CanvasViewController: CharacterDetailDelegate {
    // In CanvasViewController.swift
    
    // In CanvasViewController.swift
    
    func didConfirmCharacterSelection(item: SpawnItem, scale: Float, name: String) {
        print("✅ Character confirmed:", item.title)
        print("📝 Model File To Load:", item.modelFileName) // Verify this prints "Woman1Sit"
        
        // 1. Create a copy of the item to ensure the name is correct
        var finalItem = item
        finalItem.title = name
        
        // 2. CRITICAL FIX: Wrap the async call in 'Task' and use the correct function name
        Task {
            // Use 'spawnEntity', NOT 'spawnCharacter'
            await spawnEntity(
                item: finalItem,
                toolType: .character,
                customName: name,
                scale: scale
            )
        }
        
        dismiss(animated: true)
    }
}

class EntityActionMenu: UIView {
    var onAction: ((ActionType) -> Void)?
    
    enum ActionType {
        case move, rotate, lock, delete
    }
    
    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 20
        sv.alignment = .center
        sv.isLayoutMarginsRelativeArrangement = true
        sv.layoutMargins = UIEdgeInsets(top: 8, left: 24, bottom: 8, right: 24)
        return sv
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    // MARK: - Helper to Update Lock Title
    func setLockTitle(isLocked: Bool) {
        // This finds the button labeled "Lock" or "Unlock" and updates it
        stackView.arrangedSubviews.compactMap { $0 as? UIButton }.forEach { btn in
            if btn.currentTitle == "Lock" || btn.currentTitle == "Unlock" {
                btn.setTitle(isLocked ? "Unlock" : "Lock", for: .normal)
            }
        }
    }
    
        
        // MARK: - New Top Bar UI Elements
        
        private let topBarView: UIView = {
            let view = UIView()
            view.backgroundColor = .black // Or .systemBackground / custom dark color
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()
        
        private let backButton: UIButton = {
            let button = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            button.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
            button.tintColor = .white
            button.translatesAutoresizingMaskIntoConstraints = false
            return button
        }()
        
//        private let sceneNameLabel: UILabel = {
//            let label = UILabel()
//            label.text = "Living Room" // Default text
//            label.font = .systemFont(ofSize: 17, weight: .semibold)
//            label.textColor = .white
//            label.textAlignment = .center
//            label.translatesAutoresizingMaskIntoConstraints = false
//            return label
//        }()
   
        // ... existing properties ...
    
    private func setupUI() {
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        layer.cornerRadius = 28
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 12
        
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        addMenuButton(title: "Move", action: .move)
        addSeparator()
        addMenuButton(title: "Rotate", action: .rotate)
        addSeparator()
        addMenuButton(title: "Lock", action: .lock)
        addSeparator()
        addMenuButton(title: "Delete", action: .delete, isDestructive: true)
    }
    
    private func addMenuButton(title: String, action: ActionType, isDestructive: Bool = false) {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        btn.tintColor = isDestructive ? UIColor(red: 169/255 , green: 32/255, blue: 57/255, alpha: 1) : .label
        btn.addAction(UIAction { [weak self] _ in self?.onAction?(action) }, for: .touchUpInside)
        stackView.addArrangedSubview(btn)
    }
    
    private func addSeparator() {
        let line = UIView()
        line.backgroundColor = .separator
        line.widthAnchor.constraint(equalToConstant: 1).isActive = true
        line.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stackView.addArrangedSubview(line)
    }
}

