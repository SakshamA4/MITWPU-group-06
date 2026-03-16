import UIKit
import RealityKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Clip Conflict Detection & Resolution
//
// Hooks into showPathEditToolbar's Apply action.
// Detects when a timing edit causes an overlap with the next clip for the
// same entity, then presents a three-option resolution dialog.
// ─────────────────────────────────────────────────────────────────────────────

extension CanvasViewController {

    // ── MARK: Detection ──────────────────────────────────────────────────────

    /// Returns the first clip that `editedClip` overlaps, looking only at
    /// clips for the same entity that start AFTER `editedClip`.
    ///
    /// - Parameters:
    ///   - editedClip:  The candidate clip with proposed new timing.
    ///   - replacingID: The UUID of the clip being replaced (excluded from search).
    func detectClipConflict(
        editedClip:  AnimationClip,
        replacingID: UUID
    ) -> AnimationClip? {
        let editedEnd = editedClip.startTime + editedClip.duration

        // All clips for the same entity, sorted by start time, excluding the
        // clip being edited so we don't compare it against itself.
        let siblings = timeline.clips
            .filter { $0.entityName == editedClip.entityName && $0.id != replacingID }
            .sorted { $0.startTime < $1.startTime }

        // A conflict exists when the edited clip's end time exceeds the
        // start time of any sibling clip that comes after it.
        return siblings.first {
            $0.startTime >= editedClip.startTime && editedEnd > $0.startTime
        }
    }

    // ── MARK: Resolution Dialog ───────────────────────────────────────────────

    /// Presents a UIAlertController with three resolution options whenever
    /// a timing edit would cause an overlap.
    func presentClipConflictResolution(
        editedClip:      AnimationClip,
        replacingID:     UUID,
        conflicting:     AnimationClip,
        clipIndex:       Int,
        originalEndTime: Float       // oldClip.startTime + oldClip.duration before the edit
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

            // Commit the edited clip first
            self.commitClipTimingChange(
                newClip:   editedClip,
                oldClipID: replacingID,
                clipIndex: clipIndex
            )

            // originalGap = second clip's start - first clip's ORIGINAL end time
            // This is the gap that existed before the user's edit.
            // Example: Clip A ended at 1s, Clip B started at 2s → gap = 1s
            let originalGap = conflicting.startTime - originalEndTime

            // New Clip B start = new Clip A end + original gap
            let editedEnd     = editedClip.startTime + editedClip.duration
            let newClipBStart = editedEnd + originalGap

            // How far does Clip B (and everything after it) need to move?
            let shiftDelta = newClipBStart - conflicting.startTime

            if shiftDelta > 0.0001 {
                // Boundary = conflicting clip's startTime so it AND everything
                // after it gets shifted (not just clips starting after editedEnd)
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

            // Commit the edited clip first
            self.commitClipTimingChange(
                newClip:   editedClip,
                oldClipID: replacingID,
                clipIndex: clipIndex
            )

            // Merge: next clip starts right after edited clip ends,
            // duration shrinks to preserve original end time.
            let editedEnd       = editedClip.startTime + editedClip.duration
            let originalEnd     = conflicting.startTime + conflicting.duration
            let newDuration     = max(0, originalEnd - editedEnd)

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
    /// This is the same logic previously inlined in the Apply button, now
    /// extracted so both the conflict-free and conflict paths share it.
    func commitClipTimingChange(
        newClip:   AnimationClip,
        oldClipID: UUID,
        clipIndex: Int
    ) {
        timeline.clips[clipIndex] = newClip

        // Re-key the motion path visual from oldClipID → newClip.id
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
            type:       conflicting.type,
            track:      conflicting.track,
            easing:     conflicting.easing,
            startTime:  newStartTime,
            duration:   max(0.01, newDuration),   // never zero
            fromValue:  conflicting.fromValue,
            toValue:    conflicting.toValue,
            motionPath: conflicting.motionPath
        )
        timeline.clips[index] = merged

        reKeyVisuals(oldID: oldID, newClip: merged)
    }

    // ── MARK: Visual Re-keying ────────────────────────────────────────────────

    /// Transfers motion-path and rotation-arc visuals from `oldID` to `newClip.id`,
    /// updating every embedded MotionPathHandleComponent / RotationArcComponent.
    private func reKeyVisuals(oldID: UUID, newClip: AnimationClip) {
        // Motion path
        if let visual = activeMotionPaths.removeValue(forKey: oldID) {
            activeMotionPaths[newClip.id] = visual
            let comp = MotionPathHandleComponent(clipID: newClip.id)
            visual.startHandle?.components.set(comp)
            visual.control1Handle.components.set(comp)
            visual.control2Handle.components.set(comp)
            visual.endHandle.components.set(comp)
            if selectedPathClipID == oldID { selectedPathClipID = newClip.id }
        }

        // Rotation arc
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
