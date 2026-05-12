import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

extension CanvasViewController {

    
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
        playButton.addTarget(
            self,
            action: #selector(playTimeline),
            for: .touchUpInside
        )
        
        pauseButton = UIButton(type: .system)
        pauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        pauseButton.tintColor = .white
        pauseButton.backgroundColor = .systemOrange
        pauseButton.layer.cornerRadius = 22
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        pauseButton.isHidden = true
        pauseButton.addTarget(
            self,
            action: #selector(pauseTimeline),
            for: .touchUpInside
        )
        
        stopButton = UIButton(type: .system)
        stopButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        stopButton.tintColor = .white
        stopButton.backgroundColor = .systemRed
        stopButton.layer.cornerRadius = 22
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.isHidden = true
        stopButton.addTarget(
            self,
            action: #selector(stopTimeline),
            for: .touchUpInside
        )
        
        playbackButtonStack = UIStackView(arrangedSubviews: [
            playButton,
            pauseButton,
            stopButton,
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
            timelineContainer.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            timelineContainer.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            timelineContainer.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor
            ),
            timelineContainer.heightAnchor.constraint(equalToConstant: 120),
            
            // Playback buttons (bottom-left, above timeline)
            playbackButtonStack.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 16
            ),
            playbackButtonStack.bottomAnchor.constraint(
                equalTo: timelineContainer.topAnchor,
                constant: -12
            ),
            
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
            
            // 🔒 Lock state lives on the PATH ROOT
            let isLocked =
            visual.root.components[LockComponent.self]?.isLocked ?? false
            
            // 🎯 Color priority:
            // 1. Locked  → Gray
            // 2. Selected → Red
            // 3. Default → Blue
            let color: UIColor
            if isLocked {
                color = .systemGray
            } else if clipID == selectedPathClipID {
                color = .systemRed
            } else {
                color = .systemBlue
            }
            
            MotionPathRenderer.setPathColor(
                entity: pathEntity,
                color: color
            )
        }
    }

    
    func shouldShowStartHandle(for clip: AnimationClip) -> Bool {

        // Only position clips with motion paths are relevant
        guard clip.track == .position, clip.motionPath != nil else {
            return false
        }

        // Find ANY earlier motion path for this entity
        let hasPreviousPath = timeline.clips.contains {
            $0.entityName == clip.entityName &&
            $0.motionPath != nil &&
            $0.startTime < clip.startTime
        }

        // Show start handle ONLY if this is the FIRST path
        return !hasPreviousPath
    }



    func previousPathClip(
        for clip: AnimationClip
    ) -> AnimationClip? {
        timeline.clips
            .filter {
                $0.entityName == clip.entityName && $0.motionPath != nil
                    && $0.startTime + $0.duration <= clip.startTime
            }
            .sorted { $0.startTime < $1.startTime }
            .last
    }


    @objc func playTimeline() {
        
        // RESUME FROM PAUSE
        
        if playbackState == .paused {
            // Adjust start time so playback resumes correctly
            playbackStartTime =
            CACurrentMediaTime()
            - CFTimeInterval(currentTimelineTime)
            
            startPlayback()
            playbackState = .playing
            
            playButton.isHidden = true
            pauseButton.isHidden = true
            stopButton.isHidden = true
            // Show pause inside pill, hide play
            (view.viewWithTag(9503) as? UIButton)?.isHidden = false
            (view.viewWithTag(9505) as? UIButton)?.isHidden = true
            
            return
        }
        
        // START FROM BEGINNING
        
        guard editorMode == .edit else { return }
        guard !timeline.clips.isEmpty else { return }
        
        enterTimelineMode()
        
        // Show floating scrubber pill instead of the old timelineContainer
        timelineContainer.isHidden = true
        view.viewWithTag(9500)?.isHidden = false
        playButton.isHidden = true
        pauseButton.isHidden = true
        stopButton.isHidden = true
        // Show pause in pill, hide play-in-pill
        (view.viewWithTag(9503) as? UIButton)?.isHidden = false
        (view.viewWithTag(9505) as? UIButton)?.isHidden = true
        
        // Setup scrubber
        scrubber.minimumValue = 0
        scrubber.maximumValue = timeline.duration
        scrubber.value = 0
        // Update floating pill time labels
        if let elapsedLbl = view.viewWithTag(9501) as? UILabel {
            elapsedLbl.text = "00:00"
        }
        if let remainLbl = view.viewWithTag(9502) as? UILabel {
            let d = timeline.duration
            remainLbl.text = String(format: "%02d:%02d", Int(d) / 60, Int(d) % 60)
        }
        
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
        stopAllWalkCycles()
        
        pauseButton.isHidden = true
        playButton.isHidden = true
        // Inside pill: show play, hide pause
        (view.viewWithTag(9503) as? UIButton)?.isHidden = true
        (view.viewWithTag(9505) as? UIButton)?.isHidden = false
        
    }

    
    func startPlayback() {
        stopPlayback()  // safety

        // FIX 1: Use a proxy object so CADisplayLink doesn't retain self strongly.
        // Without this, a dismissed modal VC is kept alive indefinitely.
        let proxy = DisplayLinkProxy()
        proxy.target = self
        displayLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
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
        // Update floating pill time labels
        if let elapsedLbl = view.viewWithTag(9501) as? UILabel {
            let t = currentTimelineTime
            elapsedLbl.text = String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
        }
        if let remainLbl = view.viewWithTag(9502) as? UILabel {
            let r = max(0, timeline.duration - currentTimelineTime)
            remainLbl.text = String(format: "%02d:%02d", Int(r) / 60, Int(r) % 60)
        }
        evaluateTimeline(at: currentTimelineTime)
    }

    
    @objc func stopTimeline() {
        guard editorMode == .timeline else { return }
        
        stopPlayback()
        playbackState = .stopped
        
        scrubber.value = 0
        currentTimelineTime = 0
        playbackStartTime = 0
        
        stopAllWalkCycles()
        exitTimelineMode()
        
        timelineContainer.isHidden = true
        view.viewWithTag(9500)?.isHidden = true
        playButton.isHidden = false
        stopButton.isHidden = true
        pauseButton.isHidden = true
        
        // Reset pill buttons
        (view.viewWithTag(9503) as? UIButton)?.isHidden = false
        (view.viewWithTag(9505) as? UIButton)?.isHidden = true
        
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
                let entity = timelineEntityCache[entityName] ?? mainAnchor?.findEntity(named: entityName),
                let baseTransform = baseTransforms[entityName]
            else { continue }
            
            var translation = baseTransform.translation
            var rotation = baseTransform.rotation
            var scale = baseTransform.scale
            var fov: Float? = nil

            // A zoom clip targets the cameraRoot (a plain Entity whose name starts with
            // "SceneCameraRoot_").  The actual PerspectiveCamera is a child of that root.
            // Look for the camera either directly (if this entity IS a PerspectiveCamera)
            // or inside its children (the normal camera-root case).
            let perspectiveCamera: PerspectiveCamera? = {
                if let pc = entity as? PerspectiveCamera { return pc }
                return entity.children.compactMap { $0 as? PerspectiveCamera }.first
            }()
            if let pc = perspectiveCamera {
                fov = baseFOVs[entityName] ?? pc.camera.fieldOfViewInDegrees
            }
            
            // Sort clips by start time (important!)
            let sortedClips = clips.sorted { $0.startTime < $1.startTime }
            
            for clip in sortedClips {
                
                let localTime = time - clip.startTime
                
                let progress: Float
                if localTime <= 0 {
                    continue
                } else if localTime >= clip.duration {
                    progress = 1  // 🔑 HOLD FINAL VALUE
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
                        let t = max(0, min(1, (time - clip.startTime) / clip.duration))
                        if clip.type == .walk {
                            // Walk: position + facing + skeleton set directly on entity
                            applyWalkToEntity(entity, path: path, progress: t)
                            // Sync back so the final Transform(...) at the bottom of the
                            // loop doesn't overwrite what applyWalkToEntity just set
                            translation = entity.position
                            rotation    = entity.transform.rotation
                        } else {
                            translation = path.evaluateConstantSpeed(t)
                        }
                    }
                    
                case .rotation:
                    // New model: fromValue = axis, toValue.x = totalRadians (unbounded)
                    // evaluateTimeline interpolates from 0 to totalRadians * eased
                    let axis         = RotationPathRenderer.axisOf(clip)
                    let totalRadians = RotationPathRenderer.totalRadiansOf(clip)
                    let delta        = simd_quatf(angle: totalRadians * eased, axis: axis.simdAxis)
                    rotation         = delta * rotation
                    
                case .scale:
                    scale *= value
                    
                case .fov:
                    // Interpolate FOV between fromValue.x and toValue.x
                    let scalarVal = simd_mix(clip.fromValue.x, clip.toValue.x, eased)
                    fov = scalarVal
                }
            }
            
            entity.transform = Transform(
                scale: scale,
                rotation: rotation,
                translation: translation
            )

            // Apply the interpolated FOV to the PerspectiveCamera (may be the entity
            // itself or a child of a SceneCameraRoot_ entity).
            if let pc = perspectiveCamera, let f = fov {
                pc.camera.fieldOfViewInDegrees = f
            }
        }
    }

    func evaluateEntityTransform(
        entityName: String,
        at time: Float
    ) -> Transform {
        
        // Base transform before any animation
        guard let base = baseTransforms[entityName] else {
            return Transform()
        }
        
        var translation = base.translation
        var rotation = base.rotation
        var scale = base.scale
        
        // All clips affecting this entity before given time
        let clips = timeline.clips
            .filter {
                $0.entityName == entityName && $0.startTime <= time
            }
            .sorted { $0.startTime < $1.startTime }
        
        for clip in clips {
            
            let localTime = time - clip.startTime
            
            let progress: Float
            if localTime <= 0 {
                continue
            } else if localTime >= clip.duration {
                progress = 1
            } else {
                progress = localTime / clip.duration
            }
            
            let eased = applyEasing(progress, easing: clip.easing)
            
            switch clip.track {
                
            case .position:
                
                if let path = clip.motionPath {
                    translation = path.evaluateConstantSpeed(eased)
                } else {
                    translation = simd_mix(
                        clip.fromValue,
                        clip.toValue,
                        SIMD3<Float>(repeating: eased)
                    )
                }
                
            case .rotation:
                let axis         = RotationPathRenderer.axisOf(clip)
                let totalRadians = RotationPathRenderer.totalRadiansOf(clip)
                let delta        = simd_quatf(angle: totalRadians * eased, axis: axis.simdAxis)
                rotation         = delta * rotation
                
            case .scale:
                scale *= simd_mix(
                    clip.fromValue,
                    clip.toValue,
                    SIMD3<Float>(repeating: eased)
                )
                
            case .fov:
                break
            }
        }
        
        return Transform(
            scale: scale,
            rotation: rotation,
            translation: translation
        )
    }

    
    func setupScrubber() {
        // ── Floating pill container ──────────────────────────────────────
        let pill = UIView()
        pill.tag = 9500
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.clipsToBounds = true
        pill.layer.cornerRadius = 22
        pill.isHidden = true
        view.addSubview(pill)

        // Glass background
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.isUserInteractionEnabled = false
        pill.addSubview(blur)

        // Border for extra polish
        pill.layer.borderWidth = 0.5
        pill.layer.borderColor = UIColor(white: 1, alpha: 0.12).cgColor

        // ── Time labels ─────────────────────────────────────────────────
        let elapsed = UILabel()
        elapsed.tag = 9501
        elapsed.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        elapsed.textColor = UIColor(white: 1, alpha: 0.70)
        elapsed.text = "00:00"
        elapsed.translatesAutoresizingMaskIntoConstraints = false

        let remaining = UILabel()
        remaining.tag = 9502
        remaining.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        remaining.textColor = UIColor(white: 1, alpha: 0.40)
        remaining.text = "00:00"
        remaining.translatesAutoresizingMaskIntoConstraints = false

        // ── Slider ──────────────────────────────────────────────────────
        scrubber = UISlider()
        scrubber.translatesAutoresizingMaskIntoConstraints = false
        scrubber.minimumValue = 0
        scrubber.maximumValue = 1
        scrubber.value = 0
        scrubber.minimumTrackTintColor = .white
        scrubber.maximumTrackTintColor = UIColor(white: 1, alpha: 0.18)
        // Small circular thumb matching native player
        let thumbSize: CGFloat = 12
        let thumbImage = UIGraphicsImageRenderer(size: CGSize(width: thumbSize, height: thumbSize)).image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: thumbSize, height: thumbSize))
        }
        scrubber.setThumbImage(thumbImage, for: .normal)
        let thumbSizeHL: CGFloat = 16
        let thumbHL = UIGraphicsImageRenderer(size: CGSize(width: thumbSizeHL, height: thumbSizeHL)).image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: thumbSizeHL, height: thumbSizeHL))
        }
        scrubber.setThumbImage(thumbHL, for: .highlighted)
        scrubber.addTarget(
            self,
            action: #selector(scrubberChanged(_:)),
            for: .valueChanged
        )

        // ── Pause / Play / Stop buttons inside pill ─────────────────────
        let pillPauseBtn = UIButton(type: .system)
        pillPauseBtn.tag = 9503
        let pauseCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        pillPauseBtn.setImage(UIImage(systemName: "pause.fill", withConfiguration: pauseCfg), for: .normal)
        pillPauseBtn.tintColor = .white
        pillPauseBtn.translatesAutoresizingMaskIntoConstraints = false
        pillPauseBtn.addTarget(self, action: #selector(pauseTimeline), for: .touchUpInside)

        let pillStopBtn = UIButton(type: .system)
        pillStopBtn.tag = 9504
        let stopCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        pillStopBtn.setImage(UIImage(systemName: "stop.fill", withConfiguration: stopCfg), for: .normal)
        pillStopBtn.tintColor = UIColor(red: 1.0, green: 0.38, blue: 0.38, alpha: 1.0)
        pillStopBtn.translatesAutoresizingMaskIntoConstraints = false
        pillStopBtn.addTarget(self, action: #selector(stopTimeline), for: .touchUpInside)

        // Play button inside pill (shown when paused)
        let pillPlayBtn = UIButton(type: .system)
        pillPlayBtn.tag = 9505
        let playCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        pillPlayBtn.setImage(UIImage(systemName: "play.fill", withConfiguration: playCfg), for: .normal)
        pillPlayBtn.tintColor = .white
        pillPlayBtn.translatesAutoresizingMaskIntoConstraints = false
        pillPlayBtn.isHidden = true
        pillPlayBtn.addTarget(self, action: #selector(playTimeline), for: .touchUpInside)

        pill.addSubview(elapsed)
        pill.addSubview(scrubber)
        pill.addSubview(remaining)
        pill.addSubview(pillPauseBtn)
        pill.addSubview(pillPlayBtn)
        pill.addSubview(pillStopBtn)

        NSLayoutConstraint.activate([
            // Pill position — floating above the bottom of the viewport
            pill.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            pill.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            pill.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -56),
            pill.heightAnchor.constraint(equalToConstant: 44),

            // Blur fills the pill
            blur.topAnchor.constraint(equalTo: pill.topAnchor),
            blur.leadingAnchor.constraint(equalTo: pill.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: pill.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: pill.bottomAnchor),

            // Elapsed label
            elapsed.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 14),
            elapsed.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            elapsed.widthAnchor.constraint(equalToConstant: 38),

            // Stop button (rightmost)
            pillStopBtn.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10),
            pillStopBtn.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            pillStopBtn.widthAnchor.constraint(equalToConstant: 32),
            pillStopBtn.heightAnchor.constraint(equalToConstant: 32),

            // Pause button (to the left of stop)
            pillPauseBtn.trailingAnchor.constraint(equalTo: pillStopBtn.leadingAnchor, constant: -4),
            pillPauseBtn.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            pillPauseBtn.widthAnchor.constraint(equalToConstant: 32),
            pillPauseBtn.heightAnchor.constraint(equalToConstant: 32),

            // Play button (same position as pause, shown when paused)
            pillPlayBtn.trailingAnchor.constraint(equalTo: pillStopBtn.leadingAnchor, constant: -4),
            pillPlayBtn.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            pillPlayBtn.widthAnchor.constraint(equalToConstant: 32),
            pillPlayBtn.heightAnchor.constraint(equalToConstant: 32),

            // Remaining label (to the left of pause)
            remaining.trailingAnchor.constraint(equalTo: pillPauseBtn.leadingAnchor, constant: -6),
            remaining.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            remaining.widthAnchor.constraint(equalToConstant: 38),

            // Slider
            scrubber.leadingAnchor.constraint(equalTo: elapsed.trailingAnchor, constant: 8),
            scrubber.trailingAnchor.constraint(equalTo: remaining.leadingAnchor, constant: -8),
            scrubber.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
        ])
    }

    
    @objc func scrubberChanged(_ sender: UISlider) {
        let time = sender.value
        // Update floating pill time labels during manual scrub
        if let elapsedLbl = view.viewWithTag(9501) as? UILabel {
            elapsedLbl.text = String(format: "%02d:%02d", Int(time) / 60, Int(time) % 60)
        }
        if let remainLbl = view.viewWithTag(9502) as? UILabel {
            let r = max(0, scrubber.maximumValue - time)
            remainLbl.text = String(format: "%02d:%02d", Int(r) / 60, Int(r) % 60)
        }
        currentTimelineTime = time
        evaluateTimeline(at: time)
    }

    
    func makeRay(from screenPoint: CGPoint)
    -> (origin: SIMD3<Float>, direction: SIMD3<Float>)
    {
        
        guard let ray = arView.ray(through: screenPoint) else {
            
            // fallback forward ray
            let cam = arView.cameraTransform
            let forward = cam.rotation.act([0, 0, -1])
            return (cam.translation, forward)
        }
        
        return (ray.origin, ray.direction)
    }

    
    func hideAllMotionPaths() {
        for (_, visual) in activeMotionPaths {
            visual.root.isEnabled = false
            visual.startHandle?.isEnabled = false
        }
    }

    
    func showAllMotionPaths() {
        for (_, visual) in activeMotionPaths {
            visual.root.isEnabled = true
            visual.startHandle?.isEnabled = true    // start handle is on entity, show separately
        }
    }

    
    func enterTimelineMode() {
        editorMode = .timeline
        hideAllMotionPaths()
        hideAllRotationArcs()   // hide arcs during playback; restored in exitTimelineMode
        hideAnimationPanel()
        selectedEntity = nil
        
        baseTransforms.removeAll()
        baseFOVs.removeAll()
        timelineEntityCache.removeAll()

        // Snapshot only the user scene entities under MainAnchor.
        // Iterating arView.scene.anchors would include the Grid anchor (40,000+ line entities),
        // causing massive memory allocation and frame drops.
        // FIX 6: Also skip "PathContainer" — its children (PathRoot_ entities) hold
        // motion path geometry that must not be snapshotted as user-scene entities.
        let skipNames: Set<String> = ["Grid", "EditorCamera", "PathContainer"]
        mainAnchor?.children
            .filter { !skipNames.contains($0.name) && !$0.name.isEmpty }
            .forEach { entity in
                baseTransforms[entity.name] = entity.transform
                timelineEntityCache[entity.name] = entity
                // If this entity is a camera-root (SceneCameraRoot_), snapshot the FOV
                // from its PerspectiveCamera child, keyed under the root's name — because
                // zoom AnimationClips target the root name, not the camera child name.
                if let pc = entity as? PerspectiveCamera {
                    baseFOVs[entity.name] = pc.camera.fieldOfViewInDegrees
                } else if let pc = entity.children.compactMap({ $0 as? PerspectiveCamera }).first {
                    baseFOVs[entity.name] = pc.camera.fieldOfViewInDegrees
                }
            }
    }

    
    // MARK: - Shot Player Playback Context
    //
    // Called by ShotPlayerViewController (via closure) so that evaluateTimeline
    // has valid baseTransforms / baseFOVs / timelineEntityCache without changing
    // the editor's UI state (editorMode, motion path visibility, etc.).

    func enterShotPlaybackMode() {
        baseTransforms.removeAll()
        baseFOVs.removeAll()
        timelineEntityCache.removeAll()

        let skipNames: Set<String> = ["Grid", "EditorCamera", "PathContainer"]
        mainAnchor?.children
            .filter { !skipNames.contains($0.name) && !$0.name.isEmpty }
            .forEach { entity in
                baseTransforms[entity.name]     = entity.transform
                timelineEntityCache[entity.name] = entity
                // Zoom clips target the cameraRoot name; snapshot its child camera's FOV
                // under the same key so evaluateTimeline can restore it correctly.
                if let pc = entity as? PerspectiveCamera {
                    baseFOVs[entity.name] = pc.camera.fieldOfViewInDegrees
                } else if let pc = entity.children.compactMap({ $0 as? PerspectiveCamera }).first {
                    baseFOVs[entity.name] = pc.camera.fieldOfViewInDegrees
                }
            }
    }

    func exitShotPlaybackMode() {
        // Restore every entity to its pre-playback state so the editor scene is clean.
        for (name, transform) in baseTransforms {
            mainAnchor?.findEntity(named: name)?.transform = transform
        }
        // baseFOVs is keyed by the cameraRoot name; the PerspectiveCamera is a child.
        for (name, fov) in baseFOVs {
            guard let entity = mainAnchor?.findEntity(named: name) else { continue }
            let camera: PerspectiveCamera? =
                (entity as? PerspectiveCamera) ??
                entity.children.compactMap { $0 as? PerspectiveCamera }.first
            camera?.camera.fieldOfViewInDegrees = fov
        }
        baseTransforms.removeAll()
        baseFOVs.removeAll()
        timelineEntityCache.removeAll()
    }

    func exitTimelineMode() {
        editorMode = .edit
        // Only restore paths and arcs if we are in the editor view.
        // If a scene camera is still active, setActiveCamera already hid them
        // and activateEditorCamera will restore them when the user exits the camera.
        if activeCamera === editorCamera {
            showAllMotionPaths()
            showAllRotationArcs()
        }
        for (name, transform) in baseTransforms {
            mainAnchor?.findEntity(named: name)?.transform = transform
        }
        // baseFOVs is keyed by the cameraRoot name; the PerspectiveCamera is a child.
        for (name, fov) in baseFOVs {
            guard let entity = mainAnchor?.findEntity(named: name) else { continue }
            let camera: PerspectiveCamera? =
                (entity as? PerspectiveCamera) ??
                entity.children.compactMap { $0 as? PerspectiveCamera }.first
            camera?.camera.fieldOfViewInDegrees = fov
        }
        baseTransforms.removeAll()
        baseFOVs.removeAll()
        timelineEntityCache.removeAll()
    }


    func moveLaterPaths(
        after clipIndex: Int,
        entityName: String,
        delta: SIMD3<Float>
    ) {
        for i in timeline.clips.indices {
            guard i > clipIndex else { continue }
            guard timeline.clips[i].entityName == entityName else { continue }
            guard var p = timeline.clips[i].motionPath else { continue }
            
            p.start += delta
            p.end += delta
            p.control1 += delta
            p.control2 += delta
            p.rebuildArcLengthTable()
            timeline.clips[i].motionPath = p
            
            if let visual = activeMotionPaths[timeline.clips[i].id] {
                visual.root.position = p.start
                visual.startHandle?.position = .zero
                visual.control1Handle.position = p.control1 - p.start
                visual.control2Handle.position = p.control2 - p.start
                visual.endHandle.position = p.end - p.start
                
                if let entity =
                    visual.root.findEntity(named: "MotionPath") as? ModelEntity
                {
                    MotionPathRenderer.updatePathMesh(entity: entity, path: p)
                }
            }
        }
    }


    
    func debugPrintTimeline() {
        print("Timeline Clips:")
        for clip in timeline.clips {
            print(
                """
                ├─ \(clip.type.rawValue.uppercased())
                   Entity: \(clip.entityName)
                   Start: \(clip.startTime)s
                   Duration: \(clip.duration)s
                """
            )
        }
    }

}
