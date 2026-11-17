import Compression

@objc extension ARKController {
    
    // MARK: - Saving
    
    /**
     Save the current tracker World Map in local storage
     
     - Fails if tracking isn't initialized, or if the acquisition of a World Map fails for some other reason
     */
    func saveWorldMap() {
        if !trackingStateNormal() {
            DDLogError("Can't save WorldMap to local storage until tracking is initialized")
            return
        }
        
        if !worldMappingAvailable() {
            DDLogError("Can't save WorldMap to local storage until World Mapping has started")
            return
        }
        
        session?.getCurrentWorldMap(completionHandler: { worldMap, error in
            if let worldMap = worldMap {
                DDLogError("saving WorldMap to local storage")
                self._save(worldMap)
            } else {
                // try to get rid of an old one if it exists.  Don't care if this fails.
                if let worldSaveURL = self.worldSaveURL {
                    try? FileManager.default.trashItem(at: worldSaveURL, resultingItemURL: nil)
                }
                DDLogError("moving saved WorldMap to trash")
            }
        })
    }
    
    func _save(_ worldMap: ARWorldMap) {
        if let worldSaveURL = worldSaveURL {
            var data: Data? = nil
            data = try? NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
            do {
                try data?.write(to: worldSaveURL, options: .atomic)
                DDLogError("saved WorldMap to load storage at \(worldSaveURL)")
            } catch {
                DDLogError("Failed saving WorldMap to persistent storage")
            }
        }
    }
    
    /**
     Save the current ARKit ARWorldMap if tracking.
     */
    func saveWorldMapInBackground() {
        if !trackingStateNormal() {
            DDLogError("can't save WorldMap as we transition to background, tracking isn't initialized")
            return
        }
        
        session.getCurrentWorldMap(completionHandler: { worldMap, error in
            if worldMap != nil {
                DDLogError("saving WorldMap as we transition to background")
                self.backgroundWorldMap = worldMap
            }
        })
    }
    
    // MARK: - Loading
    
    /**
     Load a previously saved World Map from local storage.
     */
    func loadSavedMap() {
        if let worldSaveURL = worldSaveURL {
            var data: Data? = nil
            do {
                data = try Data(contentsOf: worldSaveURL)
            } catch {
                DDLogError("Error loading WorldMap")
                return
            }
            if let data = data {
                do {
                    guard let obj = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
                        DDLogError("Failed to unarchive the WorldMap")
                        return
                    }
                    _setWorldMap(obj)
                } catch {
                    DDLogError("Failed to create ARWorldMap from saved WorldMap loaded from persistent storage")
                }
            } else {
                DDLogError("Failed to load saved WorldMap from persistent storage")
                return
            }
        }
    }
    
    // MARK: - Getting
    
    /**
     Get the current tracker World Map and return it in an base64 encoded string in a dictionary, for sending to Javascript
     
     - Fails if tracking isn't initialized, or if the acquisition of a World Map fails for some other reason
     
     @param completion The completion block that will be called with the outcome of the acquisition of the world map
     */
    func getWorldMap(_ completion: @escaping GetWorldMapCompletionBlock) {
        if getWorldMapPromise != nil {
            getWorldMapPromise(false, "World Map request cancelled by subsequent call to get World Map.", nil)
            getWorldMapPromise = nil
        }
        
        #if ALLOW_GET_WORLDMAP
        switch webXRAuthorizationStatus {
        case .worldSensing, .videoCameraAccess:
            getWorldMapPromise = completion
            _getWorldMap()
        case .lite:
            completion(false, "The user only granted access to a single plane, so cannot get map", nil)
        case .minimal, .denied:
            completion(false, "The user denied access to world sensing data", nil)
        case .notDetermined:
            print("Attempt to get World Map but world sensing data authorization is not determined, enqueue the request")
            getWorldMapPromise = completion
        }
        #else
        completion(false, "getWorldMap not supported", nil)
        #endif
    }
    
    // Actually perform the saving and sending of world map back to the app
    func _getWorldMap() {
        let completion: GetWorldMapCompletionBlock? = getWorldMapPromise
        getWorldMapPromise = nil
        
        if configuration is ARFaceTrackingConfiguration {
            if completion != nil {
                completion?(false, "Cannot get World Map when using the front facing camera", nil)
            }
            return
        }
        
        if !trackingStateNormal() {
            if completion != nil {
                completion?(false, "Cannot get World Map until tracking is fully initialized", nil)
            }
            return
        }
        
        if !worldMappingReadyToSave() {
            let status = worldMappingStatusString(for: session?.currentFrame)
            if completion != nil {
                completion?(false, "Scan more of your environment before saving (status: \(status)).", nil)
            }
            return
        }
        
        session?.getCurrentWorldMap(completionHandler: { worldMap, error in
            if let worldMap = worldMap {
                if let completion = completion {
                    var mapData = [AnyHashable: Any]()
                    
                    var data: Data? = nil
                    do {
                        data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
                    } catch {
                        print("Error accessing archived worldMap data")
                        completion(false, "request to get World Map failed: could not archive map data", nil)
                        return
                    }
                    let compressedData = self.getCompressedData(data)
                    
                    if compressedData == nil {
                        completion(false, "request to get World Map failed: couldn't compress data", nil)
                        return
                    }
                    #if DEBUG
                    print("world map uncompressed size \(data?.count ?? 0) -> compressed \(compressedData?.count ?? 0)")
                    #endif
                    
                    let string = compressedData?.base64EncodedString(options: [])
                    mapData["worldMap"] = string ?? ""
                    mapData["center"] = dictFromVector3(worldMap.center)
                    mapData["extent"] = dictFromVector3(worldMap.extent)
                    mapData["featureCount"] = NSNumber(value: worldMap.rawFeaturePoints.points.count)
                    
                    self.logUnexpectedWorldMapAnchors(worldMap)
                    
                    completion(true, nil, mapData)
                }
            } else {
                if let error = error {
                    completion?(false, "request to get World Map failed: \(error)", nil)
                } else {
                    completion?(false, "request to get World Map failed: no map data returned", nil)
                }
            }
        })
    }
    
    // MARK: - Setting
    
    /**
     Set the current tracker World Map from a base64 encoded text string, passed in from Javascript.
     
     - Fails if the map will not load for some other reason
     
     @param worldMapDictionary The dictionary representing the worldMap
     @param completion The completion block that will be called with the outcome of the loading of the world map
     */
    func setWorldMap(_ worldMapDictionary: [AnyHashable : Any], completion: @escaping SetWorldMapCompletionBlock) {
        if setWorldMapPromise != nil {
            setWorldMapPromise(false, "World Map set request cancelled by subsequent call to set World Map.")
        }
        
        switch webXRAuthorizationStatus {
        case .worldSensing, .videoCameraAccess:
            setWorldMapPromise = completion
            // we do it here (rather than above) because if a nil is passed in, we don't want to replace the previously saved
            // value (since a user could still reload it with the browser menu)
            let map: ARWorldMap? = dict(toWorldMap: worldMapDictionary)
            
            if let map = map {
                //[self _saveWorldMap:map];
                _setWorldMap(map)
            } else {
                if setWorldMapPromise != nil {
                    setWorldMapPromise(false, "The World Map may be invalid, it couldn't be decoded.")
                    setWorldMapPromise = nil
                }
            }
        case .lite:
            completion(false, "The user only provided access to a single plane, so cannot set map")
        case .minimal, .denied:
            completion(false, "The user denied access to world sensing data, so cannot set map")
        case .notDetermined:
            print("Attempt to get World Map but world sensing data authorization is not determined, enqueue the request")
            setWorldMapPromise = completion
        }
    }
    
    func _setWorldMap(_ map: ARWorldMap) {
        let completion: SetWorldMapCompletionBlock? = setWorldMapPromise
        setWorldMapPromise = nil
        
        if configuration is ARWorldTrackingConfiguration {
            worldMapRelocalizationInProgress = true
            // First, let's restart with current configuration, but remove existing anchors
            //    [[self session] runWithConfiguration:[self configuration] options: ARSessionRunOptionRemoveExistingAnchors];
            print("Restarted, removing existing anchors")
            
            // now, let's load the world map
            let worldTrackingConfiguration = configuration as? ARWorldTrackingConfiguration
            worldTrackingConfiguration?.initialWorldMap = map
            logUnexpectedWorldMapAnchors(map)
            
            if let configuration = configuration {
                session?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            }
            
            // if we are removing anchors, clear the user map
            arkitGeneratedAnchorIDUserAnchorIDMap = NSMutableDictionary.init()
            print("Restarted, loading map.")
            
            for anchor in map.anchors {
                session?.add(anchor: anchor)
                arkitGeneratedAnchorIDUserAnchorIDMap[anchor.identifier.uuidString] = anchor.name ?? ""
            }
            
            // now remove the map from the config
            worldTrackingConfiguration?.initialWorldMap = nil
            
            self.arSessionState = .ARKSessionRunning
            // [self setupDeviceCamera];
            
            completion?(true, nil)
        } else {
            DDLogError("Cannot load World Map when using user-facing camera")
            completion?(false, "Cannot load World Map when using user-facing camera")
            return
        }
    }
    
    // MARK: - Helpers
    
    func getDecompressedData(_ compressed: Data) -> Data? {
        var dst_buffer_size: size_t = compressed.count * 8
        let maxAttempts = 16
        var attempts = 0
        
        var src_buffer = [UInt8](repeating: 0, count: compressed.count)
        compressed.copyBytes(to: &src_buffer, count: compressed.count)
        
        while attempts < maxAttempts {
            attempts += 1
            var dst_buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: dst_buffer_size)
            let decompressedSize: size_t = compression_decode_buffer(dst_buffer, dst_buffer_size, &src_buffer, compressed.count, nil, COMPRESSION_ZLIB)
            
            // error!
            if decompressedSize == 0 {
                free(dst_buffer)
                return nil
            }
            
            // overflow, try again
            if decompressedSize == dst_buffer_size {
                dst_buffer_size *= 2
                free(dst_buffer)
                continue
            }
            let decompressed = Data(bytes: dst_buffer, count: decompressedSize)
            free(dst_buffer)
            return decompressed
        }
        return nil
    }
    
    func getCompressedData(_ input: Data?) -> Data? {
        var dst_buffer_size: size_t = max((input?.count ?? 0) / 8, 10)
        let maxAttempts = 16
        var attempts = 0
        
        var src_buffer = [UInt8](repeating: 0, count: input?.count ?? 0)
        input?.copyBytes(to: &src_buffer, count: input?.count ?? 0)
        
        while attempts < maxAttempts {
            attempts += 1
            var dst_buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: dst_buffer_size)
            let compressedSize = compression_encode_buffer(dst_buffer, dst_buffer_size, &src_buffer, (input?.count ?? 0), nil, COMPRESSION_ZLIB)
            
            // overflow, try again
            if compressedSize == 0 {
                dst_buffer_size *= 2
                free(dst_buffer)
                continue
            }
            let compressed = Data(bytes: dst_buffer, count: compressedSize)
            free(dst_buffer)
            return compressed
        }
        return nil
    }
    
    func logUnexpectedWorldMapAnchors(_ worldMap: ARWorldMap) {
        for anchor in worldMap.anchors {
            if anchor is ARPlaneAnchor {
                DDLogWarn("WorldMap contained PlaneAnchor")
            } else if anchor is ARImageAnchor {
                DDLogWarn("WorldMap contained ImageAnchor")
            } else if anchor is ARFaceAnchor {
                DDLogWarn("WorldMap contained FaceAnchor")
            }
        }
    }
    
    func dict(toWorldMap worldMapDictionary: [AnyHashable : Any]) -> ARWorldMap? {
        guard let b64String = worldMapDictionary["worldMap"] as? String else { return nil }
        guard let data = Data(base64Encoded: b64String, options: .ignoreUnknownCharacters) else { return nil }
        guard let uncompressed = getDecompressedData(data) else { return nil }
        #if DEBUG
        print("World map compressed size \(data.count) -> uncompressed \(uncompressed.count)")
        #endif
        var obj: ARWorldMap? = nil
        do {
            obj = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: uncompressed)
        } catch {
            print("Error unarchiving WorldMap")
        }
        
        return obj
    }
    
    func worldMappingAvailable() -> Bool {
        guard let ws = session?.currentFrame?.worldMappingStatus else { return false }
        return ws != .notAvailable
    }
    
    /// World map capture is allowed while ARKit is extending or has mapped the area.
    /// notAvailable and limited still need more scanning.
    func worldMappingReadyToSave() -> Bool {
        guard let ws = session?.currentFrame?.worldMappingStatus else { return false }
        return ws == .extending || ws == .mapped
    }
    
    func worldMappingStatusString(for frame: ARFrame?) -> String {
        guard let ws = frame?.worldMappingStatus else { return "unknown" }
        switch ws {
        case .notAvailable: return WEB_AR_WORLDMAPPING_NOT_AVAILABLE
        case .limited: return WEB_AR_WORLDMAPPING_LIMITED
        case .extending: return WEB_AR_WORLDMAPPING_EXTENDING
        case .mapped: return WEB_AR_WORLDMAPPING_MAPPED
        }
    }
    
    /**
     Is there a saved world map?
     */
    func hasBackgroundWorldMap() -> Bool {
        return backgroundWorldMap != nil
    }
}
