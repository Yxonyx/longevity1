# Longevity Digital Twin

A personal longevity optimization app for iOS and Apple Watch.

## Features

### MVP
- Dashboard with readiness score
- Biomarker tracking
- Supplement management
- Apple Watch complications

### v1.0
- CGM glucose integration
- OCR lab report upload
- Biological age calculator (PhenoAge)
- Photo-to-macro food analysis

### v2.0
- N-of-1 experiment engine
- WatchConnectivity real-time sync
- Zone 2 training with haptic coaching
- Longevity Horizon visualization

## Requirements

- iOS 17.0+
- watchOS 10.0+
- Xcode 15.0+

## Build

```bash
xcodebuild -project Longevity.xcodeproj -scheme Longevity -destination 'platform=iOS Simulator,name=iPhone 15'
```

## CI/CD

This project uses GitHub Actions for automated builds. Push to `main` or `develop` to trigger builds.

## License

Private - All rights reserved
