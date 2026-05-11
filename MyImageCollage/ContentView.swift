//
//  ContentView.swift
//  MyImageCollage
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var images: [NSImage?] = [nil, nil]
    @State private var collage: NSImage? = nil
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { index in
                    DropZone(image: $images[index]) {
                        regenerate()
                    }
                }
            }

            if let collage {
                Divider()
                Image(nsImage: collage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 400)
                    .cornerRadius(6)
                    .shadow(radius: 4)

                Button("Save Collage…") {
                    saveCollage(collage)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 400)
    }

    private func regenerate() {
        let loaded = images.compactMap { $0 }
        guard loaded.count == 2 else { collage = nil; return }
        collage = buildCollage(images: loaded)
    }

    private func buildCollage(images: [NSImage]) -> NSImage? {
        let gap: CGFloat = 2
        let maxSide: CGFloat = 1200

        // Normalize each image to same height
        let targetH = min(images.map { $0.size.height }.min() ?? maxSide, maxSide)
        let scaled = images.map { img -> NSImage in
            let scale = targetH / img.size.height
            return img.resized(to: NSSize(width: img.size.width * scale, height: targetH))
        }

        let totalW = scaled.map(\.size.width).reduce(0, +) + gap * CGFloat(scaled.count - 1)
        let totalH = targetH
        let size = NSSize(width: totalW, height: totalH)

        let result = NSImage(size: size)
        result.lockFocus()
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()

        var x: CGFloat = 0
        for img in scaled {
            img.draw(in: NSRect(x: x, y: 0, width: img.size.width, height: img.size.height))
            x += img.size.width + gap
        }
        result.unlockFocus()
        return result
    }

    private func saveCollage(_ image: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "collage.png"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: url)
        }
    }
}

// MARK: - Drop Zone

struct DropZone: View {
    @Binding var image: NSImage?
    var onChanged: () -> Void

    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                            style: StrokeStyle(lineWidth: 2, dash: image == nil ? [6, 4] : [])
                        )
                )

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 260, height: 220)
                    .clipped()
                    .cornerRadius(10)
                    .overlay(alignment: .topTrailing) {
                        Button {
                            self.image = nil
                            onChanged()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                    }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Drop image here")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Choose…") { pickFile() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .frame(width: 260, height: 220)
        .onDrop(of: [.fileURL, .image], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let u = item as? URL {
                    url = u
                } else {
                    url = nil
                }
                if let url, let img = NSImage(contentsOf: url) {
                    DispatchQueue.main.async { self.image = img; onChanged() }
                }
            }
            return true
        }

        if provider.canLoadObject(ofClass: NSImage.self) {
            provider.loadObject(ofClass: NSImage.self) { obj, _ in
                if let img = obj as? NSImage {
                    DispatchQueue.main.async { self.image = img; onChanged() }
                }
            }
            return true
        }

        return false
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url,
                  let img = NSImage(contentsOf: url) else { return }
            self.image = img
            onChanged()
        }
    }
}

// MARK: - NSImage resize helper

private extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        let result = NSImage(size: newSize)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: newSize),
             from: NSRect(origin: .zero, size: size),
             operation: .copy,
             fraction: 1)
        result.unlockFocus()
        return result
    }
}

#Preview {
    ContentView()
}
