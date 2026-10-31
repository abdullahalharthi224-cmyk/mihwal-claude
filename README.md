# Mihwal · مِحوَل

[![Build IPA](https://github.com/abdullahalharthi224-cmyk/mihwal-claude/actions/workflows/build-ipa.yml/badge.svg?branch=main)](https://github.com/abdullahalharthi224-cmyk/mihwal-claude/actions/workflows/build-ipa.yml)

21 PDF and image tools for iPhone that run **100% on-device**: no server, no account, no tracking, no network.

- SwiftUI, iOS 17+, iPhone. Arabic first, English second, full RTL.
- The project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`.
  The `.xcodeproj` is never committed.
- Plan and per-tool spec: [`docs/ANALYSIS.md`](docs/ANALYSIS.md).

## Getting the app (no Mac needed)
Direct link to the newest build (published only when every test passed):
https://github.com/abdullahalharthi224-cmyk/mihwal-claude/releases/latest/download/Mihwal.ipa

Each release's notes start with the test result, e.g. "✅ 129 tests passed, 0 failed".
The badge above is green when the latest build on `main` passed.

Sign and install it with your signing service. Bundle id: `com.abdullah.mihwal.claude`, name under the icon: «مِحوَل C»
   (so it can be installed next to another build).

## Layout
```
Mihwal/App/            app entry, app state (favorites, recents)
Mihwal/Core/           shared logic (tool registry, later: files, thumbnails, progress)
Mihwal/DesignSystem/   DS tokens + shared components
Mihwal/Features/Home/  home grid, search, favorites, recents
Mihwal/Tools/<Tool>/   one folder per tool (Engine + ViewModel + View)
Mihwal/Resources/      String Catalog, assets
MihwalTests/           XCTest unit tests
```

## Dependencies
None. Only Apple frameworks.
