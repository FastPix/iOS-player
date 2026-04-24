
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
playerViewController.enableAnalytics(
    metadata: [
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

- **Spritesheet Support for Secured Content**
  - Resolved limitation where spritesheet previews were not available for private and DRM-protected streams.
  - Added full support for timeline thumbnail previews in **FairPlay DRM** and **token-protected media**.
  - Ensured secure fetching and rendering of spritesheet assets without exposing protected URLs.
  - Improved scrubbing experience consistency across public and secured playback.

### Forward & Rewind Controls : 

FastPix iOS Player SDK provides Forward and Rewind seek controls functionality that integrates with AVPlayer and custom player UIs. These controls are designed to work reliably alongside a custom seekbar, gestures, and auto-hide logic.

#### Configure Forward & Rewind Controls : 

You can enable forward and rewind buttons and configure their seek increments separately for portrait and landscape modes.

```swift
playerViewController.configureSeekButtons(
    enablePortrait: true,
    enableLandscape: true,
    forwardIncrement: 10,   // Customizable
    backwardIncrement: 10  // Customizable
)
```
#### Behavior & State Handling : 
- Forward and rewind actions are fully synchronized with the player’s internal playback state.
- Controls are automatically disabled during active seek bar scrubbing to prevent conflicting seek operations.
- Auto-hide logic is paused during forward/rewind interactions and resumes safely afterward.
- Controls remain visible while users interact with forward or rewind buttons.
- Works consistently across play, pause, buffering, playback end, fullscreen, inline, and Picture-in-Picture (PiP) modes.

### Volume Control : 

The iOS Player SDK provides multiple ways to manage audio playback. Integrating applications can control device volume, implement on-screen volume controls, and toggle mute/unmute functionality using the SDK player instance.

#### Device Volume Control: 

The SDK respects the device’s system volume. Any changes made using the hardware volume buttons are automatically reflected during playback.

- Uses the device’s current system volume.
- No additional SDK configuration required.
- Changes apply instantly during playback.

#### On-Screen Volume Control : 

Integrators can implement custom on-screen volume controls (such as sliders or gestures) by updating the player’s volume programmatically.

- Ideal for custom UI sliders or gesture-based controls.
- Volume range: 0.0 (mute) to 1.0 (maximum).
- Applies only to the SDK player instance.

```swift

// Update the player’s volume based on the slider value
// Range: 0.0 (mute) to 1.0 (maximum volume)
playerViewController.setVolume(sender.value)

// Update the mute/unmute icon depending on whether volume is zero
// If slider value is 0, treat the player as muted
updateMuteIcon(isMuted: sender.value == 0)
```

#### Mute / Unmute Functionality : 

The SDK supports instant muting and unmuting of audio without changing the current volume level.

- Does not modify the existing volume value
- Useful for mute buttons and accessibility controls
- Takes effect immediately during playback

```swift

// Toggle the mute state of the player
// If currently playing audio, it will mute; if muted, it will unmute
playerViewController.toggleMute()

// Fetch the updated mute state after toggling
let isMuted = playerViewController.isMuted()
```

#### Volume state updates :

```swift
/// Called whenever the player's volume level changes
func onVolumeChanged(
    _ player: AVPlayerViewController,
    volume: Float
) {
    // Volume range: 0.0 (silent) to 1.0 (max)
    print("[Volume] Volume changed to \(volume)")
}

/// Called when the player is muted or unmuted
func onMute(
    _ player: AVPlayerViewController,
    isMuted: Bool
) {
    // true = muted, false = unmuted
    print("[Volume] Mute state changed: \(isMuted)")
}
```

### Playback Loop : 

Playback Loop in iOS Player SDK enables automatic replay of the video when playback reaches the end. This is useful for previews, short videos, and continuous playback experiences.

```swift

// By default, playback loop is disabled (false)

// Enable playback loop
// When enabled, the video restarts automatically after reaching the end
playerViewController.isLoopEnabled = true

// Disable playback loop
// When disabled, the video stops once playback reaches the end
playerViewController.isLoopEnabled = false
```

### Autoplay :

Autoplay in iOS Player SDK allows the player to start playback automatically as soon as the content is ready, without requiring explicit user interaction.

```swift
// By default, autoplay is disabled (false)

// Enable autoplay
// When enabled, playback starts automatically as soon as the video is ready
playerViewController.isAutoPlayEnabled = true

// Disable autoplay
// When disabled, the user must manually start playback
playerViewController.isAutoPlayEnabled = false
```

### Playback Speed Control : 

With the FastPix iOS Player SDK, playback speed can be modified dynamically during playback without interrupting the video or reloading the stream. Changes take effect immediately and remain active until the playback rate is updated again or reset to the default value.

- Supports slower playback for detailed viewing (e.g., tutorials, training videos)
- Enables faster playback for quick consumption (e.g., reviews, highlights)
- Works seamlessly during play, pause, and seek operations
- Does not affect video quality, buffering logic, or audio sync

#### Available Playback Speeds

The SDK supports the following playback speeds:
- **0.25x** - Quarter speed (slow motion)
- **0.5x** - Half speed
- **0.75x** - Three-quarter speed
- **1.0x** - Normal speed (default)
- **1.25x** - 1.25x speed
- **1.5x** - 1.5x speed
- **1.75x** - 1.75x speed
- **2.0x** - Double speed

```swift
// By default, the playback speed is set to 1x (normal playback)

// Set the playback speed to a specific value (e.g., 1x,0.25x)
playerViewController.setPlaybackSpeed(.1x)

// Increase the playback speed to the next supported rate
// Example: 1x → 1.25x → 1.5x → 2x
playerViewController.incrementPlaybackRate()

// Decrease the playback speed to the previous supported rate
// Example: 2x → 1.5x → 1.25x → 1x
playerViewController.decrementPlaybackRate()

// Get the current playback speed of the player
// Returns the active playback rate (e.g., 1x, 1.5x)
playerViewController.currentPlaybackRate()
```

#### playbackspeed state updates :

```swift
/// Called whenever the playback speed of the player changes
func onPlaybackRateChanged(
    _ player: AVPlayerViewController,
    rate: Float
) {
    // Current playback rate (default is 1.0x)
    print("[PlaybackRate] Playback speed changed to \(rate)x")
}
```

### Network Handling : 

FastPix iOS Player SDK includes built-in network awareness to handle real-world connectivity changes during playback.

- Automatically detects network changes (Wi-Fi, Cellular, Offline)
- Pauses playback when the network is lost
- Optionally resumes playback when the network is restored
- Improves stability during buffering, stalls, and network switches
- Exposes network state updates so apps can show custom UI like No Internet or Reconnecting

>**NOTE:**
>The SDK handles playback logic, while integrators control UI and retry behavior.

### Skip Controls (Intro / Songs / Credits) :

FastPix iOS Customizable Player SDK supports OTT-style skip controls using time-based segments.

- Supports Skip Intro, Skip Songs, and Skip Credits
- Skip segments can be configured per playlist item
- SDK automatically applies skip ranges during playback
- Skip button visibility is managed based on current playback time
- Skip state resets automatically during playlist transitions
- Fully compatible with custom player UI

#### Configure Skip Segments per Playlist Item:

```swift
let item = FastPixPlaylistItem(
    
    // Playback ID associated with the video
    playbackId: "<PLAYBACK_ID>",
    
    // Title of the content (used for UI / playlist display)
    title: "Episode 1",
    
    // Define skip segments for this video
    skipSegments: [
        
        // Skip Intro from 10s to 90s
        SkipSegment(startTime: 10, endTime: 90, type: .intro),
        
        // Skip Song section from 6:00 to 8:00
        SkipSegment(startTime: 360, endTime: 480, type: .song),
        
        // Skip Credits from 9:00 to 9:56
        SkipSegment(startTime: 540, endTime: 596, type: .credits)
    ]
)
```

#### Initialize Skip Manager

Initialize the skip manager after the player is ready (recommended inside `viewDidAppear`).

```swift
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // Ensure UI updates and player setup happen on the main thread
    DispatchQueue.main.async {

        // Make sure the AVPlayer instance is fully initialized
        // Skip manager depends on the player being available
        guard self.playerViewController.player != nil else { return }

        // Attach the Skip Manager and set the delegate
        // This enables skip segment detection and visibility callbacks
        self.playerViewController.setupSkipManager(delegate: self)

        // Setup custom Skip button UI (Intro / Song / Credits)
        self.setupSkipButton()
    }
}
```

#### Handle Skip Button Visibility:

```swift
// Called by the SDK when playback enters or exits a skip segment
func onSkipVisibilityChanged(isVisible: Bool) {
    
    // Show skip button when a skip segment is active
    // Hide it when playback is outside skip ranges
    skipButton.isHidden = !isVisible
}
```

>**NOTE:**
>The SDK manages skip logic and timing. Integrators are responsible for rendering the skip UI.

### Audio Track Switching:

FastPix iOS Player SDK automatically detects all available audio tracks from the stream and allows users to switch between them dynamically during playback — ideal for multi-language content.

#### Set Up Audio Track Delegate
```swift
playerViewController.audioTrackDelegate = self
```

#### Set Preferred Audio Track

Set a preferred audio track by language name. The SDK will automatically select it when the video loads. If the preferred track is not available, the manifest default is used.
```swift
// Pass the display name of the language (case-insensitive)
playerViewController.setPreferredAudioTrack("Hindi")
```

#### Get Available Audio Tracks
```swift
let audioTracks = playerViewController.getAudioTracks()
```

#### Get Current Audio Track
```swift
let currentTrack = playerViewController.getCurrentAudioTrack()
```

#### Switch Audio Track
```swift
// Switch by track ID
playerViewController.setAudioTrack(trackId: track.id)
```

#### Handle Audio Track Events

Conform to `FastPixAudioTrackDelegate` to receive track updates:
```swift
extension VideoPlayerViewController: FastPixAudioTrackDelegate {

    // Called when audio tracks are loaded or updated
    func onAudioTracksUpdated(tracks: [AudioTrack]) {
        print("Available audio tracks:", tracks)
    }

    // Called when the active audio track changes
    func onAudioTrackChange(selectedTrack: AudioTrack) {
        print("Audio switched to:", selectedTrack.label)
    }

    // Called when a track switch fails
    func onAudioTrackFailed(error: AudioTrackError) {
        print("Audio switch failed:", error)
    }

    // Called when a track switch starts or finishes
    func onAudioTrackSwitching(isSwitching: Bool) {
        if isSwitching {
            // Show loading indicator
        } else {
            // Hide loading indicator
        }
    }
}
```

#### AudioTrack Model

| Property | Type | Description |
|---|---|---|
| `id` | `String` | Unique identifier for the track |
| `languageCode` | `String` | BCP-47 language tag (e.g. `"hi"`, `"en"`) |
| `languageName` | `String` | Display name of the language (e.g. `"Hindi"`) |
| `label` | `String` | Human-readable label shown in UI |
| `isSelected` | `Bool` | Whether this track is currently active |
| `isDefault` | `Bool` | Whether this is the default track |

### Subtitle Track Switching:

FastPix iOS Player SDK supports WebVTT-based subtitle tracks. It automatically parses the HLS manifest, fetches subtitle segments, and renders cues in sync with playback.

#### Set Up Subtitle Track Delegate
```swift
playerViewController.subtitleTrackDelegate = self
```

#### Set Preferred Subtitle Track

Set a preferred subtitle track by language name. The SDK will automatically select it when the video loads.
```swift
// Pass the display name of the language (case-insensitive)
playerViewController.setPreferredSubtitleTrack("Hindi")
```

#### Get Available Subtitle Tracks
```swift
let subtitleTracks = playerViewController.getSubtitleTracks()
```

#### Get Current Subtitle Track
```swift
// Returns nil if subtitles are disabled
let currentTrack = playerViewController.getCurrentSubtitleTrack()
```

#### Switch Subtitle Track
```swift
// Switch by track ID
try? playerViewController.setSubtitleTrack(trackId: track.id)
```

#### Disable Subtitles
```swift
playerViewController.disableSubtitles()
```

#### Render Subtitle Cues

The SDK delivers subtitle text in real time via `onSubtitleCueChange`. You are responsible for rendering it in your UI:
```swift
private let subtitleLabel: UILabel = {
    let label = UILabel()
    label.textColor = .white
    label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
    label.textAlignment = .center
    label.numberOfLines = 0
    label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
}()
```

Position it above the seek bar inside `playerViewController.view`:
```swift
private func setupSubtitleLabel() {
    playerViewController.view.addSubview(subtitleLabel)
    playerViewController.view.bringSubviewToFront(subtitleLabel)

    NSLayoutConstraint.activate([
        subtitleLabel.leadingAnchor.constraint(
            equalTo: playerViewController.view.leadingAnchor, constant: 20),
        subtitleLabel.trailingAnchor.constraint(
            equalTo: playerViewController.view.trailingAnchor, constant: -20),
        subtitleLabel.bottomAnchor.constraint(
            equalTo: playerViewController.view.bottomAnchor, constant: -130)
    ])
}
```

#### Handle Subtitle Events

Conform to `FastPixSubtitleTrackDelegate` to receive subtitle updates:
```swift
extension VideoPlayerViewController: FastPixSubtitleTrackDelegate {

    // Called when subtitle tracks finish loading
    func onSubtitlesLoaded(tracks: [SubtitleTrack]) {
        print("Subtitle tracks available:", tracks)
    }

    // Called when the active subtitle track changes
    func onSubtitleChange(track: SubtitleTrack?) {
        print("Subtitle switched to:", track?.label ?? "Off")
    }

    // Called every time a new subtitle cue becomes active
    func onSubtitleCueChange(information: SubtitleRenderInfo) {
        DispatchQueue.main.async {
            if information.text.isEmpty {
                self.subtitleLabel.isHidden = true
            } else {
                self.subtitleLabel.text = information.text
                self.subtitleLabel.isHidden = false
            }
        }
    }

    // Called when subtitle tracks fail to load
    func onSubtitlesLoadedFailed(error: SubtitleTrackError) {
        print("Subtitle load failed:", error)
    }
}
```

#### SubtitleTrack Model

| Property | Type | Description |
|---|---|---|
| `id` | `String` | Unique identifier for the track |
| `languageCode` | `String` | BCP-47 language tag (e.g. `"hi"`, `"en"`) |
| `label` | `String` | Human-readable label shown in UI |
| `playlistURL` | `String?` | Resolved URL of the subtitle playlist |
| `isSelected` | `Bool` | Whether this track is currently active |

#### SubtitleRenderInfo Model

| Property | Type | Description |
|---|---|---|
| `text` | `String` | Subtitle cue text. Empty string means the cue has ended |
| `timestamp` | `Double` | Playback time in seconds when the cue is active |
| `languageCode` | `String` | Language code of the active subtitle track |

> **NOTE:**
> - Subtitle rendering is the host app's responsibility. The SDK delivers cue text only.
> - Always call `disableSubtitles()` when switching playlist items to prevent stale cues from appearing on videos without subtitles.
> - Add the subtitle label to `playerViewController.view`, not `self.view`, to ensure correct positioning across orientations and fullscreen transitions.
> - The SDK automatically stops the subtitle parser when `disableSubtitles()` is called or when the player is detached.

### Adaptive Bitrate (ABR) & Resolution Switching

The FastPix iOS Player SDK provides a powerful and flexible video quality system that supports both:

- **Adaptive Bitrate Streaming (ABR)** – automatic quality selection  
- **Manual Resolution Switching** – user-controlled quality selection  

This enables developers to build a fully customizable video player experience similar to modern OTT platforms.

#### Setup Quality Manager:

```swift
// Assign delegate to receive quality-related callbacks
playerViewController.qualityDelegate = self

// Initialize the quality manager
// This is required to enable ABR + manual switching support
playerViewController.setupQualityManager(delegate: self)
```

#### Fetch Available Quality Levels:

Each QualityLevel contains: label (e.g., Auto, 240p, 480p, 720p)
- bitrate
- resolution
- isAuto

```swift
// Fetch all available resolution levels from the current stream
// This will include "Auto" (ABR) + all manual resolutions
let levels = playerViewController.getResolutionLevels()
```

#### Get Current Quality Level:

```swift
// Get the currently active resolution level
// Useful for updating UI (e.g., highlight selected quality)
let current = playerViewController.getCurrentResolutionLevel()
```

#### Switch Quality Level (Manual):

```swift
// Switch to a specific quality level selected by the user
// Example: 720p, 1080p, etc.
playerViewController.setResolutionLevel(level)
```

##### Note: 
- Playback continues from the same position
- Player may buffer briefly during the switch

#### Reset to AutoMode (ABR Mode):

```swift
// Switch back to Auto mode (ABR enabled)
// Player will now automatically adjust quality based on network
playerViewController.resetToAuto()
```

#### Custom Quality Selection UI:
You can build custom UI (Action Sheet, Dropdown, etc.):

```swift
// Iterate through all available quality levels
for level in levels {

    // If "Auto" is selected → enable ABR
    if level.isAuto {
        playerViewController.resetToAuto()
    } else {
        // Otherwise switch to selected manual resolution
        playerViewController.setResolutionLevel(level)
    }
}
```

#### Dynamic Quality Loading : 
Quality levels are loaded only after playback starts:

```swift
// Manually trigger loading of quality levels from the stream
// This parses the HLS manifest (.m3u8) and extracts renditions
playerViewController.qualityManager?.loadQualityLevels()
```
- Best Practice: Trigger this when `player.timeControlStatus == .playing`

#### Delegate Callbacks: 

```swift
// Called when all quality levels are fetched and ready
func onQualityLevelsUpdated(levels: [QualityLevel]) {
    print("Quality levels available: \(levels.count)")
}

// Called when user or ABR switches the resolution
func onQualityLevelChanged(selectedLevel level: QualityLevel) {
    print("Switched to: \(level.label)")
}

// Called when a quality switch is in progress
// Use this to show/hide loading indicators in UI
func onQualitySwitching(isSwitching: Bool) {
    print("Switching in progress...")
}

// Called when quality switching fails
// Handle errors gracefully (e.g., show fallback UI)
func onQualityLevelFailed(error: QualityLevelError) {
    print("Quality switch failed: \(error)")
}
```

### Preloading & Precaching Support :

FastPix iOS Player SDK supports preloading and precaching of upcoming playlist items to eliminate startup delays and reduce buffering when the user advances to the next video.

- Preloading initializes AVPlayerItem instances for upcoming videos in the background using a shadow AVPlayer, warming up AVFoundation's URL session cache so that when the SDK loads the same stream URL, initial buffering is already complete.
- Precaching downloads and stores HLS segments to disk, ensuring content is served from the local cache on subsequent playback requests. DRM-protected items (with a drmToken) are automatically skipped during precaching since their segments are encrypted and cannot be cached.

Both managers expose delegate callbacks so the host app can react to preload and cache state changes in the UI.

#### Setup Preload & Precache Managers :

Initialize both managers and assign delegates before starting playback:

```swift
private let preloadManager = PreloadManager.shared
private let precacheManager = PrecacheManager.shared

override func viewDidLoad() {
    super.viewDidLoad()

    playerViewController.addPlaylist(playlist)

    // Assign delegates to receive status callbacks
    preloadManager.delegate = self
    precacheManager.delegate = self

    // Start preloading and precaching after the playlist is ready
    preloadNextVideos()
    precacheUpcomingVideos()
}
```

#### Preload Upcoming Videos :

Preloads the next 2 items after the currently playing index. You can customize the number of items to preload. Call this method when the playlist position changes (for example, `next()`, `previous()`, `jumpTo()`, or `FastPixPlaylistStateChanged`).

```swift
private func preloadNextVideos() {
    let currentIndex = playerViewController.currentPlaylistIndex
    let currentId = currentIndex < playlist.count ? playlist[currentIndex].playbackId : ""

    let upcoming = playlist
        .enumerated()
        .filter { $0.offset > currentIndex }
        .prefix(2)
        .map { $0.element }
        .filter {
            // Skip if already loading, ready, or currently playing
            let status = preloadManager.preloadStatus(forVideo: $0.playbackId)
            switch status {
            case .idle: return $0.playbackId != currentId
            default:    return false
            }
        }

    let itemsToPreload: [(id: String, item: AVPlayerItem)] = upcoming.compactMap { playlistItem -> (id: String, item: AVPlayerItem)? in
        guard let url = buildPlaybackURL(for: playlistItem) else { return nil }
        let playerItem = AVPlayerItem(url: url)
        return (id: playlistItem.playbackId, item: playerItem)
    }

    guard !itemsToPreload.isEmpty else { return }
    preloadManager.preload(items: itemsToPreload)
}
```

#### Precache Upcoming Videos :

Precaches HLS segments for the current and next video. DRM-protected items are automatically skipped.

```swift
private func precacheUpcomingVideos() {
    let currentIndex = playerViewController.currentPlaylistIndex
    let upcoming = playlist
        .enumerated()
        .filter { $0.offset >= currentIndex }
        .prefix(2)
        .map { $0.element }

    for item in upcoming {
        // Skip DRM-protected content — encrypted segments cannot be cached
        guard item.drmToken.isEmpty else { continue }

        let host = item.customDomain.isEmpty == false
            ? item.customDomain
            : "stream.fastpix.io"

        var urlString = "https://\(host)/\(item.playbackId).m3u8"
        if !item.token.isEmpty {
            urlString += "?token=\(item.token)"
        }

        guard let url = URL(string: urlString) else { continue }
        precacheManager.startPrecaching(url: url)
    }
}
```

### Consume a Preloaded Item Before Navigation :

When navigating to the next item, call `consumePreloadedItem(for:)` before calling `next()`. This detaches the shadow player so AVFoundation's URL session cache can be reused by the SDK when loading the same stream URL.

```swift
let nextIndex = playerViewController.currentPlaylistIndex + 1
if nextIndex < playlist.count {
    let nextId = playlist[nextIndex].playbackId
    if preloadManager.consumePreloadedItem(for: nextId) != nil {
        print("🚀 Preloaded item consumed — AVFoundation cache warm for: \(nextId)")
    }
}
_ = playerViewController.next()
```

#### Re-trigger on Playlist State Changes :

Always re-trigger preloading and precaching inside the `FastPixPlaylistStateChanged` observer so the window stays ahead of the current position:

```swift
@objc private func playlistStateChanged(_ notification: Notification) {
    DispatchQueue.main.async {
        // ... your existing reset logic ...
        self.preloadNextVideos()
        self.precacheUpcomingVideos()
    }
}
```

#### Cleanup :

Stop all in-flight preload and precache tasks when the view controller is deallocated:

```swift
deinit {
    preloadManager.clearAll()
    precacheManager.stopAllPrecaching()
}
```

#### PreloadManagerDelegate :

Conform to `PreloadManagerDelegate` to receive preload lifecycle callbacks:

```swift
extension VideoPlayerViewController: PreloadManagerDelegate {

    // Called when preloading begins for a video
    func videoPreloadDidStart(forId id: String) {
        print("Preload started for: \(id)")
    }

    // Called when the preloaded AVPlayerItem is buffered and ready
    func videoPreloadDidBecomeReady(forId id: String) {
        print("Preload ready — instant playback available for: \(id)")
    }

    // Called when preloading fails
    func videoPreloadDidFail(forId id: String, error: Error?) {
        print("Preload failed for \(id): \(error?.localizedDescription ?? "unknown error")")
    }

    // Called when a preload task is cancelled
    func videoPreloadDidCancel(forId id: String) {
        print("Preload cancelled for: \(id)")
    }

    // Called when the SDK auto-advances and consumes the preloaded buffer
    func videoPreloadDidAutoAdvance(toId id: String) {
        print("Auto-advance consumed preloaded item: \(id)")
    }
}
```

#### PrecacheManagerDelegate :

Conform to `PrecacheManagerDelegate` to observe whether segments are served from disk or fetched from the network:

```swift
extension VideoPlayerViewController: PrecacheManagerDelegate {

    // Called when a request is served from the local disk cache
    func videoCacheDidHit(url: URL) {
        print("Cache HIT — served from disk: \(url.lastPathComponent)")
    }

    // Called when a request is not in the cache and is being downloaded
    func videoCacheDidMiss(url: URL) {
        print("Cache MISS — downloading and caching: \(url.lastPathComponent)")
    }
}
```

#### NOTE:
- Call preloadNextVideos() and precacheUpcomingVideos() after every playlist navigation event (next(), previous(), jumpTo()) and inside playlistStateChanged to keep the preload window current.
- DRM-protected items (drmToken is non-empty) are automatically excluded from precaching. Preloading still applies to DRM items as AVFoundation handles license fetching separately.
- Always call consumePreloadedItem(for:) before next() to hand off the buffered data to AVFoundation's URL session cache.
- Call preloadManager.clearAll() and precacheManager.stopAllPrecaching() in deinit to avoid memory leaks and dangling background tasks.

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
