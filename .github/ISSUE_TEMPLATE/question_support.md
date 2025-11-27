---
name: Question/Support
about: Ask questions or get help with the FastPix iOS Player SDK
title: '[QUESTION] '
labels: ['question', 'needs-triage']
assignees: ''
---

# Question/Support

Thank you for reaching out! We're here to help you with the FastPix iOS Player SDK. To get faster and more accurate help, please provide the following information:

## Question Type
- [ ] How to use a specific feature
- [ ] Integration help
- [ ] Configuration question
- [ ] Performance question
- [ ] Troubleshooting help
- [ ] Other: _______________

## Question
**What would you like to know?**

<!-- Provide a clear and specific question about the iOS Player SDK -->

## What You've Tried
**What have you already attempted to solve this?**

```swift
import FastPixPlayerSDK

let playerVC = AVPlayerViewController()
playerVC.prepare(
    playbackID: "YOUR_PLAYBACK_ID",
    playbackOptions: PlaybackOptions(
        streamType: "on-demand",
        playbackToken: "YOUR_TOKEN"
    )
)

// Your attempted code here
```

## Current Setup
**Describe your current setup:**
- iOS project version, Swift version, player used (AVPlayer, custom player, etc.)

## Environment
- **SDK Version**: [e.g., 1.1.0]
- **iOS Version**: [e.g., iOS 17.0]
- **Xcode Version**: [e.g., 15.0]
- **Device/Simulator**: [e.g., iPhone 14 Pro, Simulator]
- **Player**: [e.g., AVPlayer / AVPlayerViewController / Custom]

## Configuration
**Current SDK configuration:**

```swift
playerViewController.prepare(
    playbackID: playbackID,
    playbackOptions: PlaybackOptions(
        streamType: "on-demand",
        playbackToken: playbackToken,
        customDomain: "your.custom.domain"
    )
)
```

## Expected Outcome
**What are you trying to achieve?**

<!-- Example: Improve buffering, enable DRM playback, use playlist, switch audio tracks, etc. -->

## Error Messages (if any)
```
<!-- Paste any error messages or unexpected behavior -->
```

## Additional Context

### Use Case
**What are you building?**
- [ ] Mobile app
- [ ] Video streaming service
- [ ] Video streaming service
- [ ] Other: _______________

### Timeline
**When do you need this resolved?**
- [ ] ASAP (blocking development)
- [ ] This week
- [ ] This month
- [ ] No rush

### Resources Checked
**What resources have you already checked?**
- [ ] README.md
- [ ] SDK documentation
- [ ] Examples
- [ ] Stack Overflow
- [ ] GitHub Issues
- [ ] Other: _______________

## Priority
Please indicate the urgency:
- [ ] Critical (Blocking production deployment)
- [ ] High (Blocking development)
- [ ] Medium (Would like to know soon)
- [ ] Low (Just curious)

## Checklist
Before submitting, please ensure:
- [ ] I have provided a clear question
- [ ] I have described what I've tried
- [ ] I have included my current setup and environment
- [ ] I have checked existing documentation
- [ ] I have provided sufficient context

---

**We'll do our best to help you get unstuck! 🚀**

**Helpful Resources:**
- [FastPix iOS SDK Documentation](https://docs.fastpix.io/docs/ios-player)
- [Stack Overflow](https://docs.fastpix.io/docs/ios-player)
- [GitHub Discussions](https://github.com/FastPix/iOS-player/discussions)