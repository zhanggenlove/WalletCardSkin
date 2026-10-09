# WalletBloom

WalletBloom is a native macOS SwiftUI starter project for designing and applying visual skins to Apple Wallet cards.

## Run

Requires macOS 14 or later. The app always talks to a real iPhone through AirCard's helpers — there is no mock mode. Package it with `scripts/package_app.sh` (see below), or when running from Xcode / `swift run`, set `AIR_CARD_ROOT` to an AirCard checkout containing `build/device_helper` and `aircard_backend.py`. Without a toolchain the app opens on an error screen explaining what is missing.

```text
Package.swift
Sources/WalletBloom/
├── Domain/Models.swift       Device, WalletCard, Skin (+ Artwork), FlashJob
├── Domain/Services.swift     Transport, scanner, engine, skin catalog boundaries
├── Infrastructure/           Airlift adapter, flash coordinator, local library, skin exporter
├── Views/                    Onboarding, scan status, workspace (carousel, skins, toolbar)
├── WalletBloomStore.swift    Phase state machine and import/scan/flash orchestration
└── WalletBloomApp.swift      Single-window app entry point
Tests/WalletBloomTests/       Process runner, hash extraction, flash result, library, renderer
Resources/                    Info.plist, AppIcon.icns (regenerate with `swift scripts/make_icon.swift`)
```

Run the tests with `swift test`.

## Package a real-device app

Build AirCard's helper binaries first, run `swift package resolve` once to fetch Sparkle, then run `scripts/package_app.sh`. The script embeds `Sparkle.framework` and the app icon. The script expects the source at `/Users/zhanggen/Downloads/AirCard-main` by default; set `AIR_CARD_ROOT` to override it. If the helper binaries are built elsewhere, set `AIR_CARD_BIN_ROOT`. It refuses to package when `device_helper` or `airtraffic_host` is missing, so an app without device support is never produced.

## Current behavior

The store drives a single phase state machine: `launching → onboarding → scanning → ready`, with `noCards` and `failed` as scan outcomes.

- **Onboarding** — shown when no iPhone is connected, and again whenever the phone is unplugged. Lists the connect / trust / open Wallet / scan steps and polls `device_helper list` every 2 seconds; steps 1–2 tick off once the phone appears. If cards were saved earlier, connecting skips straight to the workspace.
- **Scanning** — watches device logs for 20 seconds with a progress bar and can be cancelled. Bare hashes are only trusted from Wallet-related processes, which filters out the push/sync tokens that look identical. New cards are saved to WalletBloom's own library; AirCard's `~/.aircard_cards.json` is read but never written.
- **No cards / failed** — native `ContentUnavailableView` screens with rescan, retry and contact-support actions (the support address is a placeholder in `SupportContact`).
- **Workspace** — stacked card carousel (click, swipe, ← / → keys; right-click to remove a misdetected card), a skin grid that previews on the card immediately and remembers the choice per card, and a bottom bar for importing an image, rescanning and applying (⌘↩).
- **No restore** — WalletBloom does not back up the original card art. The disclaimer and a confirmation before applying (with "Don't show again") explain that restoring requires removing and re-adding the card in Wallet; the wording lives in `RestoreNotice`.
- **Sync** — applying a skin opens a modal sheet with the backend's real step progress; the window is locked until it finishes, and quitting asks for confirmation.
- **Disclaimer & privacy** — a one-time disclaimer must be accepted on first launch (bump `DisclaimerView.version` when the text changes); both texts are always available from the Help menu and the toolbar.
- **Menus** — WalletBloom (About, Check for Updates…), File (Import Image ⌘O, Scan Cards ⌘R), Cards (previous/next, rename, apply ⌘↩, remove), Help (privacy, disclaimer, support). Updates use Sparkle and stay disabled until `SUFeedURL` / `SUPublicEDKey` are set — see `docs/roadmap.md`.
- **Language** — Simplified Chinese only for now, including system menu items; internationalization is planned in `docs/roadmap.md`.
- **Local library** — `~/Library/Application Support/WalletBloom/` keeps scanned and removed cards, the skin applied to each card, and copies of imported images.
- Skins come from a `SkinCatalog`; `PlaceholderSkinCatalog` returns eight gradients until a server catalog exists. `Skin.Artwork` already supports `.remoteImage`, which is downloaded before flashing.

## Airlift integration

`Infrastructure/AirliftWallet.swift` now reflects the checked AirCard CLI boundary:

- `device_helper list` returns paired device records.
- `aircard_backend.py flash <udid> <card_hash> <image_path>` prepares `1536x969` artwork, builds the PNG/PDF assets, writes them through `write_files_batch`, and removes `FrontFace`, `PlaceHolder`, and `Preview` from both cache directories.
- Saved card hashes are read from `~/.aircard_cards.json`; AirCard discovers new hashes by watching device logs while Wallet is open.

The app uses the helpers bundled under `Contents/Resources` first, then falls back to `AIR_CARD_ROOT`; if neither is available it shows the missing-toolchain error. The bundle build must copy the signed helper binaries and Python resources before enabling real-device use.

The application-level sequence remains:

```text
build assets → write assets through transport → refresh Wallet
```

The private `MobileDevice.framework` and `AirTrafficHost.framework` calls remain inside AirCard's helper binaries. WalletBloom does not link those private frameworks directly; it invokes the verified helper boundary and keeps exploit-specific details out of SwiftUI and domain code.
