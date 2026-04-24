
# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0]

- **Preload & Precache Support**
  - Added PreloadManager (singleton via PreloadManager.shared) to initialize AVPlayerItem instances for upcoming playlist items in the background using a shadow AVPlayer, warming AVFoundation's URL session cache before the user navigates to the next video.
  - Added PrecacheManager (singleton via PrecacheManager.shared) to download and store HLS segments to disk, serving content from the local cache on subsequent playback requests for reduced startup latency.
  - Introduced `preload(items:)` to queue one or more (id: String, item: AVPlayerItem) pairs for background buffering.
  - Introduced `preloadStatus(forVideo:)` to query the current preload state of a video — useful for filtering out items that are already loading, ready, or currently playing before queuing a new preload.
  - Introduced `consumePreloadedItem(for:)` to detach a preloaded item from the shadow player before calling next(), allowing AVFoundation's URL session cache to be reused by the SDK when loading the same stream URL.
  - Introduced `clearAll()` on PreloadManager to cancel all in-flight preload tasks and release buffered items — call this in deinit to prevent memory leaks.
  - Introduced `startPrecaching(url:)` on PrecacheManager to begin downloading HLS segments for a given stream URL to disk.
  - Introduced `stopAllPrecaching()` on PrecacheManager to cancel all active precache downloads — call this in deinit alongside `clearAll()`.
  - DRM-protected items (drmToken is non-empty) are automatically excluded from precaching since their segments are encrypted and cannot be meaningfully cached. Preloading still applies to DRM items as AVFoundation handles license fetching separately.
  - Introduced `PreloadManagerDelegate` with the following callbacks:
    - `videoPreloadDidStart(forId:)` — fires when background buffering begins for a video
    - `videoPreloadDidBecomeReady(forId:)` — fires when the AVPlayerItem is buffered and ready for instant playback
    - `videoPreloadDidFail(forId:error:)` — fires when preloading fails, providing the error for logging or retry logic
    - `videoPreloadDidCancel(forId:)` — fires when a preload task is cancelled (e.g., via clearAll())
    - `videoPreloadDidAutoAdvance(toId:)` — fires when the SDK auto-advances to the next playlist item and consumes the preloaded buffer.
  - Introduced `PrecacheManagerDelegate`` with the following callbacks:
    - `videoCacheDidHit(url:)` — fires when a segment request is served from the local disk cache
    - `videoCacheDidMiss(url:)` — fires when a segment is not cached and is being downloaded from the network
  - Preloading and precaching are automatically re-triggered on next(), previous(), jumpTo(), and `FastPixPlaylistStateChanged` to keep the preload window ahead of the current playlist position.
  - Fully compatible with token-protected streams, custom domains, playlist-based playback, and all existing SDK features.

## [1.0.0]

- **Adaptive Bitrate (ABR) & Resolution Switching**
  - Added support for Adaptive Bitrate Streaming (ABR) to automatically adjust video quality based on network conditions, ensuring smooth playback with reduced buffering.
  - Enabled manual resolution switching, allowing users to select specific quality levels (e.g., 240p, 480p, 720p) during playback.
  - Introduced `QualityLevel` model with properties such as label, bitrate, resolution, and auto-mode indicator.
  - Added `setupQualityManager(delegate:)` to initialize and manage quality-related operations.
  - Added `qualityDelegate` to receive real-time updates for quality changes and availability.
  - Added `getResolutionLevels()` to fetch all available quality levels dynamically from the stream.
  - Added `getCurrentResolutionLevel()` to retrieve the currently active quality level.
  - Added `setResolutionLevel(_:)` to allow manual switching between available quality levels.
  - Added `resetToAuto()` to switch back to automatic ABR mode.
  - Implemented dynamic loading of quality levels after playback starts for accurate detection based on stream data.
  - Introduced delegate callbacks:
    - `onQualityLevelsUpdated` for receiving available quality levels
    - `onQualityLevelChanged` for tracking successful quality switches
    - `onQualitySwitching` for indicating switching state
    - `onQualityLevelFailed` for handling errors during switching
  - Designed to work effortlessly with custom player UI, enabling OTT-style quality selectors (Auto / Manual modes).
  - Fully compatible with HLS streaming, buffering logic, and playlist-based playback.

## [0.11.1]

- **Fixed**
  - Fixed Swift Package Manager configuration.
  - Updated `swift-tools-version`.
  - Improved package compatibility with Xcode.

## [0.11.0]

- **Enhanced Spritesheet Support**
  - Added support for spritesheet-based timeline preview for **private media**.
  - Enabled spritesheet preview for **DRM-protected content (FairPlay)**.
  - Improved thumbnail loading mechanism to work seamlessly with secured playback URLs.
  - Ensured compatibility with token-based and signed URL playback flows.
  - Optimized preview rendering performance for smoother scrubbing experience across all content types.

## [0.10.0]

- Updated iOS Data Core SDK by updating the SDK’s default metrics collection domain to improve endpoint reliability and alignment with current infrastructure.

## [0.9.0]

- **Audio Track Switching**
  - Added `setPreferredAudioTrack(languageName:)` to set a preferred audio language by display name (case-insensitive).
  - Preferred audio track is automatically applied on every playlist item change, not just the first video.
  - SDK now resets the preferred track selection state on each player attach, ensuring consistent behavior across playlist transitions.
  - Introduced `FastPixAudioTrackDelegate` with callbacks for track updates, track changes, switching state, and errors.
  - Added `getAudioTracks()` to retrieve all available audio tracks for the current item.
  - Added `getCurrentAudioTrack()` to retrieve the currently active audio track.
  - Added `setAudioTrack(trackId:)` to switch audio tracks programmatically during playback.
  - Falls back to the manifest default track if the preferred language is not available in the stream.
- **Subtitle Track Switching**
  - Added `setPreferredSubtitleTrack(languageName:)` to set a preferred subtitle language by display name (case-insensitive).
  - Preferred subtitle track is automatically applied on every playlist item change.
  - SDK resets subtitle parser and selection state on each player attach to prevent stale cues across playlist transitions.
  - Introduced `FastPixSubtitleTrackDelegate` with callbacks for tracks loaded, track change, cue change, and errors.
  - Added `getSubtitleTracks()` to retrieve all available subtitle tracks for the current item.
  - Added `getCurrentSubtitleTrack()` to retrieve the currently active subtitle track, or `nil` if subtitles are off.
  - Added `setSubtitleTrack(trackId:)` to switch subtitle tracks programmatically during playback.
  - Added `disableSubtitles()` to turn off subtitles and stop the WebVTT parser.
  - Real-time subtitle cue delivery via `onSubtitleCueChange(information:)` with text, timestamp, and language code.
  - Built-in WebVTT parser that fetches and parses subtitle segments from HLS manifest-resolved playlist URLs.
  - Falls back to the manifest default track if the preferred language is not available in the stream.

## [0.8.0]

- **Network Handling**
  - Added real-time network monitoring (Wi-Fi, Cellular, Offline).
  - Automatically pauses playback on network loss and resumes on reconnection (configurable).
  - Exposed network state callbacks for custom UI and handling.
  - Improved playback stability during buffering, stalls, and network switches.
- **Skip Controls (Intro / Songs / Credits)**
  - Added support for Skip Intro, Skip Songs, and Skip Credits using time-based skip segments.
  - Skip segments can be configured per asset or per FastPixPlaylistItem.
  - SDK automatically validates and applies skip ranges during playback.
  - Introduced SkipManager APIs to set, clear, and trigger skips.
  - Skip button visibility is managed by the SDK based on playback time.
  - Skip state resets automatically during playlist transitions.
  - Fully compatible with custom UI implementations.

## [0.7.0]

- **Volume Control**
  - Added device-level volume support, reflecting system volume changes made via hardware buttons.
  - Introduced on-screen volume control APIs for building custom sliders or gesture-based volume controls.
  - Added mute / unmute functionality with proper state handling.
  - Ensured volume slider UI and mute state remain synchronized with the player’s audio state
- **Playback Loop**
  - Added Playback Loop support to automatically restart playback when the video reaches the end.
  - Loop behavior works seamlessly across inline playback, fullscreen, and Picture-in-Picture (PiP) modes.
  - Enabled simple configuration using `isLoopEnabled`.
  - Playback loop is disabled by default to preserve standard playback behavior.
- **Autoplay**
  - Added Autoplay support to automatically start playback once the media is ready.
  - Enabled simple configuration using `isAutoPlayEnabled`.
  - Autoplay behavior extends to playlist playback for automatic item transitions.
  - Autoplay is disabled by default to maintain user-controlled playback.
- **Playback Speed Control**
  - Added Playback Speed Control to dynamically adjust playback rate during runtime.
  - Supports multiple playback rates including slow-motion and fast-forward options.
  - Set a specific playback rate, Increment playback speed, Decrement playback speed, Retrieve the current playback rate.
  - Playback speed changes apply instantly without interrupting playback or affecting buffering, video quality, or audio sync.
  - Default playback speed is set to 1x (normal playback)

## [0.6.0]

- **Forward & Rewind Controls**
  - Added configurable seek increments via: `configureSeekButtons(enablePortrait:enableLandscape:forwardIncrement:backwardIncrement:)`
  - Forward and rewind actions are fully synchronized with the player’s internal playback state and are automatically disabled during active seek bar scrubbing to prevent conflicting seeks.
  - Improved user interaction handling — controls remain visible during forward/rewind interactions, and auto-hide logic pauses during seek actions and resumes safely afterward

## [0.5.0]

- **Picture-in-Picture (PiP)**  
  - Enable PiP with `enablePiP = true`.  
  - Check state via `isPiPAvailable` and `isPiPActive`.  
  - Toggle with `togglePiP()` and observe via `FastPixPiPStateChangedNotification`.
- **Full-Screen Mode**  
  - Smooth inline ↔ full-screen transitions using `FastPixFullscreenManager`.  
  - Configure layout with `configureConstraints(normal:fullscreen:)`.  
  - Observe state via `FastPixFullscreenStateChangedNotification`.
- **Spritesheet & Timeline Preview**  
  - Show thumbnails on seek bar with `loadSpritesheet(url:previewEnable:config:)`.  
  - Clear with `clearSpritesheet()`.  
  - Fall back to timestamp-only preview with `setFallbackMode(.timestamp)`.

## [0.4.0]

- FastPix iOS Player now supports fully customizable player controls.
- Integrate your own Play/Pause button while staying synced with the player’s internal playback state.
- Introduced support for a custom Seek Bar using FastPixSeekManager with real-time updates for: Current playback time, Total duration, Buffered time, Seek start/end events.
- Developers can now manage orientation handling manually, making it easier to build custom full-screen or embedded player UIs.
- Built-in seek navigation improvements (seekForward(), seekBackward(), seekToPercentage()) for enhanced control customization.
- Custom UI elements can now listen to playback and buffering updates using delegate callbacks to stay perfectly in sync with the player.

## [0.3.0]

 - FastPix iOS Player now supports playlist.
 - Create and manage playlists with multiple `FastPixPlaylistItems`.  
 - Add playlist directly to the player using `addPlaylist()` method.  
 - Auto-play option (`isAutoPlayEnabled`) to automatically continue playback with the next item.  
 - Option to hide the SDK’s default controls (`hideDefaultControls`) for building custom UI.  
 - Playlist state notifications via `NotificationCenter` (`FastPixPlaylistStateChanged`) for updating UI elements such as titles, buttons, or thumbnails.  
 - Built-in navigation methods: `next()`, `previous()`, and `jumpTo(index:)` for moving between items.  
 - Navigation methods can also be connected to custom UI buttons (e.g., Next/Previous/Episode selectors) 

## [0.2.0]

 - FastPix iOS Player now supports DRM via Apple FairPlay for content protection.

## [0.1.0]

### Added
  - **Media Playback**: Support for both live and on-demand streaming via `.m3u8` playback.
  - **Token-based Secure Playback**: Enables playback with `playbackToken` for secured streams.
  - **Custom Domain Support**: Allows streaming from custom domains with optional secure access.
  - **Audio Track Switching**: Automatic detection and switching of multiple audio tracks in supported streams.
  - **Resolution Control**:
    - Support for minimum (e.g., `.atLeast270p`) and maximum (e.g., `.upTo1080p`) resolution limits.
    - Fixed resolution option (e.g., `.set480p`).
    - Range-based resolution configuration.
- **Rendition Order Customization**: Added support for ascending or descending rendition selection.
- **Swift Package Manager Support**: SDK is installable via SPM using the repo URL.
