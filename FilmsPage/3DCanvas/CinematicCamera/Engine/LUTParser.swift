//
//  LUTParser.swift
//  FilmsPage
//
//  Parses .cube (Adobe/Resolve) and .3dl (Autodesk/Flame) LUT files
//  into runtime LUTData for realtime color grading application.
//  Supports 1D and 3D LUTs with validation and error reporting.
//

import Foundation

// MARK: - LUT Parser Errors

enum LUTParserError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidFormat(String)
    case invalidGridSize(Int)
    case insufficientData(expected: Int, found: Int)
    case parseError(line: Int, content: String)
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "LUT file not found: \(path)"
        case .invalidFormat(let reason):
            return "Invalid LUT format: \(reason)"
        case .invalidGridSize(let size):
            return "Invalid LUT grid size: \(size). Expected 2–128."
        case .insufficientData(let expected, let found):
            return "Insufficient LUT data: expected \(expected) entries, found \(found)"
        case .parseError(let line, let content):
            return "Parse error at line \(line): \(content)"
        case .unsupportedFormat(let ext):
            return "Unsupported LUT format: .\(ext)"
        }
    }
}

// MARK: - LUTParser

/// Parses .cube and .3dl LUT files into runtime LUTData.
final class LUTParser {

    static let shared = LUTParser()
    private init() {}

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Public API
    // ═══════════════════════════════════════════════════════════════════════

    /// Parse a LUT file from a URL. Auto-detects format from extension.
    func parse(fileURL: URL) throws -> LUTData {
        let ext = fileURL.pathExtension.lowercased()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw LUTParserError.fileNotFound(fileURL.path)
        }

        let contents = try String(contentsOf: fileURL, encoding: .utf8)

        switch ext {
        case "cube":
            return try parseCube(contents: contents)
        case "3dl":
            return try parse3DL(contents: contents)
        default:
            throw LUTParserError.unsupportedFormat(ext)
        }
    }

    /// Parse a LUT from raw string content with explicit format.
    func parse(contents: String, format: LUTFormat) throws -> LUTData {
        switch format {
        case .cube:
            return try parseCube(contents: contents)
        case .threeDL:
            return try parse3DL(contents: contents)
        }
    }

    /// Validate a LUT file without fully parsing it.
    /// Returns the grid size if valid, throws on error.
    func validate(fileURL: URL) throws -> Int {
        let data = try parse(fileURL: fileURL)
        return data.size
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - .cube Parser (Adobe / DaVinci Resolve)
    // ═══════════════════════════════════════════════════════════════════════

    /// .cube format specification:
    /// - Lines starting with # are comments
    /// - TITLE "name" (optional)
    /// - LUT_3D_SIZE N (required, N = grid size)
    /// - DOMAIN_MIN r g b (optional, default 0 0 0)
    /// - DOMAIN_MAX r g b (optional, default 1 1 1)
    /// - Data lines: R G B (floating point 0.0–1.0)
    /// - Order: R fastest, then G, then B
    private func parseCube(contents: String) throws -> LUTData {
        let lines = contents.components(separatedBy: .newlines)

        var gridSize: Int?
        var domainMin = SIMD3<Float>(0, 0, 0)
        var domainMax = SIMD3<Float>(1, 1, 1)
        var table: [SIMD3<Float>] = []

        for (lineIndex, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if line.isEmpty || line.hasPrefix("#") { continue }

            // Parse header directives
            if line.hasPrefix("TITLE") { continue }

            if line.hasPrefix("LUT_3D_SIZE") || line.hasPrefix("LUT_1D_SIZE") {
                let parts = line.split(separator: " ")
                if parts.count >= 2, let size = Int(parts[1]) {
                    gridSize = size
                }
                continue
            }

            if line.hasPrefix("DOMAIN_MIN") {
                let values = parseFloatsFromLine(line, skipFirst: 1)
                if values.count >= 3 {
                    domainMin = SIMD3<Float>(values[0], values[1], values[2])
                }
                continue
            }

            if line.hasPrefix("DOMAIN_MAX") {
                let values = parseFloatsFromLine(line, skipFirst: 1)
                if values.count >= 3 {
                    domainMax = SIMD3<Float>(values[0], values[1], values[2])
                }
                continue
            }

            // Skip other header directives
            if line.first?.isLetter == true { continue }

            // Parse data line: R G B
            let values = parseFloatsFromLine(line, skipFirst: 0)
            if values.count >= 3 {
                // Normalise from domain range to 0–1
                let r = normalise(values[0], min: domainMin.x, max: domainMax.x)
                let g = normalise(values[1], min: domainMin.y, max: domainMax.y)
                let b = normalise(values[2], min: domainMin.z, max: domainMax.z)
                table.append(SIMD3<Float>(r, g, b))
            } else if !line.isEmpty {
                // Non-empty line that doesn't parse — warn but continue
                print("⚠️ LUTParser: Skipping unparseable line \(lineIndex + 1): \(line)")
            }
        }

        // Validate
        guard let size = gridSize else {
            throw LUTParserError.invalidFormat("Missing LUT_3D_SIZE directive")
        }

        guard size >= 2, size <= 128 else {
            throw LUTParserError.invalidGridSize(size)
        }

        let expectedEntries = size * size * size
        guard table.count >= expectedEntries else {
            throw LUTParserError.insufficientData(expected: expectedEntries, found: table.count)
        }

        // Trim to exact size (some files have trailing data)
        let trimmedTable = Array(table.prefix(expectedEntries))

        return LUTData(size: size, table: trimmedTable)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - .3dl Parser (Autodesk / Flame)
    // ═══════════════════════════════════════════════════════════════════════

    /// .3dl format specification:
    /// - First non-comment line: input bit depth values (mesh definition)
    /// - Subsequent lines: R G B (integer values, typically 0–4095 for 12-bit)
    /// - Grid size is inferred from the mesh definition line
    private func parse3DL(contents: String) throws -> LUTData {
        let lines = contents.components(separatedBy: .newlines)

        var meshLine: String?
        var table: [SIMD3<Float>] = []
        var maxValue: Float = 4095.0  // Default 12-bit

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("//") { continue }

            // First non-comment line is the mesh definition
            if meshLine == nil {
                meshLine = line
                // Detect bit depth from mesh values
                let meshValues = parseFloatsFromLine(line, skipFirst: 0)
                if let lastValue = meshValues.last, lastValue > 0 {
                    maxValue = lastValue
                }
                continue
            }

            // Parse data lines: R G B (integers)
            let values = parseFloatsFromLine(line, skipFirst: 0)
            if values.count >= 3 {
                let r = values[0] / maxValue
                let g = values[1] / maxValue
                let b = values[2] / maxValue
                table.append(SIMD3<Float>(
                    min(1.0, max(0.0, r)),
                    min(1.0, max(0.0, g)),
                    min(1.0, max(0.0, b))
                ))
            }
        }

        // Infer grid size from entry count
        let entryCount = table.count
        let gridSize = Int(round(pow(Float(entryCount), 1.0 / 3.0)))

        guard gridSize >= 2, gridSize <= 128 else {
            throw LUTParserError.invalidGridSize(gridSize)
        }

        let expectedEntries = gridSize * gridSize * gridSize
        guard entryCount >= expectedEntries else {
            throw LUTParserError.insufficientData(expected: expectedEntries, found: entryCount)
        }

        let trimmedTable = Array(table.prefix(expectedEntries))
        return LUTData(size: gridSize, table: trimmedTable)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Helpers
    // ═══════════════════════════════════════════════════════════════════════

    /// Parse whitespace-separated floats from a line, optionally skipping N leading tokens.
    private func parseFloatsFromLine(_ line: String, skipFirst: Int) -> [Float] {
        let parts = line.split(whereSeparator: { $0.isWhitespace })
        let dataParts = parts.dropFirst(skipFirst)
        return dataParts.compactMap { Float($0) }
    }

    /// Normalise a value from [min, max] to [0, 1].
    private func normalise(_ value: Float, min: Float, max: Float) -> Float {
        let range = max - min
        guard range > 0.0001 else { return value }
        return (value - min) / range
    }
}

// MARK: - LUT File Manager

/// Manages LUT file import, storage, and retrieval within the app's
/// documents directory.
final class LUTFileManager {

    static let shared = LUTFileManager()

    /// Directory for storing imported LUT files
    private let lutDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("CinematicLUTs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {}

    /// Import a LUT file from an external URL (e.g. Files picker).
    /// Copies to the app's LUT directory and returns a LUTFile model.
    func importLUT(from sourceURL: URL) throws -> LUTFile {
        // Validate first
        let data = try LUTParser.shared.parse(fileURL: sourceURL)

        // Generate unique filename
        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension.lowercased()
        let uniqueName = "\(originalName)_\(Int(Date().timeIntervalSince1970)).\(ext)"
        let destURL = lutDirectory.appendingPathComponent(uniqueName)

        // Copy file
        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        let format: LUTFormat = ext == "3dl" ? .threeDL : .cube

        return LUTFile(
            id: UUID().uuidString,
            name: originalName,
            originalFileName: sourceURL.lastPathComponent,
            format: format,
            relativePath: uniqueName,
            gridSize: data.size,
            importDate: Date()
        )
    }

    /// Load a previously imported LUT file.
    func loadLUT(file: LUTFile) throws -> LUTData {
        let fileURL = lutDirectory.appendingPathComponent(file.relativePath)
        return try LUTParser.shared.parse(fileURL: fileURL)
    }

    /// Delete an imported LUT file.
    func deleteLUT(file: LUTFile) {
        let fileURL = lutDirectory.appendingPathComponent(file.relativePath)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// List all imported LUT files on disk.
    func importedLUTFilenames() -> [String] {
        let contents = try? FileManager.default.contentsOfDirectory(atPath: lutDirectory.path)
        return contents ?? []
    }
}
