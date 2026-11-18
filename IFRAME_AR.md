# AR sessions inside iframes (XR Viewer)

A page can run its WebXR `immersive-ar` session from an iframe. The Training Editor uses this: its WebVR player iframe enters AR while the editor page keeps running behind it.

## What is supported

- The top-level page, as before.
- A direct child iframe of the top page with the same origin (scheme, host, port). One level only. Nested and cross-origin iframes get no `navigator.xr` from the app.
- One AR owner per tab. The frame that last called `requestSession` owns AR. The previous owner gets `userStoppedAR`, so its session fires `end`. Across tabs, the existing "Close AR session?" prompt still applies.

## How it works

`XRViewer/Resources/webxr.js` is injected into every frame (`forMainFrameOnly: false` in `WebController.makeWebView`). It activates only in the top page and in eligible iframes. In an iframe it stays dormant: it sends `initAR` only when the page first calls `requestSession`.

Every bridge message carries `xrFrameToken`, a random id per document. `WebController` uses it to:

- reply to a request in the frame that sent it, using `evaluateJavaScript(_:in:in:)`;
- send per-frame AR data and native events (tracking state, interruptions, resize, `userStoppedAR`) only to the owner frame, or to the top page when nobody owns AR;
- refuse session actions (hit test, anchors, images, world map, feature points, `stopAR`) from frames that don't own AR.

Ownership is cleared when the owner calls `stopAR`, the top page navigates, or the tab is switched. It is also cleared when the owner frame disappears: the iframe sends `stopAR` on `pagehide`, and native treats a `javaScriptInvalidFrameTarget` error as "owner gone".

## Top-page layout while an iframe owns AR

When the iframe's session starts, its polyfill posts `{ message: '__xrviewerSubframeAR__', state: 'ar-start' }` to the parent. The top page's polyfill then:

- makes the iframe `position: fixed`, full screen and topmost, without moving it in the DOM (moving an iframe reloads it);
- sets `visibility: hidden` and a transparent background on `html` and `body`, so the camera shows through;
- clears `transform`, `filter`, `contain` and similar properties on the iframe's ancestors, so they can't trap the fixed iframe.

Inline styles are saved and restored on `ar-end`, or when native calls `window.__xrviewerSubframeAREnded()`. The editor page is hidden but not removed, so its scripts, timers and `postMessage` traffic keep running.

The top page gets a DOM event for each change:

```js
window.addEventListener('xrviewer-iframe-ar', (event) => {
    const { active, iframe } = event.detail; // pause or resume heavy editor work here
});
```

## Notes for page authors

- Give the iframe `allow="xr-spatial-tracking"`. The Training Editor's iframe already has it.
- An editor element whose CSS sets `visibility: visible` explicitly would show through the transparent iframe during AR.
- `postMessage` payloads whose `message` is `'__xrviewerSubframeAR__'` belong to the app. Page handlers can ignore them.

## Verify on a device

This change was written on Windows. It was not built in Xcode, run on a device, or run in a browser. `node --check XRViewer/Resources/webxr.js` passes.

1. A full-screen player in a top-level tab still enters and exits AR.
2. Training Editor: enter AR from the player iframe. The camera is visible and no editor UI is drawn on top.
3. Tap hit tests and anchors land where tapped. World map save/load and feature points work.
4. The editor and player keep exchanging messages during AR (for example, trigger a step change).
5. Exit AR: the editor layout comes back unchanged.
6. Reload or remove the iframe during AR: AR ends and the editor comes back.
7. Switch tabs during iframe AR: the prompt shows and AR ends. Returning to the tab shows the normal editor.
8. A page with a YouTube or ad iframe logs no `initAR` from those frames.
9. Enter and exit AR 20 times: the Xcode memory gauge returns to its baseline.
