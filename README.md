# FlashView

<p align="center">
  <img src="Sources/FlashView/Resources/Assets.xcassets/Logo.png" alt="FlashView Logo" width="200">
</p>

<p align="center">
  <img src="Sources/FlashView/Resources/Assets.xcassets/screenshot-1.png" alt="FlashView Screenshot" width="800">
</p>

# FlashView

FlashView is a free, simple, fast image viewer and rater for macOS, built with SwiftUI.

> [!IMPORTANT]
> This is a vibe coded application built for personal use. Please use with care.
>
> Feel free to fork it, make changes, and raise a PR — or just drop a system prompt in an issue and I can make changes quickly. Thank you!

## Why FlashView?

I built FlashView because I had tons of photos sitting on my drive and no quick way to triage them. Every photo management app I tried was either too heavy, too slow, or locked behind a paywall. All I wanted was a simple, keyboard-driven tool to rapidly flip through images, rate them into a few buckets (Good, Maybe, Bad), and move on. I couldn't find a free app that did exactly that — so I built one.

## Installation

Download the latest release from the [Releases](../../releases) page:

1. Grab the `.dmg` file (universal build — works on both Apple Silicon and Intel Macs)
2. Open the DMG and drag **FlashView.app** to your **Applications** folder
3. Launch FlashView and start triaging your photos!

## Features

- **Instant Folder Browsing:** Opens large directories of photos instantly.
- **Keyboard-first Navigation:** Use left and right arrows to quickly browse without touching your mouse.
- **Instant Rating:** Press `1` through `3` to apply star ratings directly to the image file metadata.
- **Local AI Powered Features:**
  - **Background Removal:** One-click background removal powered by Apple's Vision framework.
  - **AI Enhanced Filters:** Apply high-quality Fujifilm-inspired film simulations and smart color grading.
- **Privacy First:** Every single bit of processing happens on your machine. No data is sent to the cloud, ensuring your photos stay private.
- **Slideshow Mode:** Press `Space` to start/stop an automatic slideshow (advances every 2 seconds).
- **Quick Deletion:** Press `d` to immediately move the current image to the macOS Trash.
- **Sidebar & Editing:** Quickly switch between folders and tweak exposure, contrast, and saturation with live previews.

## Build and Run

1. Open your terminal and navigate to the `FlashView/` directory.
2. Run the build script:
   ```bash
   ./build_app.sh
   ```
3. Open the built application:
   ```bash
   open FlashView.app
   ```
   Or double-click `FlashView.app` in Finder.

## Keyboard Shortcuts

| Key     | Action                          |
| ------- | ------------------------------- |
| `→`     | Next Photo                      |
| `←`     | Previous Photo                  |
| `1`-`3` | Apply Rating (Bad, Maybe, Good) |
| `Space` | Toggle Slideshow                |
| `d`     | Move Photo to Trash             |

## Mouse Controls

- **Right-Click (Preview):** Open a context menu to quickly tag or delete the current photo.
- **Left Sidebar:** Click arrows to expand folders and filter by ratings.
- **Right Panel (Filter icon):** Adjust editing controls and film simulations.

## Contributing

Contributions are welcome! If you find a bug or have a feature request, please open an issue. You are also welcome to fork the repository and submit pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

> **⚠️ Disclaimer:** FlashView is a self-healing application, powered by [OpenClaw](https://openclaw.ai).
