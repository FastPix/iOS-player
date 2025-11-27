# FastPix iOS Player SDK - Documentation PR

## Documentation Changes

### What Changed
- [ ] New documentation added
- [ ] Existing documentation updated
- [ ] Documentation errors fixed
- [ ] Code examples updated
- [ ] Links and references updated

### Files Modified
- [ ] README.md
- [ ] docs/ files
- [ ] USAGE.md
- [ ] CONTRIBUTING.md
- [ ] Other: _______________

### Summary
**Brief description of changes:**

<!-- Describe what documentation was added, updated, or fixed for the iOS SDK -->

### Code Examples
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
```

### Testing
- [ ] All code examples tested on iOS
- [ ] Links verified
- [ ] Grammar checked
- [ ] Formatting consistent

### Review Checklist
- [ ] Content is accurate
- [ ] Code examples work as expected
- [ ] Links are working
- [ ] Grammar is correct
- [ ] Formatting is consistent

---

**Ready for review!**
