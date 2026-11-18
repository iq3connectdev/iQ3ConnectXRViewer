# AR WorldMap bridge (XR Viewer)

Section D of the immersiveQ AR WorldMap plan, implemented in this fork. This file documents the bridge.

The polyfill is the injected script `XRViewer/Resources/webxr.js`. Methods are added in `installNonstandardExtension()` on the immersive `XRSession`. Existing world-map calls are unchanged: `nonStandard_getWorldMap`, `nonStandard_setWorldMap`, `nonStandard_getWorldMappingStatus`, `nonStandard_getTrackingState`, `nonStandard_getWorldMapRelocalizationInProgress`, `XRFrame.addAnchor(matrix, referenceSpace, name)`, `XRAnchor.detach()`.

WebVR feature check: `typeof session.nonStandard_getBridgeVersion === 'function' && session.nonStandard_getBridgeVersion() >= 2`.

## Session API

| Method | Returns |
| --- | --- |
| `nonStandard_getAnchors(referenceSpace)` | `[{ name, uuid, matrix: Float32Array(16) }]` |
| `nonStandard_setFeaturePointsEnabled(enabled, {intervalMs=250, maxPoints=1500})` | Promise that settles when the message is posted. Native does not call back. |
| `nonStandard_getFeaturePoints(referenceSpace)` | `{ timestamp, positions: Float32Array(3n), ids: Array }` or `null` |
| `nonStandard_getBridgeVersion()` | `2` |

`getAnchors` lists user `ARAnchor`s only (not planes, images, faces, hit-test placeholders, or deleted anchors). `name` and `uuid` are the same string: the anchor name. That is the key in `ARKitWrapper._anchors`.

Plane anchors are never sent to JS, in any authorization state, and the polyfill has no plane API (`nonStandard_getPlanes` and `XRPlaneMesh` were removed). Sending every plane's full geometry on every frame grew with scan time and added memory and main-thread load. ARKit plane detection stays on, because native hit testing (`existingPlaneUsingGeometry` / `existingPlaneUsingExtent`) and the Lite Mode plane picker use it. Native skips `ARPlaneAnchor` in `session(_:didAdd:)` and in the world-sensing re-add loop in `ARKController.m`. As a fallback, `createDictionary(for:)` still types a plane as `"plane"` (no geometry), and `_createOrUpdateAnchorObject` in `webxr.js` ignores plane payloads.

`getFeaturePoints` returns `null` until the first throttled payload. After that it returns the latest snapshot, including after the stream is turned off. `timestamp` is the polyfill-adjusted ARKit time of that payload.

`setFeaturePointsEnabled(false)` is the default. While disabled, native adds neither `featurePoints` nor `featurePointIds`.

## Poses

`XRFrame.addAnchor` converts a pose in `referenceSpace` into ARKit world with:

```text
T = getPose(localReferenceSpace, referenceSpace).matrix
worldMatrix = T * poseMatrix
```

`local` is the ARKit world frame (`session` `_localSpace`). These getters apply the inverse:

```text
toReference = inverse(T)
matrixInReferenceSpace = toReference * worldMatrix
pointInReferenceSpace = toReference * pointWorld
```

Passing the session `local` space makes `T` identity, so values stay in ARKit world. Any other reference space uses `referenceSpace._getSpaceRelativeTransform(localSpace)`, including origin offset. Viewer spaces refresh from the latest device pose.

## Feature points (native)

Message name: `setFeaturePointsEnabled`. Body: `{ enabled, intervalMs, maxPoints }`. Wired `WebController` → `ViewController` → `ARKController.setFeaturePointsEnabled`. Non-positive `intervalMs` / `maxPoints` fall back to 250 and 1500.

`updateARKData` adds a payload only when enabled and at least `intervalMs` has passed (`ARFrame.timestamp`). Keys:

- `featurePoints`: flat `[x, y, z, …]` in ARKit world
- `featurePointIds`: `ARPointCloud.identifiers` for those points

If the cloud is larger than `maxPoints`, indices are `i * count / maxPoints` (uniform stride). The arrays are not logged. Frames between samples omit the keys; JS keeps the previous snapshot.

## Anchors and culling

`removeDistantAnchors` skips any anchor whose `name` starts with `iq3-`. Other anchors, including distant planes, are unchanged.

`setWorldMap` still runs with reset-tracking and remove-existing-anchors, then re-adds `map.anchors` and records `identifier → anchor.name`. `anchorID()` publishes that name as the JS uuid, so after relocalization `nonStandard_getAnchors` lists the saved names. Empty names are omitted. This path is code-reviewed only; it has not been run on a device.

Loading a map in the same session that created it is a special case: the scan's anchors are still in the session and have the same identifiers as the map's anchors. Their removal can be reported after the restored anchor is live. `session(_:didRemove:)` ignores a removal when an anchor with that identifier is still in `currentFrame.anchors`. `userAnchorName(for:)` also falls back to `ARAnchor.name` for `iq3-` anchors, so the origin keeps its name even if the identifier → name entry is lost.

`XRAnchor.detach()` removes the anchor from the ARKit session, not only from JS, so a detached anchor is not saved into the next World Map. The polyfill posts `removeAnchors` with `{ uids, xrFrameToken }`, and native removes each anchor by name. Before this, nothing reached native: `removeAnchor` tested `!anchor instanceof XRAnchorOffset` (always false), and the handler dropped the bare-array body.

`addAnchor` rejects when native refuses the name (missing, or used by a live anchor). Native used to reply `{}`, which the polyfill took as success, storing an anchor that ARKit never tracked. A detached anchor's name is free again once native reports its removal, normally within a frame or two.

`worldMapRelocalizationInProgress` is cleared on the first frame where tracking is normal and mapping status is extending or mapped. It is checked in `session(_:didUpdate:)` on every frame, because `cameraDidChangeTrackingState` only fires on a tracking-state change. It is also cleared when the page leaves AR (`onXRUpdate(false)`: stop AR, page load, tab switch, permission denied) and when tracking is reset (`runSessionResettingTrackingAndRemovingAnchors`). Otherwise a relocalization that never finished kept the flag set, and the next session skipped its tracking reset and stayed relocalizing against the old map.

## Image detection and sessions

Image detection belongs to the WebXR session that set it up. When the page leaves AR (`onXRUpdate(false)`), `clearImageDetection()` drops the reference images, pending activations, the detection set, the tracked-image count, and the image anchors in ARKit and in `objects`. The polyfill's `_handleStopped()` drops `XRImageAnchor`s from `_anchors` without a removal event, so the page does not re-arm them after it left AR. Before this, all of it carried into the next AR session on the same page: `activateDetectionImage` resolved at once with the previous session's anchor, the next World Map load removed that anchor, and the page re-armed the image after relocalization. Activate, deactivate, and `setNumberOfTrackedImages` each call `session.run`, and a run after relocalization moved the restored anchors.

`setWorldMap` records the image anchors whose image is still in the detection set, and `session(_:didRemove:)` does not report their removal. ARKit finds the image again after relocalization, and that anchor updates the page's anchor under the same name (image anchors are keyed by image name), so the page does not re-arm the image.

## Detection-image destroy

`nonStandard_destroyDetectionImage` called `createDetectionImage`. It now calls `destroyDetectionImage`, and the message name is `destroyDetectionImage` (it previously posted `destroyImageAnchor`, which native does not handle).

## Verify on a device

This change was written on Windows. It was not built in Xcode and not run on a device. `node --check XRViewer/Resources/webxr.js` passes (plain script, not an ES module).

On a Mac, build the XR Viewer, install on a device, open an immersive-ar page (or the WebVR console) that already requests `worldSensing`, and use the same `local` reference space as `addAnchor`. Log counts, not the arrays.

1. `session.nonStandard_getBridgeVersion()` is `2`.
2. `nonStandard_setFeaturePointsEnabled(true)` then, inside `requestAnimationFrame`, `nonStandard_getFeaturePoints(local)`. `positions.length / 3` should grow and refresh about every 250 ms, and stay ≤ `maxPoints`. Call again with `false` and confirm later frames do not replace the snapshot.
3. `frame.addAnchor(matrix, local, 'iq3-origin')`, then `nonStandard_getAnchors(local)` includes that name. Walk away far enough to trip distance culling and confirm the `iq3-` anchor remains.
4. `nonStandard_getWorldMap()`, restart, `nonStandard_setWorldMap({worldMap})`. After tracking returns to normal, `getAnchors` lists the same names and poses within a few centimeters.
5. During a long scan, `nonStandard_getAnchors(local)` never lists plane UUIDs, and center-screen hit testing still lands on detected floors and walls.
6. Marker detection still activates and deactivates. Destroy uses `nonStandard_destroyDetectionImage(uid)`.
7. Place `iq3-anchor-1` and `iq3-anchor-2`, `detach()` the second, then save and load the map: `getAnchors` lists `iq3-origin` and `iq3-anchor-1` only. `addAnchor` with a name that is still live rejects.
8. Load a map somewhere it cannot relocalize, let the page give up, leave AR, and enter AR again on the same page: tracking resets and returns to normal instead of staying relocalizing.
9. Run WorldMap marker authoring, leave AR, and run it again on the same page without reloading: the restored anchors do not move when the marker scan starts, and the marker is detected.
10. Start WorldMap marker authoring with the marker in view, so it is detected before the map loads: the restored anchors do not move after relocalization, and the marker pose updates once the marker is seen again.
