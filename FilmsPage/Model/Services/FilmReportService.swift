//
//  FilmReportService.swift
//  FilmsPage
//
//  Compiles a comprehensive production report for a given film.
//  Works in two layers:
//    Layer 1 — metadata from FilmService / SequenceService / SceneService
//              (always available, shows scene names & notes).
//    Layer 2 — deep asset data from saved scene JSON on disk
//              (available only after each scene has been opened in the canvas).
//

import Foundation

// MARK: - Report Data Models

struct FilmReport {
    let film: Film
    let generatedAt: Date
    let sequences: [SequenceReport]
    var totalScenes: Int { sequences.reduce(0) { $0 + $1.scenes.count } }
}

struct SequenceReport {
    let sequence: Sequence
    let scenes: [SceneDetailReport]
}

struct SceneDetailReport {
    let sceneName: String
    let sceneNotes: String?
    // Layer-2 canvas data (nil = scene not yet saved to disk)
    let propCount: Int?
    let propNames: [String]
    let characterCount: Int?
    let characterNames: [String]
    let lights: [LightReport]
    let cameras: [CameraReport]
    let animations: [AnimationReport]
    let backgroundCount: Int?
    let wallCount: Int?
    let skySetting: String?
    let hasCanvasData: Bool
}

struct LightReport {
    let kind: String
    let intensityLumens: Float?
    let colorTempKelvin: Float?
    let shadowEnabled: Bool
    let proceduralKind: String?
    let gobo: String?
}

struct CameraReport {
    let aspectRatio: String?
    let focalLengthMM: Float?
    let focusMode: String?
}

struct AnimationReport {
    let entityName: String
    let animType: String
    let track: String
    let durationSeconds: Float
}

// MARK: - FilmReportService

final class FilmReportService {

    static let shared = FilmReportService()
    private init() {}

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func sceneFileURL(for id: UUID) -> URL {
        documentsDirectory.appendingPathComponent("scene_\(id.uuidString).json")
    }

    // MARK: - Public: Build Report

    func buildReport(for film: Film) -> FilmReport {
        let sequences = SequenceService.shared.getSequences(forFilmId: film.id)
        print("📊 FilmReport: film=\(film.name), sequences=\(sequences.count)")

        let sequenceReports: [SequenceReport] = sequences.map { sequence in
            let scenes = SceneService.shared.getScenes(forSequenceId: sequence.id)
            print("   Sequence '\(sequence.name)': \(scenes.count) scene(s)")
            let reports = scenes.map { scene -> SceneDetailReport in
                let url = sceneFileURL(for: scene.id)
                let fileExists = FileManager.default.fileExists(atPath: url.path)
                print("   Scene '\(scene.name)' [\(scene.id.uuidString.prefix(8))]: file=\(fileExists ? "✅" : "❌")")
                if fileExists,
                   let data = try? Data(contentsOf: url),
                   let doc = try? JSONDecoder().decode(CanvasSceneDocument.self, from: data) {
                    return buildDeepReport(scene: scene, doc: doc)
                }
                // Layer-1 only — no canvas data yet
                return SceneDetailReport(
                    sceneName: scene.name,
                    sceneNotes: scene.notes,
                    propCount: nil, propNames: [],
                    characterCount: nil, characterNames: [],
                    lights: [], cameras: [], animations: [],
                    backgroundCount: nil, wallCount: nil,
                    skySetting: nil, hasCanvasData: false
                )
            }
            return SequenceReport(sequence: sequence, scenes: reports)
        }

        return FilmReport(film: film, generatedAt: Date(), sequences: sequenceReports)
    }

    // MARK: - Public: Format Report

    func formatReport(_ report: FilmReport) -> String {
        let film = report.film
        var out = ""

        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short

        // ── Cover ──────────────────────────────────────────────────────────
        out += "╔══════════════════════════════════════════════════════════════╗\n"
        out += "║               FILM PRODUCTION REPORT                        ║\n"
        out += "╚══════════════════════════════════════════════════════════════╝\n\n"

        out += "  FILM TITLE       : \(film.name)\n"
        out += "  CREATED          : \(df.string(from: film.createdDate))\n"
        out += "  REPORT DATE      : \(df.string(from: report.generatedAt))\n"
        out += "  TOTAL SEQUENCES  : \(report.sequences.count)\n"
        out += "  TOTAL SCENES     : \(report.totalScenes)\n"
        out += "  TOTAL CHARACTERS : \(film.characters)\n"
        if !film.notes.isEmpty {
            out += "  FILM NOTES       : \(film.notes)\n"
        }
        out += "\n"

        guard !report.sequences.isEmpty else {
            out += "  ⚠️  No sequences found for this film.\n"
            out += "  Create sequences and scenes from the film screen.\n"
            return out
        }

        // ── Sequences ──────────────────────────────────────────────────────
        for (si, seqReport) in report.sequences.enumerated() {
            out += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            out += "  SEQUENCE \(si + 1) : \(seqReport.sequence.name.uppercased())\n"
            out += "  Scenes          : \(seqReport.scenes.count)\n"
            out += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"

            if seqReport.scenes.isEmpty {
                out += "  No scenes in this sequence yet.\n\n"
                continue
            }

            for (sci, detail) in seqReport.scenes.enumerated() {
                out += formatSceneBlock(detail, number: sci + 1)
            }
        }

        // ── Footer ─────────────────────────────────────────────────────────
        out += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        out += "  END OF REPORT — \(df.string(from: report.generatedAt))\n"
        out += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        return out
    }

    // MARK: - Deep Scene Analysis (Layer 2)

    private func buildDeepReport(scene: Scene, doc: CanvasSceneDocument) -> SceneDetailReport {
        let entities = doc.entities

        let props       = entities.filter { $0.toolType == "Prop" }
        let chars       = entities.filter { $0.toolType == "Character" }
        let lightEnts   = entities.filter { $0.toolType == "Light" }
        let cameraEnts  = entities.filter { $0.toolType == "Camera" }
        let bgCount     = entities.filter { $0.toolType == "Background" }.count
        let wallCount   = entities.filter { $0.toolType == "Wall" }.count

        let lights: [LightReport] = lightEnts.map { e in
            LightReport(
                kind:            e.lightKind ?? "unknown",
                intensityLumens: e.lightIntensity,
                colorTempKelvin: e.lightColorTempKelvin,
                shadowEnabled:   e.lightShadowEnabled ?? false,
                proceduralKind:  e.proceduralLightKind,
                gobo:            e.lightActiveGobo
            )
        }
        let cameras: [CameraReport] = cameraEnts.map { e in
            CameraReport(
                aspectRatio:  e.cameraAspectRatio,
                focalLengthMM: e.cameraFocalLengthMM,
                focusMode:    e.cameraFocusMode
            )
        }
        let animations: [AnimationReport] = doc.animationClips.map { clip in
            AnimationReport(
                entityName:      cleanName(clip.entityName),
                animType:        clip.type,
                track:           clip.track,
                durationSeconds: clip.duration
            )
        }

        return SceneDetailReport(
            sceneName:      scene.name,
            sceneNotes:     scene.notes,
            propCount:      props.count,
            propNames:      props.map { cleanName($0.modelFileName) },
            characterCount: chars.count,
            characterNames: chars.map { cleanName($0.modelFileName) },
            lights:         lights,
            cameras:        cameras,
            animations:     animations,
            backgroundCount: bgCount,
            wallCount:      wallCount,
            skySetting:     doc.skyType,
            hasCanvasData:  true
        )
    }

    // MARK: - Scene Block Formatting

    private func formatSceneBlock(_ d: SceneDetailReport, number: Int) -> String {
        var out = ""
        out += "  ┌──────────────────────────────────────────────────────────┐\n"
        out += "  │  SCENE \(number): \(d.sceneName)\n"
        out += "  └──────────────────────────────────────────────────────────┘\n"

        if let notes = d.sceneNotes, !notes.trimmingCharacters(in: .whitespaces).isEmpty {
            out += "  📝 Notes   : \(notes)\n"
        }

        if !d.hasCanvasData {
            out += "\n  ⏳ Canvas data not yet generated.\n"
            out += "     Open this scene in the 3D canvas once to populate full details.\n\n"
            return out
        }

        // Props
        let pc = d.propCount ?? 0
        out += "\n  PROPS (\(pc))\n"
        if pc == 0 { out += "    — None\n" }
        else { d.propNames.forEach { out += "    · \($0)\n" } }

        // Characters
        let cc = d.characterCount ?? 0
        out += "\n  CHARACTERS (\(cc))\n"
        if cc == 0 { out += "    — None\n" }
        else { d.characterNames.forEach { out += "    · \($0)\n" } }

        // Animations
        out += "\n  ANIMATIONS (\(d.animations.count) clip(s))\n"
        if d.animations.isEmpty {
            out += "    — None\n"
        } else {
            let grouped = Dictionary(grouping: d.animations, by: { $0.entityName })
            for (entity, clips) in grouped.sorted(by: { $0.key < $1.key }) {
                let descs = clips.map { "\(formatAnimType($0.animType, track: $0.track)) (\(String(format: "%.1f", $0.durationSeconds))s)" }
                out += "    · \(entity): \(descs.joined(separator: ", "))\n"
            }
        }

        // Lights
        out += "\n  LIGHTS (\(d.lights.count))\n"
        if d.lights.isEmpty {
            out += "    — None\n"
        } else {
            for (i, l) in d.lights.enumerated() {
                var s = "    · Light \(i+1): \(formatLightKind(l))"
                if let k  = l.colorTempKelvin  { s += "  [\(Int(k))K]" }
                if let lm = l.intensityLumens  { s += "  [\(lm >= 1000 ? String(format:"%.0fK",lm/1000) : String(format:"%.0f",lm)) lm]" }
                if l.shadowEnabled              { s += "  [Shadows ON]" }
                if let g = l.gobo, g.lowercased() != "none", !g.isEmpty { s += "  [Gobo: \(g.capitalized)]" }
                out += s + "\n"
            }
        }

        // Cameras
        out += "\n  CAMERAS (\(d.cameras.count))\n"
        if d.cameras.isEmpty {
            out += "    — None\n"
        } else {
            for (i, c) in d.cameras.enumerated() {
                var s = "    · Camera \(i+1)"
                if let r  = c.aspectRatio    { s += "  [\(r)]" }
                if let fl = c.focalLengthMM  { s += "  [\(Int(fl))mm]" }
                if let fm = c.focusMode, !fm.isEmpty { s += "  [Focus: \(fm.capitalized)]" }
                out += s + "\n"
            }
        }

        // Backgrounds
        if let bc = d.backgroundCount, bc > 0 {
            out += "\n  BACKGROUNDS (\(bc))\n    · Custom background image(s) applied\n"
        }

        // Walls
        if let wc = d.wallCount, wc > 0 {
            out += "\n  SET ELEMENTS (Walls / Ground): \(wc) element(s)\n"
        }

        // Sky
        out += "\n  SKY SETTING\n"
        if let sky = d.skySetting, !sky.isEmpty {
            out += "    · \(formatSkyType(sky))\n"
        } else {
            out += "    — None (default environment)\n"
        }

        out += "\n"
        return out
    }

    // MARK: - Helpers

    private func cleanName(_ name: String) -> String {
        let base = (name as NSString).deletingPathExtension
        return base
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    private func formatLightKind(_ l: LightReport) -> String {
        if let p = l.proceduralKind {
            switch p.lowercased() {
            case "practicallantern": return "Practical Lantern"
            case "fluorescenttube":  return "Fluorescent Tube"
            case "skypanel":         return "Sky Panel"
            default:                 return p.capitalized
            }
        }
        switch l.kind.lowercased() {
        case "spot":  return "Spotlight"
        case "panel": return "LED Panel"
        case "point": return "Point Light"
        case "sun":   return "Sun (Directional)"
        default:      return l.kind.capitalized
        }
    }

    private func formatAnimType(_ type: String, track: String) -> String {
        if type.lowercased() == "path" { return "Walk (Path)" }
        switch track.lowercased() {
        case "position": return "Move"
        case "rotation": return "Rotate"
        case "scale":    return "Scale"
        case "fov":      return "Zoom"
        default:         return type.capitalized
        }
    }

    private func formatSkyType(_ sky: String) -> String {
        switch sky {
        case "Blue_sky":     return "Blue Sky (Daytime)"
        case "Nighty_night": return "Starry Night"
        case "Evening_sky":  return "Evening Hue"
        case "sky_day":      return "Daylight Sky"
        case "sky_sunset":   return "Sunset Sky"
        case "sky_night":    return "Midnight Sky"
        default:             return sky.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
