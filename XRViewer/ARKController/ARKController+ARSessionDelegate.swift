extension ARKController: ARSessionDelegate {
    
    // Tony: Per SO, a bug that's been around for 3+ years necessitates these @objc calls
    // to the same functions. It's annoying the workaround doesn't resolve the warnings,
    // but it works for now.
    @objc(session:didUpdateFrame:)
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // cameraDidChangeTrackingState only fires when the tracking state changes. If tracking
        // turned .normal while worldMappingStatus was still .limited, the flag was never cleared
        // and JS waited until its timeout ("space not recognized"). Check every frame instead.
        if worldMapRelocalizationInProgress
            && frame.camera.trackingState == .normal
            && (frame.worldMappingStatus == .extending || frame.worldMappingStatus == .mapped) {
            worldMapRelocalizationInProgress = false
        }
        updateARKData(with: frame)
        
        didUpdate(self)
        
        if shouldUpdateWindowSize {
            self.shouldUpdateWindowSize = false
            didUpdateWindowSize()
        }
    }
    
    @objc(session:didAddAnchors:)
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        DDLogDebug("Add Anchors - \(anchors.debugDescription)")
        
        if webXRAuthorizationStatus == .notDetermined {
            for anchor in anchors {
                session.remove(anchor: anchor)
            }
            return
        }
        
        for addedAnchor: ARAnchor in anchors {
            if addedAnchor is ARFaceAnchor && !(configuration is ARFaceTrackingConfiguration) {
                print("Trying to add a face anchor to a session configuration that's not ARFaceTrackingConfiguration")
                continue
            }

            // Plane anchors stay in ARKit (hit testing and Lite Mode use them) but are not sent to JS.
            if addedAnchor is ARPlaneAnchor {
                continue
            }

            if shouldSend(addedAnchor)
                || webXRAuthorizationStatus == .worldSensing
                || webXRAuthorizationStatus == .videoCameraAccess
            // Tony: Initially I implemented a line below to allow face-based and image-based AR
            // experiences to work when operating in .singlePlane/AR Lite Mode.  However
            // if the user is choosing to operate in AR Lite Mode (i.e. a mode focused on
            // restricting the amount of data shared), they likely wouldn't want the website to
            // utilize any recognized ARFaceAnchors nor, potentially, ARImageAnchors.
            // Tony: Spoke with Blair briefly about this 2/4/19, allowing ARFaceAnchors
            //       but not ARImageAnchors
                || (webXRAuthorizationStatus == .lite && addedAnchor is ARFaceAnchor)
            {
                
                let addedAnchorDictionary = createDictionary(for: addedAnchor)
                addedAnchorsSinceLastFrame.add(addedAnchorDictionary)
                objects[anchorID(for: addedAnchor)] = addedAnchorDictionary
            }
            
            if let addedAnchor = addedAnchor as? ARImageAnchor {
                if webXRAuthorizationStatus == .worldSensing || webXRAuthorizationStatus == .videoCameraAccess {
                    guard let name = addedAnchor.referenceImage.name else { return }
                    let addedAnchorDictionary = createDictionary(for: addedAnchor)
                    if detectionImageActivationPromises[name] != nil {
                        let promise = detectionImageActivationPromises[name] as? ActivateDetectionImageCompletionBlock
                        // Call the detection image block
                        promise?(true, nil, addedAnchorDictionary as? [AnyHashable: Any])
                        detectionImageActivationPromises[name] = nil
                    }
                } else if webXRAuthorizationStatus == .minimal  {
                    session.remove(anchor: addedAnchor)
                }
            }
        }
    }
    
    @objc(session:didUpdateAnchors:)
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        //DDLogDebug(@"Update Anchors - %@", [anchors debugDescription]);
        //DDLogDebug(@"Update Anchors - %lu", anchors.count);
        for updatedAnchor: ARAnchor in anchors {
            if updatedAnchor is ARFaceAnchor && !(configuration is ARFaceTrackingConfiguration) {
                print("Trying to update a face anchor in a session configuration that's not ARFaceTrackingConfiguration")
                continue
            }
            
            updateDictionary(for: updatedAnchor)
        }
    }
    
    @objc(session:didRemoveAnchors:)
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        DDLogDebug("Remove Anchors - \(anchors.debugDescription)")
        for removedAnchor: ARAnchor in anchors {
            
            // logic makes no sense:  if the anchor is in objects[] list, remove it and send removed flag.  otherwise, ignore
            //        BOOL mustSendAnchor = [self shouldSendAnchor: removedAnchor];
            //        if (mustSendAnchor ||
            //            self.sendingWorldSensingDataAuthorizationStatus == SendWorldSensingDataAuthorizationStateAuthorized) {
            // Loading a world map runs the session with .removeExistingAnchors and restores the map's
            // anchors, which keep their saved identifiers. If anchors from the scan that produced the
            // map are still in the session, ARKit can report their removal after the restored anchor
            // with the same identifier is already live. Removing it here dropped iq3-origin from JS
            // and erased its name mapping, so the first load after saving never found the origin.
            if session.currentFrame?.anchors.contains(where: { $0.identifier == removedAnchor.identifier }) ?? false {
                DDLogDebug("Ignoring stale removal of a live anchor - \(removedAnchor.identifier.uuidString)")
                continue
            }
            let anchorID = self.anchorID(for: removedAnchor)
            if objects[anchorID] != nil {
                removedAnchorsSinceLastFrame.add(anchorID)
                objects[anchorID] = nil
                
                arkitGeneratedAnchorIDUserAnchorIDMap[removedAnchor.identifier.uuidString] = nil
                if let imageAnchor = removedAnchor as? ARImageAnchor,
                    let completion = detectionImageActivationAfterRemovalPromises[imageAnchor.referenceImage.name ?? ""] as? ActivateDetectionImageCompletionBlock
                {
                    activateDetectionImage(imageAnchor.referenceImage.name, completion: completion)
                    detectionImageActivationAfterRemovalPromises[imageAnchor.referenceImage.name ?? ""] = nil
                }
            } else {
                if arkitGeneratedAnchorIDUserAnchorIDMap[removedAnchor.identifier.uuidString] != nil {
                    DDLogDebug("Remove Anchor not in objects, but in UserAnchorIDMap - \(anchorID)")
                }
            }
        }
    }
}
