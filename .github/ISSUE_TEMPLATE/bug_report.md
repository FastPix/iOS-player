---
name: Bug Report
about: Report an issue related to the FastPix iOS Player SDK
title: '[BUG] '
labels: bug
assignees: ''
---

# Bug Description
Provide a clear and concise description of the issue you encountered with the FastPix iOS Player SDK.

---

# Steps to Reproduce

### 1. **SDK Setup**

Add the FastPix iOS Player SDK using Swift Package Manager:

```
https://github.com/FastPix/iOS-player.git
```

Import the library in your Swift file:

```swift
import FastPixPlayerSDK
```

### 2. **Example Code to Reproduce**

Provide a minimal reproducible code snippet that demonstrates the issue. Example:

```swift
import FastPixPlayerSDK
import AVKit

// Initialize AVPlayerViewController
lazy var playerViewController = AVPlayerViewController()

// Attempt to play an on-demand video
playerViewController.prepare(
    playbackID: "<PLAYBACK_ID>",
    playbackOptions: PlaybackOptions(streamType: "on-demand")
)

// Example: Dispatch player events (if using FastPix Video Data SDK)
import FastpixVideoDataAVPlayer

let fpDataSDK = initAvPlayerTracking()
let metadata = [
    "data": [
        "workspace_id": "WORKSPACE_KEY",
        "video_title": "Test Video",
        "video_id": "VIDEO_ID",
        "video_stream_type": "on-demand"
    ]
]

fpDataSDK.trackAvPlayerController(playerController: playerViewController, customMetadata: metadata)
```

Replace this snippet with the exact code where the bug occurs.

---

# Expected Behavior
```
<!-- Describe what you expected to happen -->
```

# Actual Behavior
```
<!-- Describe what actually happened -->
```

---

# Environment

- **SDK Version**: [e.g., 1.0.3]
- **iOS Version**: [e.g., iOS 17.2]
- **Device/Simulator**: [e.g., iPhone 14 Pro, Xcode Simulator]
- **Xcode Version**: [e.g., 15.3]
- **Integration Method**: Swift Package Manager (SPM) / Manual
- **Player Type**: [AVPlayer, FastPixPlayerSDK, Custom Player]

---

# Logs / Errors / Stack Trace
```
Paste console logs, crash logs, or SDK error responses here
```

---

# Additional Context
Add any additional information that might help us troubleshoot, such as:

- DRM playback enabled
- Custom domains used
- Audio track switching
- Resolution controls or restrictions
- Playlist usage

---

# Screenshots / Screen Recording
If applicable, attach screenshots or a video demonstrating the issue.

