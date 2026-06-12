import SwiftUI

/// Manage iCal subscriptions: list feeds, add/remove, toggle, recolor, refresh.
public struct CalendarSettingsView: View {
    @Bindable var state: AppState

    @State private var newName: String = ""
    @State private var newURL: String = ""
    @State private var newColor: Int = 0
    @State private var pendingDeletion: CalendarFeed?

    public init(state: AppState) { self.state = state }

    private var calendar: CalendarService { state.calendar }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                intro
                if !calendar.feeds.isEmpty { feedList }
                Rectangle().fill(Theme.Palette.outlineVariant).frame(height: 1)
                addForm
                Rectangle().fill(Theme.Palette.outlineVariant).frame(height: 1)
                refreshRow
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(
            "Remove subscription?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { feed in
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Remove", role: .destructive) {
                calendar.removeFeed(id: feed.id)
                pendingDeletion = nil
            }
        } message: { feed in
            Text("Remove \u{201C}\(feed.name.isEmpty ? "this calendar" : feed.name)\u{201D} and all of its events from your schedule? This doesn't change the calendar itself, and you can re-add it anytime.")
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CALENDAR SUBSCRIPTIONS")
                .font(Theme.Font.sectionLabelHeavy).tracking(1.4)
                .foregroundStyle(Theme.Palette.onSurface)
            Text("Subscribe to external calendars by iCal URL (e.g. Google Calendar's \u{201C}Secret address in iCal format\u{201D}). Events appear in the Schedule as read-only, busy blocks.")
                .font(Theme.Font.bodyMd).foregroundStyle(Theme.Palette.onSurfaceVariant)
        }
    }

    private var feedList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(calendar.feeds) { feed in
                HStack(spacing: 12) {
                    Circle().fill(Theme.BlockPalette.color(at: feed.colorIndex)).frame(width: 16, height: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feed.name.isEmpty ? "(unnamed)" : feed.name)
                            .font(Theme.Font.labelMd).foregroundStyle(Theme.Palette.onSurface)
                        Text(feed.urlString).font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.onSurfaceVariant).lineLimit(1)
                        if let err = calendar.feedErrors[feed.id] {
                            Text(err).font(Theme.Font.caption).foregroundStyle(Theme.Palette.secondary)
                        }
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { feed.isEnabled },
                        set: { enabled in Task { await calendar.setFeedEnabled(id: feed.id, enabled) } }))
                        .labelsHidden()
                    Button(action: { pendingDeletion = feed }) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.Palette.secondary)
                            .frame(width: 28, height: 28).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).help("Remove subscription")
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADD SUBSCRIPTION").font(Theme.Font.sectionLabelHeavy).tracking(1.4)
                .foregroundStyle(Theme.Palette.onSurface)
            TextField("Name (e.g. Work)", text: $newName).textFieldStyle(.roundedBorder)
            TextField("https://calendar.google.com/calendar/ical/.../basic.ics", text: $newURL)
                .textFieldStyle(.roundedBorder)
            ColorSwatchRow(selected: $newColor)
            Button(action: addFeed) {
                Text("Add Subscription")
                    .font(Theme.Font.labelMd).padding(.horizontal, 18).frame(height: 34)
                    .foregroundStyle(Theme.Palette.onPrimary).background(Theme.Palette.primary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(URL(string: newURL.trimmingCharacters(in: .whitespaces))?.scheme == nil)
        }
    }

    private var refreshRow: some View {
        HStack(spacing: 12) {
            Button(action: { Task { await calendar.refresh() } }) {
                Text(calendar.isRefreshing ? "Refreshing…" : "Refresh Now")
                    .font(Theme.Font.labelMd).padding(.horizontal, 18).frame(height: 34)
                    .foregroundStyle(Theme.Palette.primary)
                    .overlay(Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).disabled(calendar.isRefreshing)
            if let last = calendar.lastRefresh {
                Text("Last updated \(last.formatted(date: .abbreviated, time: .shortened))")
                    .font(Theme.Font.caption).foregroundStyle(Theme.Palette.onSurfaceVariant)
            }
            Spacer()
        }
    }

    private func addFeed() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        let url = newURL.trimmingCharacters(in: .whitespaces)
        guard URL(string: url)?.scheme != nil else { return }
        calendar.addFeed(name: name.isEmpty ? "Calendar" : name, urlString: url, colorIndex: newColor)
        newName = ""; newURL = ""; newColor = 0
        Task { await calendar.refresh() }
    }
}
