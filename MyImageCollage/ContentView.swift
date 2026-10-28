//
//  ContentView.swift
//  MyImageCollage
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CollageSlot: Identifiable {
    let id = UUID()
    var image: NSImage?
}

struct ContentView: View {
    private static let requiredSlots = 2

    @State private var slots: [CollageSlot] = (0..<requiredSlots).map { _ in CollageSlot() }
    @State private var collage: NSImage? = nil

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ForEach(slots) { slot in
                    if let image = slot.image {
                        Thumbnail(image: image) { remove(slot.id) }
                    } else {
                        AddZone(title: "Drop image here", compact: false) { newImages in
                            fill(slot.id, with: newImages)
                        }
                    }
                }
                AddZone(title: "Add more", compact: true) { newImages in
                    add(newImages)
                }
            }
            .frame(height: 230)

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
            } else {
                Text("Add at least two images to build a collage")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 400)
    }

    private func regenerate() {
        let images = slots.compactMap(\.image)
        guard images.count >= Self.requiredSlots else { collage = nil; return }
        collage = buildCollage(images: images)
    }

    /// Puts the first image in the given slot; any extras go to the next free slots.
    private func fill(_ id: UUID, with images: [NSImage]) {
        guard let first = images.first, let index = slots.firstIndex(where: { $0.id == id }) else { return }
        slots[index].image = first
        add(Array(images.dropFirst()))
    }

    /// Fills empty slots in order, then appends new slots for the rest.
    private func add(_ images: [NSImage]) {
        var remaining = images[...]
        for index in slots.indices where slots[index].image == nil {
            guard let next = remaining.popFirst() else { break }
            slots[index].image = next
        }
        slots.append(contentsOf: remaining.map { CollageSlot(image: $0) })
        regenerate()
    }

    /// The first two slots stay as placeholders; extra slots disappear.
    private func remove(_ id: UUID) {
        guard let index = slots.firstIndex(where: { $0.id == id }) else { return }
        if index < Self.requiredSlots {
            slots[index].image = nil
        } else {
            slots.remove(at: index)
        }
        regenerate()
    }

    private func buildCollage(images: [NSImage]) -> NSImage? {
        let spacer: CGFloat = 16
        let maxSide: CGFloat = 1200

        // Normalize each image to same height
        let targetH = min(images.map { $0.size.height }.min() ?? maxSide, maxSide)
        let scaled = images.map { img -> NSImage in
            let scale = targetH / img.size.height
            return img.resized(to: NSSize(width: img.size.width * scale, height: targetH))
        }

        let totalW = scaled.map(\.size.width).reduce(0, +) + spacer * CGFloat(scaled.count + 1)
        let totalH = targetH + spacer * 2
        let size = NSSize(width: totalW, height: totalH)

        let result = NSImage(size: size)
        result.lockFocus()
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()

        var x: CGFloat = spacer
        for img in scaled {
            img.draw(in: NSRect(x: x, y: spacer, width: img.size.width, height: img.size.height))
            x += img.size.width + spacer
        }
        result.unlockFocus()
        return result
    }

    private func saveCollage(_ image: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        panel.nameFieldStringValue = "\(dateFormatter.string(from: Date()))-collage.png"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: url)
        }
    }
}

// MARK: - Thumbnail

struct Thumbnail: View {
    let image: NSImage
    var onRemove: () -> Void

    var body: some View {
        Color.clear
            .overlay {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()
            .cornerRadius(10)
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .padding(6)
            }
    }
}

// MARK: - Add Zone

struct AddZone: View {
    var title: String
    var compact: Bool
    var onAdd: ([NSImage]) -> Void

    @State private var isTargeted = false

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color(nsColor: .windowBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Choose…") { pickFiles() }
                        .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: compact ? 160 : .infinity)
            .frame(height: 220)
            .onDrop(of: [.fileURL, .image], isTargeted: $isTargeted) { providers in
                handleDrop(providers)
            }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        // Load in drop order, then deliver the batch once all have finished.
        let group = DispatchGroup()
        var results = [NSImage?](repeating: nil, count: providers.count)

        for (index, provider) in providers.enumerated() {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                accepted = true
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    let url: URL?
                    if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let u = item as? URL {
                        url = u
                    } else {
                        url = nil
                    }
                    let img = url.flatMap { NSImage(contentsOf: $0) }
                    DispatchQueue.main.async { results[index] = img; group.leave() }
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                accepted = true
                group.enter()
                _ = provider.loadObject(ofClass: NSImage.self) { obj, _ in
                    DispatchQueue.main.async { results[index] = obj as? NSImage; group.leave() }
                }
            }
        }

        group.notify(queue: .main) {
            let images = results.compactMap { $0 }
            if !images.isEmpty { onAdd(images) }
        }
        return accepted
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.begin { response in
            guard response == .OK else { return }
            let images = panel.urls.compactMap { NSImage(contentsOf: $0) }
            if !images.isEmpty { onAdd(images) }
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
