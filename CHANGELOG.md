
# Changelog

All notable changes to this project will be documented in this file.

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