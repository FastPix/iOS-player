
# Player SDK for iOS

The FastPix iOS Player SDK is a flexible solution for integrating .m3u8 video streaming into your iOS applications. Whether you're streaming live broadcasts or on-demand content, the SDK provides playback with support for secure token-based access, custom domains, resolution control, and audio track switching. Once your video upload reaches the ready status, a stream URL is generated—paired with a unique playback ID—to deliver a smooth viewing experience with minimal configuration.

# Initial Setup

To get started with the FastPix Player SDK, follow these steps:

- **Log in to the FastPix Dashboard**: Navigate to the [FastPix-Dashboard](https://dashboard.fastpix.io) and log in with your credentials.
- **Create Media**: Start by creating a media using a pull or push method. You can also use our APIs for [Push media](https://docs.fastpix.io/docs/upload-videos-directly) or [Pull media](https://docs.fastpix.io/docs/upload-videos-from-url).
- **Retrieve Media Details**: After creation, access the media details by navigating to the "View Media" page.
- **Get Playback ID**: From the media details, obtain the playback ID.
- **Play Video**: Use the playback ID in the FastPix-player to play the video seamlessly.

[Explore our detailed guide](https://docs.fastpix.io/docs/get-started-in-5-minutes) to upload videos and getting a playback ID using FastPix APIs

# Installation

To install the SDK, you can use Swift Package Manager(SPM) :

## How to use Swift Package Manager 

The Swift Package Manager is a tool that simplifies the distribution and management of Swift code, seamlessly integrating with Xcode and the Swift build system to streamline downloading, compiling, and linking dependencies.

Here’s a quick guide for adding our package to your Xcode project [Step-by-step guide on using Swift Package Manager in Xcode](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app). 

To get started, use the repository URL in Xcode's search field: "https://github.com/FastPix/iOS-player".

**Import**

```swift
import FastPixPlayerSDK
```

# Features  of  iOS  Player  SDK

FastPix iOS Player SDK supports all the features mentioned below, ensuring easy integration, enhanced playback performance, and a customizable streaming experience for iOS applications.

[Click here](https://docs.fastpix.io/docs/overview-and-features) for a detailed overview.

## Media Playback: 

With FastPix iOS Player you can play live and on-demand videos using streamType and playbackID.

### For on-demand videos:

```swift
// create an object of AVPlayerViewController()  

lazy var playerViewController = AVPlayerViewController() 

// play the videos using playbackID and streamType is set to on-demand

playerViewController.prepare(playbackID: playbackID,playbackOptions: PlaybackOptions(streamType: "on-demand"))
```
### For live-stream videos:

```swift
// play the videos using playbackID and streamType is set to live

playerViewController.prepare(playbackID: playbackID,playbackOptions: PlaybackOptions(streamType: "live")) 
```

## Secure Playback:

In FastPix Player you can ensure content security with token-based authentication, secure playback IDs, and HTTPS support for both live and on-demand streams.You can give playbackToken using parameter "playbackToken"

### For live-stream videos:

```swift
// play the videos using playbackID,playbackToken and streamType is set to live

playerViewController.prepare(playbackID: playbackID, playbackOptions: PlaybackOptions(streamType: "live",playbackToken: playbackToken))
```

### For on-demand videos:

```swift
// play the videos using playbackID,playbackToken and streamType is set to on-demand

playerViewController.prepare(playbackID: playbackID, playbackOptions: PlaybackOptions(streamType: "on-demand",playbackToken: playbackToken)) 
```

## Custom Domains: 

With the FastPix iOS Player SDK, you can stream videos from your own custom domain, whether you're serving public content or securing private videos using playback tokens. This flexible setup allows you to maintain and optimize performance, control access to your media with minimal configuration.You can set your customDomain with parameter "customDomain"

### For on-demand videos:

```swift
// play the videos with custom Domain, playbackID, playbackToken and streamType is set to on-demand

playerViewController.prepare(playbackID: playbackID, playbackOptions: PlaybackOptions(customDomain: "customDomain", playbackToken: playbackToken, streamType: "on-demand")) 
```

### For live-stream videos:

```swift
// play the videos with custom Domain, playbackID, playbackToken and streamType is set to live

playerViewController.prepare(playbackID: playbackID, playbackOptions: PlaybackOptions(customDomain: "customDomain", streamType: "live")) 
```

## Audio Track Switching: 

- Allow users to dynamically switch between audio tracks during playback, perfect for multi-language or additional audio options.

- The FastPix iOS Player automatically detects and displays all available audio track options, If the playback supports or is integrated with multiple audio tracks simplifying the implementation process for dynamic audio switching.

## Resolution Control: 

FastPix iOS Player allows you to configure playback resolution, including minimum, maximum, specific, and range-based resolutions for optimized streaming.

| Option               | Description                                                                                                                       | Available Values                                                                                                                                                  | Default        |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- |
| **`minResolution`**  | Sets the **minimum resolution** for playback to avoid loading low-quality streams. Helps maintain baseline video quality.         | `.atLeast270p`, `.atLeast360p`, `.atLeast480p`, `.atLeast540p`, `.atLeast720p`, `.atLeast1080p`, `.atLeast1440p`, `.atLeast2160p` | `.standard`    |
| **`maxResolution`**  | Sets the **maximum resolution** to prevent very high-quality playback. Useful to control bandwidth or reduce buffering.           | `.upTo270p`, `.upTo360p`, `.upTo480p`, `.upTo540p`, `.upTo720p`, `.upTo1080p`, `.upTo1440p`, `.upTo2160p`                               | `.standard`    |
| **`resolution`**     | Forces a **specific fixed resolution** regardless of network quality. Disables adaptive playback. Best used for demos or testing. | `.set270p`, `.set360p`, `.set480p`, `.set540p`, `.set720p`, `.set1080p`, `.set1440p`, `.set2160p`                                         | `.standard`    |
| **`renditionOrder`** | Controls how resolution renditions are prioritized. Useful for customizing the adaptive strategy.                                 | `.standard`, `.descending`                                                                                                        | `.standard` |


### Play with a Minimum Resolution: 

```swift
// play videos with custom min-resolution and playbackID 

playerViewController.prepare(playbackID: playbackID, playbackOptions: PlaybackOptions(minResolution : .atLeast270p)) 
```

```swift
// play videos with custom min-resolution, playbackID and playbackToken 

playerViewController.prepare(playbackID: playbackID, playbackOptions: PlaybackOptions(minResolution : .atLeast270p, playbackToken: playbackToken)) 
```
### Play with a Maximum Resolution:

```swift
// play videos with custom max-resolution and playbackID  

playerViewController.prepare(playbackID: playbackID, playbackOptions: PlaybackOptions(maxResolution : .upTo1080p)) 
```

```swift
// play videos with custom max-resolution, playbackID and playbackToken 

playerViewController.prepare(playbackID: playbackID, playbackOptions: PlaybackOptions(maxResolution : .upTo1080p, playbackToken: playbackToken))
```
### Play with a Custom Resolution:

```swift
// play videos with a specific resolution, playbackID and playbackToken 

playerViewController.prepare(playbackID: playbackID, playbackOptions: PlaybackOptions(resolution : .set480p, playbackToken: playbackToken))
```

```swift
// play videos with in a specific range of resolution playbackID  and  playbackToken 

playerViewController.prepare(playbackID: playbackID, playbackOptions: PlaybackOptions(minResolution : .atLeast270p, maxResolution : .upTo1080p ,playbackToken: playbackToken)) 
```

## Rendition Order Customization: 

With the FastPix iOS Player SDK, you can configure resolution selection priorities to deliver an optimized viewing experience to user preferences.

```swift
// play videos with in a  specific range of resolution playbackID  and  renditionOrder 

playerViewController.prepare(playbackID: playbackID, playbackOptions: PlaybackOptions(minResolution :  (example :  .atLeast270p) ,maxResolution : (example :  .upTo1080p ,renditionOrder:  .descending )) 
```

## Data Integration: 

The FastPix iOS Player supports data integration for tracking video playback, user interaction, and environment details. This is useful for analytics, monitoring playback behavior, and generating detailed insights of the playback.

```swift
import FastpixVideoDataAVPlayer

let fpDataSDK = initAvPlayerTracking()

let customMetadata = [
    "data": [
        workspace_id: "WORKSPACE_KEY", // Unique key to identify your workspace (replace with your actual workspace key)
        video_title: "Test Content", // Title of the video being played (replace with the actual title of your video)
        video_id: "f01a98s76t90p88i67x", // A unique identifier for the video (replace with your actual video ID for tracking purposes)
        viewer_id: "user12345", // A unique identifier for the viewer (e.g., user ID, session ID, or any other unique value)
        video_content_type: "series", // Type of content being played (e.g., series, movie, etc.)
        video_stream_type: "on-demand", // Type of streaming (e.g., live, on-demand)

        // Custom fields for additional business logic
        custom_1: "", // Use this field to pass any additional data needed for your specific business logic
        custom_2: "", // Use this field to pass any additional data needed for your specific business logic

        // Add any additional metadata
    ]
]
// Track AVPlayer Controller
fpDataSDK.trackAvPlayerController(
    playerController: playerController,   // The AVPlayerViewController instance managing the playback
    customMetadata: customMetadata
)
```

## DRM Support:

FastPixPlayer supports DRM-encrypted playback using FairPlay.  
To enable DRM, follow the guide below and include token (playback token), drm-token (DRM license JWT), licenseURL (DRM license server URL), and certificateURL (FairPlay application certificate URL) as attributes.  

[Secure Playback with DRM – FastPix Documentation](https://docs.fastpix.io/docs/secure-playback-with-drm#/)

```swift

// play DRM-encrypted playback

if let token = self.playbackToken {
    let licenseURL = URL(string: "https://api.fastpix.io/v1/on-demand/drm/license/fairplay/\(self.playbackID)?token=\(token)")!
    let certificateURL = URL(string: "https://api.fastpix.io/v1/on-demand/drm/cert/fairplay/\(self.playbackID)?token=\(token)")!
            
    playerViewController.prepare(
        playbackID: playbackID,
        playbackOptions: PlaybackOptions(
            playbackToken: token,
            drmOptions: DRMOptions(licenseURL: licenseURL, certificateURL: certificateURL)
        )
    )
}
```

## Playlist Support

FastPix iOS Player now supports playlists, allowing you to manage and navigate multiple videos within a single playback session.

### Create a Playlist

```swift
let playlist = [ 
    FastPixPlaylistItem(
        playbackId: "<PLAYBACK_ID_1>",
        title: "Episode 1: <TITLE>",
        description: "<DESCRIPTION>",
        thumbnail: "https://example.com/thumbnail1.jpg",
        duration: "01:00:00", // format HH:MM:SS
        token: "<PLAYBACK_TOKEN>",   // optional
        drmToken: "<DRM_TOKEN>"      // optional
    ),
    FastPixPlaylistItem(
        playbackId: "<PLAYBACK_ID_2>",
        title: "Episode 2: <TITLE>",
        description: "<DESCRIPTION>",
        thumbnail: "https://example.com/thumbnail2.jpg",
        duration: "00:45:00",
        token: "<PLAYBACK_TOKEN>",
        drmToken: "<DRM_TOKEN>"
    ),
    FastPixPlaylistItem(
        playbackId: "<PLAYBACK_ID_3>",
        title: "Episode 3: <TITLE>",
        description: "<DESCRIPTION>",
        thumbnail: "https://example.com/thumbnail3.jpg",
        duration: "00:30:00",
        token: "<PLAYBACK_TOKEN>",
        drmToken: "<DRM_TOKEN>"
    )
]
```
### Add Playlist to Player

```swift
// Add the playlist directly to the player instance using this method

playerViewController.addPlaylist(playlist)
```

### Enable Auto-Play

```swift
// Automatically play the next item in the playlist

playerViewController.isAutoPlayEnabled = true
```

### Hide Default Controls

```swift
// Hide the SDK’s built-in player controls if you want custom UI

playerViewController.hideDefaultControls = true
```

### Observe Playlist State Changes

You can observe playlist state updates (such as when the current item changes) using `NotificationCenter`.  
This allows you to update your UI (titles, buttons, progress, etc.) whenever the playlist state changes.

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    setupPlaylistStateObserver()
}

private func setupPlaylistStateObserver() {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(playlistStateChanged),
        name: Notification.Name("FastPixPlaylistStateChanged"),
        object: playerViewController  // IMPORTANT: Observe the specific player instance
    )
}

@objc private func playlistStateChanged(_ notification: Notification) {
    DispatchQueue.main.async {
        // Example: Update current video title
        self.updateCurrentTitle()
        
        // Example: Update button visibility
        self.updateButtonVisibility()
        
        // Log the update
        if let current = self.playerViewController.currentPlaylistItem {
            NSLog("current item: \(current)")
        }
    }
}
```

### Playlist Navigation

FastPix Player SDK provides built-in methods to navigate between playlist items. You can move to the next or previous video, or jump directly to a specific index in the playlist. These methods can also be tied to your own UI controls (like **Next**, **Previous**, or **Jump to Episode** buttons), making it easy to customize the playback experience for your users. The index is zero-based (e.g., `jumpTo(index: 0)` plays the first item), and you can combine these navigation methods with the Playlist State Observer to dynamically update the UI (such as the current video title, button states, or thumbnails).

#### Example Usage

```swift
// Go to the next playlist item

playerViewController.next()

// Go back to the previous playlist item

playerViewController.previous()

// Jump to a specific item in the playlist (e.g., index 2)

playerViewController.jumpTo(index: 2)
```

## Customizable Player Support

FastPix iOS Player SDK now allows developers to create a fully custom video player UI by hiding the default SDK controls and implementing their own Play/Pause button, Seek Bar, Orientation handling, and additional interactive components.
This provides complete flexibility to build custom designs while still using the FastPix engine for playback, buffering, analytics, and playlists.

With customizable player support, you can:
- Embed the FastPix player inside any custom UIView
- Hide the SDK's native controls
- Add your own Play/Pause buttons
- Implement your own Seek Bar UI
- Create your own gesture-based UI (tap to show/hide)
- Customize layout for portrait/landscape

To get started, you simply hide the default controls and then use AVPlayerViewController inside your own UI container.

### Hide Default Controls
Disable the built-in player UI:

```swift 
playerViewController.hideDefaultControls = true
```
### Embed the Player Inside a Custom View
This is the first step for any custom UI setup.
Place the FastPix player inside your own UIView so you can overlay your custom controls.

```swift
func prepareAvPlayerController() {
    addChild(playerViewController)
    playerView.addSubview(playerViewController.view)
    playerViewController.didMove(toParent: self)

    playerViewController.view.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
        playerViewController.view.topAnchor.constraint(equalTo: playerView.topAnchor),
        playerViewController.view.bottomAnchor.constraint(equalTo: playerView.bottomAnchor),
        playerViewController.view.leadingAnchor.constraint(equalTo: playerView.leadingAnchor),
        playerViewController.view.trailingAnchor.constraint(equalTo: playerView.trailingAnchor)
    ])
}
```
### Custom Play/Pause Button
You can handle playback in two ways depending on your UI preference:
1.Use togglePlayPause() — the SDK automatically switches between play and pause.
2.Manually control playback by calling play() and pause().

```swift
private func setupPlayPauseButton() {
    playPauseButton = UIButton(type: .system)
    playPauseButton.translatesAutoresizingMaskIntoConstraints = false
    playPauseButton.tintColor = .white
    playPauseButton.backgroundColor = UIColor.black.withAlphaComponent(0.55)
    playPauseButton.layer.cornerRadius = 32
    playPauseButton.clipsToBounds = true

    let icon = UIImage(systemName: "pause.fill")?.withConfiguration(
        UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
    )
    playPauseButton.setImage(icon, for: .normal)

    playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
    playerView.addSubview(playPauseButton)

    NSLayoutConstraint.activate([
        playPauseButton.centerXAnchor.constraint(equalTo: playerView.centerXAnchor),
        playPauseButton.centerYAnchor.constraint(equalTo: playerView.centerYAnchor),
        playPauseButton.widthAnchor.constraint(equalToConstant: 64),
        playPauseButton.heightAnchor.constraint(equalToConstant: 64)
    ])
}

@objc private func playPauseTapped() {
    // Option 1: Toggle automatically (recommended)
    playerViewController.togglePlayPause()

    // Option 2: Manually control playback (use if needed)
    // playerViewController.play()
    // playerViewController.pause()
}
```
### Auto-Update Play/Pause Button

```swift
playerStatusObserver = player.observe(\.timeControlStatus, options: [.new, .initial]) {
    [weak self] player, _ in
    DispatchQueue.main.async {
        self?.updatePlayPauseButton(for: player.timeControlStatus)
    }
}
```
### Custom Seek Bar (FastPixSeekBar + FastPixSeekManager)
#### Add Seek Bar
```swift
private func setupSeekBar() {
    seekBar.translatesAutoresizingMaskIntoConstraints = false
    seekBar.layer.cornerRadius = 3
    playerView.addSubview(seekBar)

    NSLayoutConstraint.activate([
        seekBar.leadingAnchor.constraint(equalTo: playerView.leadingAnchor, constant: 16),
        seekBar.trailingAnchor.constraint(equalTo: playerView.trailingAnchor, constant: -16),
        seekBar.bottomAnchor.constraint(equalTo: playerView.bottomAnchor, constant: -20),
        seekBar.heightAnchor.constraint(equalToConstant: 28)
    ])

    seekBar.onSeekEnd = { [weak self] time in
        self?.playerViewController.seek(to: time)
    }
}
```
#### Seek Delegate

```swift
extension VideoPlayerViewController: FastPixSeekDelegate {

    func onBufferedTimeUpdate(loaded: TimeInterval, duration: TimeInterval) {
        seekBar.updateBuffer(loaded: loaded, duration: duration)
    }

    func onTimeUpdate(currentTime: TimeInterval, duration: TimeInterval) {
        seekBar.updateTime(current: currentTime, duration: duration)
    }

    func onSeekStart(at time: TimeInterval) {}
    func onSeekEnd(at time: TimeInterval) {}
}
```
#### Tap Gesture to Show/Hide Controls

```swift
@objc private func togglePlayerControls() {
    let shouldShow = playPauseButton.alpha == 0
    shouldShow ? showAllControls(animated: true) : hideAllControls(animated: true)
}
```
#### Auto-Hide After Delay

```swift
private func autoHideControls(after delay: TimeInterval = 3.0) {
    controlsHideWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
        self?.hideAllControls(animated: true)
    }
    controlsHideWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
}
```
#### Orientation Handling
##### Update layout when device rotates:

```swift 
override func viewWillTransition(
    to size: CGSize,
    with coordinator: UIViewControllerTransitionCoordinator
) {
    super.viewWillTransition(to: size, with: coordinator)

    coordinator.animate(alongsideTransition: { _ in
        self.updatePlayPauseConstraintsForOrientation()
        self.view.layoutIfNeeded()
    })
}
```
##### Orientation logic:

```swift 
private func isLandscapeMode() -> Bool {
    if #available(iOS 13.0, *) {
        let orientation = view.window?.windowScene?.interfaceOrientation
        return orientation == .landscapeLeft || orientation == .landscapeRight
    } else {
        return UIApplication.shared.statusBarOrientation.isLandscape
    }
}
```

### Picture-in-Picture (PiP): 

FastPix Player supports system Picture-in-Picture (PiP) on iOS 14+, allowing playback to continue when the app goes to background.

#### Enable PiP:
```swift
playerViewController.enablePiP = true
playerViewController.setupPiP(parent: self)
```

#### Start / Stop PiP: 
```swift
playerViewController.togglePiP()
```

#### Handle PiP active state : 
```swift
if playerViewController.isPiPActive() {
    return
}
```

#### Observe PiP state changes : 
```swift 
FastPixPiPStateChangedNotification
FastPixPiPAvailabilityChangedNotification
```

##### Note: 

- Call setupPiP(parent:) after the view appears
- Do not release the player while PiP is active

### Full-Screen Functionality:

FastPix provides a built-in full-screen manager for smooth inline ↔ full-screen transitions.

#### Setup Full-Screen :
```swift 
playerViewController.setupFullscreen(
    parent: self,
    container: playerView
)
```

#### Toggle Full-Screen :
```swift
playerViewController.toggleFullscreen()
```

#### Full-Screen State Updates: 
```swift
Notification.Name("FastPixFullscreenStateChangedNotification")
```

### Seek Bar Thumbnail Preview (Spritesheet): 

FastPix supports spritesheet-based thumbnail previews while scrubbing the seek bar.

#### Enable Spritesheet Preview :
```swift 
let previewConfig = FastPixSeekPreviewConfig()

playerViewController.loadSpritesheet(
    url: nil,
    previewEnable: true,
    config: previewConfig
)

playerViewController.setFallbackMode(.timestamp)
```

#### Get Preview During Scrubbing : 
```swift 
let result = playerViewController.fastpixThumbnailForPreview(at: time)

seekBar.updatePreviewThumbnail(
    result.image,
    time: time,
    useTimestamp: result.useTimestamp
)
```

##### Note : 

- Automatically falls back to timestamp if thumbnail is unavailable
- Works with playlists and custom seek bars

#### Each of these features is designed to enhance both flexibility and user experience, providing complete control over video playback, appearance, and user interactions in FastPix-player.

# Supporting tvOS

The FastPix Player SDK also supports tvOS, enabling developers to integrate seamless video playback on Apple TV applications with the same features available for iOS Mobile Applications.

## Installation on tvOS

- Add the SDK to your project using Swift Package Manager, similar to iOS Mobile Applications.
- Ensure your Xcode project supports tvOS as a deployment target.

### Usage Example

```swift
import UIKit
import AVKit
import FastPixPlayerSDK

class TVPlayerViewController: UIViewController {

    lazy var playerViewController = AVPlayerViewController()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.prepareAvPlayerController()

        let playbackOptions = PlaybackOptions(
            streamType: "STREAM_TYPE",
            playbackToken: "<YOUR_PLAYBACK_TOKEN>"
        )

        playerViewController.prepare(playbackID: "<PLAYBACK_ID>", playbackOptions: playbackOptions)

        playerViewController.player?.play()
    }

    func prepareAvPlayerController() {
        addChild(playerViewController)
        playerView.addSubview(playerViewController.view)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            playerViewController.view.leadingAnchor.constraint(equalTo: playerView.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: playerView.trailingAnchor),
            playerViewController.view.topAnchor.constraint(equalTo: playerView.topAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: playerView.bottomAnchor)
        ])
        
        playerViewController.didMove(toParent: self)
    }
}
```

# Documentation 

[Click here](https://docs.fastpix.io/docs/ios-player) for a detailed documentation on FastPix Player SDK for iOS.

# Development

## Maturity

This SDK is currently in beta, and breaking changes may occur between versions even without a major version update. To avoid unexpected issues, we recommend pinning your dependency to a specific version. This ensures consistent behavior unless you intentionally update to a newer release.
