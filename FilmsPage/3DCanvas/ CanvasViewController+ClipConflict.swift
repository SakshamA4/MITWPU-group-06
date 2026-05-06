import UIKit
import RealityKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Clip Conflict Detection & Resolution
//
// Hooks into showPathEditToolbar's Apply action (editing existing clips) and
// into applyCameraMovementPreset / applyStaticShotPreset (adding new clips).
//
// When clipIndex == timeline.clips.count it is treated as a "new clip append"
// sentinel — commitClipTimingChange appends instead of replacing.
// ─────────────────────────────────────────────────────────────────────────────

extension CanvasViewController {

    // ── MARK: Detection ──────────────────────────────────────────────────────

    /// Returns the first clip that `editedClip` overlaps, looking only at
    /// clips for the same entity that start AFTER `editedClip`.
    ///
    /// - Parameters:
    ///   - editedClip:  The candidate clip with proposed new timing.
    ///   - replacingID: The UUID of the clip being replaced (excluded from search).
    ///                  Pass a fresh `UUID()` when adding a brand-new clip so
    ///                  nothing is accidentally excluded.
    func detectClipConflict(
        editedClip:  AnimationClip,
        replacingID: UUID
    ) -> AnimationClip? {
        let editedEnd = editedClip.startTime + editedClip.duration

        let siblings = timeline.clips
            .filter { $0.entityName == editedClip.entityName && $0.id != replacingID }
            .sorted { $0.startTime < $1.startTime }

        return siblings.first {
            $0.startTime >= editedClip.startTime && editedEnd > $0.startTime
        }
    }

    // ── MARK: Resolution Dialog ───────────────────────────────────────────────

    /// Presents a UIAlertController with three resolution options whenever
    /// a timing edit (or new addition) would cause an overlap.
    ///
    /// `clipIndex` may equal `timeline.clips.count` when this is called for a
    /// brand-new clip that hasn't been inserted yet (camera shot addition).
    func presentClipConflictResolution(
        editedClip:      AnimationClip,
        replacingID:     UUID,
        conflicting:     AnimationClip,
        clipIndex:       Int,
        originalEndTime: Float
    ) {
        let alert = UIAlertController(
            title:   "Animation Timing Conflict",
            message: "The updated animation timing overlaps with another animation for this entity. Choose how you want to resolve the conflict.",
            preferredStyle: .alert
        )

        // ── Option 1: Cancel ─────────────────────────────────────────────────
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // ── Option 2: Shift Following Animations ─────────────────────────────
        alert.addAction(UIAlertAction(
            title: "Shift Following Animations",
            style: .default
        ) { [weak self] _ in
            guard let self else { return }

            self.commitClipTimingChange(
                newClip:   editedClip,
                oldClipID: replacingID,
                clipIndex: clipIndex
            )

            let originalGap   = conflicting.startTime - originalEndTime
            let editedEnd     = editedClip.startTime + editedClip.duration
            let newClipBStart = editedEnd + originalGap
            let shiftDelta    = newClipBStart - conflicting.startTime

            if shiftDelta > 0.0001 {
                self.shiftSubsequentClips(
                    entityName:    editedClip.entityName,
                    startingAfter: conflicting.startTime,
                    delta:         shiftDelta
                )
            }
        })

        // ── Option 3: Merge Animations ───────────────────────────────────────
        alert.addAction(UIAlertAction(
            title: "Merge Animations",
            style: .default
        ) { [weak self] _ in
            guard let self else { return }

            self.commitClipTimingChange(
                newClip:   editedClip,
                oldClipID: replacingID,
                clipIndex: clipIndex
            )

            let editedEnd   = editedClip.startTime + editedClip.duration
            let originalEnd = conflicting.startTime + conflicting.duration
            let newDuration = max(0, originalEnd - editedEnd)

            self.mergeConflictingClip(
                conflicting:  conflicting,
                newStartTime: editedEnd,
                newDuration:  newDuration
            )
        })

        present(alert, animated: true)
    }

    // ── MARK: Commit ──────────────────────────────────────────────────────────

    /// Writes a new clip into the timeline and re-keys motion path visuals.
    ///
    /// When `clipIndex == timeline.clips.count` the clip is appended (new-clip
    /// sentinel used by camera shot additions). In that case `oldClipID` is
    /// ignored and visuals are shown fresh instead of re-keyed.
    func commitClipTimingChange(
        newClip:   AnimationClip,
        oldClipID: UUID,
        clipIndex: Int
    ) {
        let isNewClip = clipIndex >= timeline.clips.count

        if isNewClip {
            // Brand-new clip — append and show visuals fresh
            timeline.addClip(newClip)
            if newClip.motionPath != nil {
                showMotionPath(for: newClip)
            }
            if newClip.track == .rotation,
               let entity = arView.scene.findEntity(named: newClip.entityName) {
                showRotationArc(for: newClip, on: entity)
            }
            return
        }

        // Existing clip — replace in-place
        timeline.clips[clipIndex] = newClip

        // Re-key motion path visual from oldClipID → newClip.id
        if let visual = activeMotionPaths.removeValue(forKey: oldClipID) {
            activeMotionPaths[newClip.id] = visual
            let newComp = MotionPathHandleComponent(clipID: newClip.id)
            visual.startHandle?.components.set(newComp)
            visual.control1Handle.components.set(newComp)
            visual.control2Handle.components.set(newComp)
            visual.endHandle.components.set(newComp)
            if selectedPathClipID == oldClipID {
                selectedPathClipID = newClip.id
            }
        }

        // Re-key rotation arc visual
        if let arcVisual = activeRotationArcs.removeValue(forKey: oldClipID) {
            activeRotationArcs[newClip.id] = arcVisual
            arcVisual.startHandle.components.set(RotationArcComponent(
                clipID: newClip.id, role: .start))
            arcVisual.endHandle.components.set(RotationArcComponent(
                clipID: newClip.id, role: .end))
            if selectedArcClipID == oldClipID {
                selectedArcClipID = newClip.id
            }
        }
    }

    // ── MARK: Shift ───────────────────────────────────────────────────────────

    /// Shifts every clip for `entityName` whose startTime is >= `startingAfter`
    /// forward by `delta` seconds, and repositions their motion path visuals.
    func shiftSubsequentClips(
        entityName:    String,
        startingAfter boundary: Float,
        delta: Float
    ) {
        for index in timeline.clips.indices {
            let clip = timeline.clips[index]
            guard clip.entityName == entityName,
                  clip.startTime >= boundary else { continue }

            let oldID = clip.id

            let shifted = AnimationClip(
                entityName: clip.entityName,
                entityID:   clip.entityID,
                type:       clip.type,
                track:      clip.track,
                easing:     clip.easing,
                startTime:  clip.startTime + delta,
                duration:   clip.duration,
                fromValue:  clip.fromValue,
                toValue:    clip.toValue,
                motionPath: clip.motionPath
            )
            timeline.clips[index] = shifted

            reKeyVisuals(oldID: oldID, newClip: shifted)
        }
    }

    // ── MARK: Merge ───────────────────────────────────────────────────────────

    /// Adjusts the conflicting clip to start at `newStartTime` with `newDuration`,
    /// keeping its original end time.
    func mergeConflictingClip(
        conflicting:  AnimationClip,
        newStartTime: Float,
        newDuration:  Float
    ) {
        guard let index = timeline.clips.firstIndex(where: { $0.id == conflicting.id })
        else { return }

        let oldID  = conflicting.id
        let merged = AnimationClip(
            entityName: conflicting.entityName,
            entityID:   conflicting.entityID,
            type:       conflicting.type,
            track:      conflicting.track,
            easing:     conflicting.easing,
            startTime:  newStartTime,
            duration:   max(0.01, newDuration),
            fromValue:  conflicting.fromValue,
            toValue:    conflicting.toValue,
            motionPath: conflicting.motionPath
        )
        timeline.clips[index] = merged

        reKeyVisuals(oldID: oldID, newClip: merged)
    }

    // ── MARK: Visual Re-keying ────────────────────────────────────────────────

    /// Transfers motion-path and rotation-arc visuals from `oldID` to `newClip.id`.
    private func reKeyVisuals(oldID: UUID, newClip: AnimationClip) {
        if let visual = activeMotionPaths.removeValue(forKey: oldID) {
            activeMotionPaths[newClip.id] = visual
            let comp = MotionPathHandleComponent(clipID: newClip.id)
            visual.startHandle?.components.set(comp)
            visual.control1Handle.components.set(comp)
            visual.control2Handle.components.set(comp)
            visual.endHandle.components.set(comp)
            if selectedPathClipID == oldID { selectedPathClipID = newClip.id }
        }

        if let arcVisual = activeRotationArcs.removeValue(forKey: oldID) {
            activeRotationArcs[newClip.id] = arcVisual
            arcVisual.startHandle.components.set(
                RotationArcComponent(clipID: newClip.id, role: .start))
            arcVisual.endHandle.components.set(
                RotationArcComponent(clipID: newClip.id, role: .end))
            if selectedArcClipID == oldID { selectedArcClipID = newClip.id }
        }
    }
}
