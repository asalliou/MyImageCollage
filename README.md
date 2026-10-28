# MyImageCollage

A small macOS app, built with SwiftUI, that combines two or more images into a single collage you can save as a PNG.

## Features

- Drag and drop images onto the two placeholders, or click **Choose…** to pick files.
- Use the **Add more** area to drop or choose several images at once and extend the collage beyond two.
- Switch between a **Horizontal** layout (images side by side, same height) and a **Vertical** layout (images stacked, same width).
- Live preview of the collage, with **Save Collage…** to export it as a PNG.

## Usage

1. Add at least two images. Dropped images fill the empty placeholders first, then extra slots are appended.
2. Pick Horizontal or Vertical.
3. Click **Save Collage…** and choose where to write the PNG.

Use the ✕ on a thumbnail to remove an image. Removing one of the first two empties its placeholder; removing an extra image deletes its slot.

## Build

Requires Xcode and macOS.

```
xcodebuild -scheme MyImageCollage -configuration Release -destination 'platform=macOS' build
```

Or open `MyImageCollage.xcodeproj` in Xcode and run the `MyImageCollage` scheme.

The bundle identifier is `com.asalliou.MyImageCollage`. Release builds are ad-hoc signed, so on first launch you may need to right-click the app and choose **Open**.
