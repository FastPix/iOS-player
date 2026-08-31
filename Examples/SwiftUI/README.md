# FastPix iOS Player — SwiftUI Example

A minimal, self-contained SwiftUI app that plays a video with the FastPix iOS
Player and attaches the FastPix Data (analytics) SDK. Copy this folder into
your own project, or open it as-is.

## Run it

1. Open `FastPixPlayerExample.xcodeproj` in Xcode.
2. Select an iOS Simulator (or your device) and press **Run**.

The project references the `FastPixPlayerSDK` package from this repository via a
local package reference (`../..`), so no extra setup is needed.

## Configure

Both values live at the top of [`ContentView.swift`](FastPixPlayerExample/ContentView.swift):

```swift
enum FastPixConfig {
    static let workspaceKey = "WORKSPACE_KEY"                        // ← replace
    static let playbackID   = "7c8d5087-edf7-462f-a1b3-e2fbd30747fa" // demo asset
}
```

- **`workspaceKey`** — get yours from the [FastPix dashboard](https://dashboard.fastpix.io)
  under Workspaces. The bundled placeholder still exercises the analytics
  pipeline; the backend simply rejects its beacons until you set a real key.
- **`playbackID`** — defaults to a public FastPix demo video so the example
  runs unchanged. Replace it with your own playback ID.

## How it works

- `PlayerModel` (an `ObservableObject`) owns the `AVPlayerViewController` so the
  player and the attached SDK survive SwiftUI re-renders.
- `enableAnalytics(metadata:)` attaches the Data SDK **before** `prepare(...)`.
- `FastPixPlayerView` bridges the controller into SwiftUI via
  `UIViewControllerRepresentable`.
- Playback starts in `.onAppear` and is torn down in `.onDisappear` / the
  model's `deinit`.
