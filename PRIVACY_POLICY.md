
# iQ3Connect XR Viewer App Privacy Statement

iQ3Connect XR Viewer is an augmented reality (AR) viewer that lets you create and run AR experiences built with web technologies and ARKit. This is a project targeted at developers wanting to design and test web-based AR applications like [iQ3Connect](https://iq3connect.com) on iOS. This privacy statement explains what data the app collects, and how that data is used.

## Data Sources and Usage

iQ3Connect XR Viewer exposes a number of AR related sensors to web-based AR applications including audio, video, motion tracking and scene geometry data. iQ3Connect XR Viewer will always ask before activating and sharing any sensor data, but always be cautious when visiting untrusted websites. The following section describes data and its usage within iQ3Connect XR Viewer.

**Location data**: iQ3Connect XR Viewer always asks before determining and sharing your location with a requesting website (for example, if a map website needs your location to provide directions). To determine location, it may use your operating system’s geolocation features, Wi-fi networks, cell phone towers, or IP address, and may send this data to Google's geolocation service, which has its own  [privacy policy](https://www.google.com/privacy/lsf.html). iQ3Connect XR Viewer also combines macro-level localization with more precise positioning from AR Kit’s motion tracking API. This data is used to support multi-user persistent AR sessions across devices.

**Audio and video data**: iQ3Connect XR Viewer exposes an image processing datapath that allows websites to locally process camera frames for tasks like relocalization or object detection. Like standard web browsers, iQ3Connect XR Viewer supports access to audio and video for use in web-based teleconferencing applications. XR Browser will always prompt users to warn them whenever audio or video interfaces are requested by a website.

**Motion tracking data**: Motion tracking and position data can be transmitted to web sites that wish to establish multi-user shared AR experiences. Sharing this data is required for one user to see the position of another user in AR. iQ3Connect XR Viewer does not locally store motion tracking data and all websites that request motion data will prompt a user with a confirmation dialog.

**Face tracking data**: iQ3Connect XR Viewer exposes AR Kit Face Tracking data to enable in-browser AR experience like avatars with animated faces or the addition of special effects on top of video conferencing feeds (e.g. virtual glasses, hats, etc). Face tracking data is not stored locally and users are prompted when a website accesses any depth or scene geometry data.

**Depth API and scene geometry data**: Depth and Scene geometry data is used to make interaction with real-world objects look more realistic in AR. This includes being able to place objects naturally on surfaces as well as having realistic occlusions. iQ3Connect XR Viewer does not locally store depth or geometry data and all websites that request this data will prompt a user with a confirmation dialog.

**Account data**: iQ3Connect XR Viewer does not require account login data. Any login data required by external websites falls under their privacy policy. See Cached Data section below for information about website content management.

## Website Access

Like common web browsers, data made available via W3C standards for HTML, CSS, & JavaScript are accessible to opened websites. Access to any third-party websites would fall under their associated privacy policies. iQ3Connect XR Viewer adheres to the WebXR standard in terms of what local data is exposed as described in their  [privacy policy](https://immersive-web.github.io/webxr/privacy-security-explainer.html).

## Cached Data

To improve performance, the app may cache website content, metadata, and other cookies. All of this data is locally stored on the device. It will be deleted when the app removed from the device.
