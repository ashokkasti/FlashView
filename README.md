# FlashView

A lightweight, fast native macOS photo gallery application optimized for rapid photo review, tagging, and minimal friction.

## Features
- **Instant Folder Browsing:** Opens large directories of photos instantly.
- **Keyboard-first Navigation:** Use left and right arrows to quickly browse without touching your mouse.
- **Instant Rating:** Press `1` through `5` to apply star ratings directly to the image file metadata.
- **Slideshow Mode:** Press `Space` to start/stop an automatic slideshow (advances every 2 seconds).
- **Quick Deletion:** Press `d` to immediately move the current image to the macOS Trash.
- **Film Simulations & Editing:** Apply Fujifilm-inspired film simulations and tweak exposure, contrast, etc.
- **Sidebar Navigation:** Quickly switch between recent folders and filter photos by star rating.

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

| Key | Action |
| --- | --- |
| `→` | Next Photo |
| `←` | Previous Photo |
| `1`-`5` | Apply 1-5 Star Rating |
| `Space` | Toggle Slideshow |
| `d`| Move Photo to Trash |

## Mouse Controls
- **Right-Click (Preview):** Open a context menu to quickly tag or delete the current photo.
- **Left Sidebar:** Click arrows to expand folders and filter by ratings.
- **Right Panel (Filter icon):** Adjust editing controls and film simulations.
