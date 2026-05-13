//
//  ModelCacheManager.swift
//  3DCanvas
//
//  Manages a scene-scoped, LRU-evicting cache of loaded USDZ models.
//  Designed for iPad with 10-15 models per scene, supporting fast scene switches
//  with minimal memory footprint.
//

import RealityKit
import Foundation

// MARK: - Cached Model

struct CachedModel {
    let entity: Entity
    var lastAccessTime: Date
    let estimatedSize: Int  // bytes
    let fileName: String
}

// MARK: - Cache Statistics

struct CacheStats {
    let sceneID: UUID
    let modelCount: Int
    let totalSize: Int
    let lastAccessed: Date
}

// MARK: - ModelCacheManager

final class ModelCacheManager {
    
    // MARK: - Configuration (iPad-optimized)
    
    static let maxCacheSize = 800 * 1024 * 1024        // 800 MB for iPad
    static let maxScenesInCache = 10                    // Keep up to 10 scenes
    static let evictionThreshold: Float = 0.7          // Evict at 70% full (560 MB)
    static let defaultModelEstimateSize = 8 * 1024 * 1024  // 8 MB per model (conservative)
    static let maxRetainedExitedScenes = 2             // Keep last N exited scenes in cache
    
    // MARK: - Private Properties
    
    private var sceneCache: [UUID: [String: CachedModel]] = [:]  // [sceneID: [fileName: CachedModel]]
    private var cacheStats: [UUID: CacheStats] = [:]
    private var currentMemoryUsage: Int = 0
    /// Tracks scene IDs in exit order (FIFO) for durable cache retention.
    private var exitedSceneOrder: [UUID] = []
    
    private let queue = DispatchQueue(label: "com.filmpage.modelcache", attributes: .concurrent)
    
    // MARK: - Initialization
    
    init() {
        print("✅ ModelCacheManager initialized (Max: \(Self.maxCacheSize / 1024 / 1024)MB, Max Scenes: \(Self.maxScenesInCache))")
    }
    
    // MARK: - Public API
    
    /// Retrieves a cached model for the given scene and file name.
    /// Updates access time if found (for LRU tracking).
    func getModel(_ fileName: String, for sceneID: UUID) -> Entity? {
        var result: Entity?
        queue.sync {
            if var scene = sceneCache[sceneID], var cached = scene[fileName] {
                cached.lastAccessTime = Date()
                scene[fileName] = cached
                sceneCache[sceneID] = scene
                result = cached.entity
                print("📦 Cache HIT: \(fileName) (scene: \(sceneID.uuidString.prefix(8))...)")
            }
        }
        return result
    }
    
    /// Caches a model for the given scene.
    /// Automatically triggers eviction if cache exceeds threshold.
    func cacheModel(_ entity: Entity, _ fileName: String, for sceneID: UUID, estimatedSize: Int) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let cached = CachedModel(
                entity: entity,
                lastAccessTime: Date(),
                estimatedSize: estimatedSize,
                fileName: fileName
            )
            
            if self.sceneCache[sceneID] == nil {
                self.sceneCache[sceneID] = [:]
            }
            self.sceneCache[sceneID]?[fileName] = cached
            self.currentMemoryUsage += estimatedSize
            
            // Update stats
            self.updateCacheStats(for: sceneID)
            
            print("📦 Cache ADD: \(fileName) (\(estimatedSize / 1024)KB, Total: \(self.currentMemoryUsage / 1024 / 1024)MB)")
            
            // Check if we need to evict
            if Float(self.currentMemoryUsage) > Float(Self.maxCacheSize) * Self.evictionThreshold {
                print("⚠️ Cache at \(String(format: "%.1f", Float(self.currentMemoryUsage) / Float(Self.maxCacheSize) * 100))% - triggering eviction")
                self.evictLRUScene_internal()
            }
        }
    }
    
    /// Evicts a specific scene from the cache.
    func evictScene(_ sceneID: UUID) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if let scene = self.sceneCache[sceneID] {
                let freed = scene.values.reduce(0) { $0 + $1.estimatedSize }
                self.sceneCache.removeValue(forKey: sceneID)
                self.cacheStats.removeValue(forKey: sceneID)
                self.currentMemoryUsage -= freed
                print("🗑️ Cache EVICT scene: \(sceneID.uuidString.prefix(8))... (freed \(freed / 1024)KB)")
            }
        }
    }
    
    /// Evicts the least-recently-used scene if cache is over threshold.
    /// Called automatically when adding to cache, or can be called manually.
    func evictLRUSceneIfNeeded() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let usagePercent = Float(self.currentMemoryUsage) / Float(Self.maxCacheSize) * 100
            if Float(self.currentMemoryUsage) > Float(Self.maxCacheSize) * Self.evictionThreshold {
                print("⚠️ Cache at \(String(format: "%.1f", usagePercent))% - evicting LRU scene")
                self.evictLRUScene_internal()
            }
        }
    }
    
    /// Returns current memory usage in bytes.
    func getCurrentMemoryUsage() -> Int {
        queue.sync {
            currentMemoryUsage
        }
    }
    
    /// Returns cache statistics as a dictionary.
    func getStats() -> [String: Any] {
        queue.sync {
            var sceneStats: [[String: Any]] = []
            for (sceneID, stats) in cacheStats {
                sceneStats.append([
                    "sceneID": sceneID.uuidString,
                    "modelCount": stats.modelCount,
                    "size": stats.totalSize,
                    "lastAccessed": stats.lastAccessed
                ])
            }
            
            return [
                "currentMemory": currentMemoryUsage,
                "maxMemory": Self.maxCacheSize,
                "scenesInCache": sceneCache.count,
                "totalModels": sceneCache.values.reduce(0) { $0 + $1.count },
                "percentUsed": String(format: "%.1f", Float(currentMemoryUsage) / Float(Self.maxCacheSize) * 100),
                "sceneStats": sceneStats
            ]
        }
    }
    
    /// Clears the entire cache (for memory warnings or testing).
    func clearAll() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            let freed = self.currentMemoryUsage
            self.sceneCache.removeAll()
            self.cacheStats.removeAll()
            self.currentMemoryUsage = 0
            self.exitedSceneOrder.removeAll()
            print("🗑️ Cache CLEAR ALL (freed \(freed / 1024 / 1024)MB)")
        }
    }
    
    /// Marks a scene as exited. Retains the last `maxRetainedExitedScenes` in cache;
    /// evicts the oldest when the limit is exceeded. This allows reopening a recently
    /// visited scene without reloading USDZ models from disk.
    func markExited(sceneID: UUID) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Remove if already tracked (re-exit of same scene)
            self.exitedSceneOrder.removeAll { $0 == sceneID }
            self.exitedSceneOrder.append(sceneID)
            
            // Evict oldest exited scenes beyond the retention limit
            while self.exitedSceneOrder.count > Self.maxRetainedExitedScenes {
                let evictID = self.exitedSceneOrder.removeFirst()
                if let scene = self.sceneCache[evictID] {
                    let freed = scene.values.reduce(0) { $0 + $1.estimatedSize }
                    self.sceneCache.removeValue(forKey: evictID)
                    self.cacheStats.removeValue(forKey: evictID)
                    self.currentMemoryUsage -= freed
                    print("🗑️ Cache EVICT oldest exited scene: \(evictID.uuidString.prefix(8))... (freed \(freed / 1024)KB)")
                }
            }
            
            // Safety: if we're still over the memory threshold, evict LRU
            if Float(self.currentMemoryUsage) > Float(Self.maxCacheSize) * Self.evictionThreshold {
                self.evictLRUScene_internal()
            }
            
            print("📦 Cache retained \(self.exitedSceneOrder.count)/\(Self.maxRetainedExitedScenes) exited scene(s), memory: \(self.currentMemoryUsage / 1024 / 1024)MB")
        }
    }
    
    // MARK: - Private Helpers
    
    private func evictLRUScene_internal() {
        guard !sceneCache.isEmpty else { return }
        
        // Find the scene with the oldest access time
        let lruSceneID = cacheStats.min { $0.value.lastAccessed < $1.value.lastAccessed }?.key
        
        if let sceneID = lruSceneID {
            if let scene = sceneCache[sceneID] {
                let freed = scene.values.reduce(0) { $0 + $1.estimatedSize }
                sceneCache.removeValue(forKey: sceneID)
                cacheStats.removeValue(forKey: sceneID)
                currentMemoryUsage -= freed
                print("🗑️ LRU Evicted scene: \(sceneID.uuidString.prefix(8))... (freed \(freed / 1024)KB)")
            }
        }
    }
    
    private func updateCacheStats(for sceneID: UUID) {
        if let scene = sceneCache[sceneID] {
            let modelCount = scene.count
            let totalSize = scene.values.reduce(0) { $0 + $1.estimatedSize }
            cacheStats[sceneID] = CacheStats(
                sceneID: sceneID,
                modelCount: modelCount,
                totalSize: totalSize,
                lastAccessed: Date()
            )
        }
    }
}

// MARK: - Entity Size Estimation

/// Estimates the memory footprint of an Entity based on its structure.
/// This is a conservative estimate used for cache management.
func estimateEntitySize(_ entity: Entity) -> Int {
    var size = 0
    
    // Base entity overhead: ~1KB
    size += 1024
    
    // Check for ModelComponent with mesh and materials
    if let model = entity as? ModelEntity {
        // Mesh estimation (rough): each mesh ~5MB
        size += 5 * 1024 * 1024
        
        // Material estimation: each material ~1MB
        if let materials = model.model?.materials {
            size += materials.count * 1024 * 1024
        }
    }
    
    // Estimate for children
    for child in entity.children {
        size += estimateEntitySize(child) / 2  // Children are usually sub-components
    }
    
    return size
}
