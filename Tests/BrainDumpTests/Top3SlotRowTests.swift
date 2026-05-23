import AppKit
import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import BrainDumpKit

/// Encapsulating each Top3 slot in its own `View` struct (with local
/// `isTargeted` state) is what keeps drag-and-drop smooth: when the cursor
/// crosses one slot, only that slot's body re-evaluates, instead of the
/// whole Top3Section re-creating every slot's `.dropDestination` /
/// `.draggable` modifier. These tests pin the new struct's surface and
/// verify it renders in both filled and empty states.
@MainActor
struct Top3SlotRowTests {
    @Test
    func filledSlotRendersTaskTitle() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let item = TaskService(context: context).addBrainDumpItem(
            title: "Finalize Manuscript Revision",
            on: day
        )
        try TaskService(context: context).escalate(item, on: day)

        let view = Top3SlotRow(
            day: day,
            isReadOnly: false,
            index: 0,
            item: item,
            isHovered: false,
            isExpanded: false,
            openDetail: nil,
            onHoverChange: { _ in },
            onTapToggle: {}
        )
        .environment(\.modelContext, context)

        renderSnapshot(view, size: NSSize(width: 360, height: 80), filename: "top3-slot-filled.png")
    }

    @Test
    func emptySlotRendersPriorityLabel() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))

        let view = Top3SlotRow(
            day: day,
            isReadOnly: false,
            index: 1,
            item: nil,
            isHovered: false,
            isExpanded: false,
            openDetail: nil,
            onHoverChange: { _ in },
            onTapToggle: {}
        )
        .environment(\.modelContext, context)

        renderSnapshot(view, size: NSSize(width: 360, height: 80), filename: "top3-slot-empty.png")
    }

    private func renderSnapshot<V: View>(_ view: V, size: NSSize, filename: String) {
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.layoutIfNeeded()
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            Issue.record("bitmapImageRepForCachingDisplay returned nil for \(filename)")
            return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            Issue.record("PNG encoding failed for \(filename)")
            return
        }
        let outDir = URL(fileURLWithPath: "/tmp/braindump-shots")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        do {
            try data.write(to: outDir.appendingPathComponent(filename))
        } catch {
            Issue.record("write failed: \(error)")
        }
    }
}
