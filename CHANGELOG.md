# Changelog

All notable changes to this project will be documented in this file.

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

