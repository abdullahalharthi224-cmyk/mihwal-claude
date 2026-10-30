# Mihwal · مِحوَل

21 PDF and image tools for iPhone that run **100% on-device**: no server, no account, no tracking, no network.

- SwiftUI, iOS 17+, iPhone. Arabic first, English second, full RTL.
- The project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`.
  The `.xcodeproj` is never committed.
- Plan and per-tool spec: [`docs/ANALYSIS.md`](docs/ANALYSIS.md).

## Getting the app (no Mac needed)
1. Open the **Actions** tab → **Build IPA** → the latest green run.
2. Download the **Mihwal-ipa** artifact (a zip that contains `Mihwal.ipa`).
3. Sign and install it with your signing service. Bundle id: `com.abdullah.mihwal`.

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
