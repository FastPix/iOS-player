
# Changelog

All notable changes to this project will be documented in this file.

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