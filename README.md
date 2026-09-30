# popAM

A tiny macOS menu bar activity monitor. Click the gauge in your menu bar to see CPU, memory, network, disk, and battery at a glance.

- Per-core CPU (grouped into performance / efficiency cores on Apple Silicon)
- Memory used, pressure, and swap
- Network up/down speed, disk free space and read/write speed
- Battery %, charging state, time remaining, cycle count
- Choose which cards appear and their order; optionally show 1–2 live values next to the menu bar icon

Requires macOS 14 (Sonoma) or later.

## Build and run

```bash
git clone https://github.com/Kaustubh-Pasu/popAM.git && cd popAM
open PopAM.xcodeproj           # then press ⌘R
```

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`); you only need it if you edit `project.yml`, then run `xcodegen generate`.

Or from the terminal:

```bash
xcodebuild -project PopAM.xcodeproj -scheme PopAM -configuration Release -destination 'generic/platform=macOS' -derivedDataPath build build
cp -R build/Build/Products/Release/popAM.app /Applications/
```

The app is ad-hoc signed and not notarized. If macOS blocks it the first time, right-click it in Finder, choose Open, then confirm.

## Tests

```bash
cd PopAMCore && swift test
```

## Roadmap (v2)

GPU usage, temperatures and fans, top processes, power flow, battery health, and battery temperature.

## License

MIT
