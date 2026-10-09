<div align="center">

<img src="docs/assets/icon.png" width="128" alt="Wallet Card Skin Manager" />

# Wallet Card Skin Manager

**Give the cards in your Apple Wallet the look you want**

A small macOS tool: connect your iPhone over a cable and restyle the bank and transit cards in Wallet. Ships with sample skins — but the real fun is importing your own image to craft a one-of-a-kind card face.

[![Release](https://img.shields.io/github/v/release/zhanggenlove/WalletCardSkin?style=flat-square)](https://github.com/zhanggenlove/WalletCardSkin/releases)
[![Downloads](https://img.shields.io/github/downloads/zhanggenlove/WalletCardSkin/total?style=flat-square)](https://github.com/zhanggenlove/WalletCardSkin/releases)
[![License](https://img.shields.io/github/license/zhanggenlove/WalletCardSkin?style=flat-square)](LICENSE)
![Platform](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple)

[简体中文](README.md) · **English** · [日本語](README.ja.md)

</div>

---

> An independent, third-party tool, not affiliated with or endorsed by Apple or any bank, card issuer, or card network.
> **It only changes the card's display image — it never touches payment data, never uploads anything, and never affects tap-to-pay.**

## Preview

<div align="center">
<img src="docs/assets/screenshot-mac.png" width="760" alt="Mac main window" />
</div>

<div align="center">
<table>
<tr>
<td align="center"><img src="docs/assets/screenshot-iphone-card.png" width="300" alt="Card detail on iPhone" /><br/>Card detail on iPhone</td>
<td align="center"><img src="docs/assets/screenshot-iphone-wallet.png" width="300" alt="Wallet list" /><br/>Custom card faces in Wallet</td>
</tr>
</table>
</div>

## ✨ Features

- 🎴 **One-tap restyle**: scan the cards in Wallet, pick a skin, apply to iPhone.
- 🖼️ **Your own card face**: import an image and pan/zoom to crop it into a card.
- 🎨 **Built-in samples**: a handful of sample skins, ready to go.
- 🔒 **Local & private**: everything happens on your Mac over the cable — no uploads, no access to payment data.
- 🖥️ **Native feel**: built with SwiftUI; universal binary for Apple Silicon and Intel, with **no Python install required**.

## 📦 Install

1. Download the latest `WalletCardSkin.app.zip` from [Releases](https://github.com/zhanggenlove/WalletCardSkin/releases) and unzip it.
2. Drag `钱包卡片皮肤管家.app` into your Applications folder.
3. The app is not notarized by Apple, so Gatekeeper blocks it on first launch. Use any method below to allow it.

### Allow a blocked app (Gatekeeper)

**Option 1 · Remove the quarantine flag (recommended)** — in Terminal (adjust the path):

```bash
xattr -dr com.apple.quarantine "/Applications/钱包卡片皮肤管家.app"
```

**Option 2 · Right-click open** — right-click the app → "Open" → "Open" again in the dialog.

**Option 3 · System Settings** — after it's blocked, go to System Settings → Privacy & Security → "Open Anyway" at the bottom.

> These steps are only needed because the app isn't paid-notarized — not because it's unsafe. The source is fully open; review or build it yourself.

## 🚀 Usage

1. Connect your iPhone to the Mac with a cable and tap "Trust This Computer".
2. Open the Wallet app on iPhone (or double-press the side button).
3. Click "Start Scanning" in the app; once cards are found you enter the main screen.
4. Pick a skin, or click "Create your own" to import and crop your image.
5. Click "Apply to iPhone". When it finishes, **force-close the Wallet app and reopen it** to see the new card face (restart the iPhone if it still shows the old one).

**Requirements**: macOS 14+; iPhone on iOS 18+ (tested on iOS 27).

## ⚠️ Important

- **The original card face cannot be restored from within the app.** It is not backed up. To restore it, remove the card in Wallet and add it again (your issuer may require re-verification).
- Updating iOS or re-syncing a card in Wallet may revert the card face.
- Use at your own discretion and risk. See Help → Disclaimer inside the app.

## 🛠️ Build from source

```bash
git clone https://github.com/zhanggenlove/WalletCardSkin.git
cd WalletCardSkin
swift build        # compile
swift test         # run tests
```

Device communication relies on [AirCard](https://github.com/)'s helpers (`device_helper`, `airtraffic_host`) and its Python backend. To package a device-capable app:

```bash
AIR_CARD_ROOT=/path/to/AirCard-main scripts/package_app.sh
```

The script compiles a release, embeds Sparkle and the app icon, and downloads + bundles a standalone Python runtime ([python-build-standalone](https://github.com/astral-sh/python-build-standalone), arm64 + x86_64), so the target Mac needs no python3. For Apple Silicon only, use `WB_PYTHON_ARCHS=arm64 scripts/package_app.sh` to shrink it.

Drop images into `Resources/BuiltInSkins/` to ship them as built-in sample skins. See `docs/` for structure and roadmap.

## 🔍 How it works

The app links no private frameworks itself. All device communication is wrapped inside AirCard's helpers; the app only calls that verified boundary:

```text
build card artwork → write to the device via AirCard → refresh the Wallet cache
```

Card detection and skin sync all happen locally over the cable. The app goes online only to check for updates (Sparkle); it sends no card or device information.

## 🙏 Credits & License

Released under the [MIT License](LICENSE).

- Device communication via [AirCard](https://github.com/) (MIT, © 2026 Johnny Franks)
- Auto-update via [Sparkle](https://github.com/sparkle-project/Sparkle)
- Embedded Python from [python-build-standalone](https://github.com/astral-sh/python-build-standalone)

Full third-party license texts are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
