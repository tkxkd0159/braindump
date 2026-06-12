import AppKit
import Combine
import SwiftData
import SwiftUI

public struct AppShell: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var state: AppState?

    // Periodic safety-net so an open window catches a date change even if the
    // precise `NSCalendarDayChanged` notification is missed (e.g. coalesced
    // across system sleep). `refreshCurrentDate()` is a cheap no-op until the
    // local day actually advances, so a short interval is harmless.
    @State private var dateRefreshTimer =
        Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private let storeRecovery: StoreRecovery
    private let initialDestination: SidebarDestination?
    private let updateModel: AppUpdateModel
    private let notifier: UserNotifying
    @State private var showRecoveryNotice: Bool

    static let sidebarWidth: CGFloat = 256
    // Left column (Top3 + BrainDump) >= 360, schedule >= 480, gutter 24,
    // canvas horizontal padding 64 * 2.
    static let canvasMin: CGFloat = 64 + 360 + 24 + 480 + 64
    static let sidebarThreshold: CGFloat = canvasMin + sidebarWidth

    // Top inset shared by the sidebar's first nav item and every tab's content,
    // so the sidebar navigation lines up with the canvas's date header.
    static let contentTopInset: CGFloat = 28

    // Sidebar-toggle metrics. The toggle drops just right of the macOS
    // traffic-lights (which span x≈9–69) on the same title-bar line, so it
    // clears them and stays left of `WindowSizing.titleBarControlsInset` (the
    // zoom-exclusion boundary).
    static let sidebarToggleLeadingInset: CGFloat = 76
    static let sidebarToggleSize: CGFloat = 32

    public init(
        storeRecovery: StoreRecovery = .normal,
        initialDestination: SidebarDestination? = nil,
        updateModel: AppUpdateModel = AppUpdateModel(),
        notifier: UserNotifying = NoopUserNotifying()
    ) {
        self.storeRecovery = storeRecovery
        self.initialDestination = initialDestination
        self.updateModel = updateModel
        self.notifier = notifier
        _showRecoveryNotice = State(initialValue: storeRecovery.isRecovery)
    }

    public var body: some View {
        Group {
            if let state {
                GeometryReader { proxy in
                    // Reminders-style auto-collapse: when the window can't fit
                    // sidebar + canvas, hide the sidebar without touching the
                    // user's preference, so it reappears when the window grows.
                    let canFit = proxy.size.width >= Self.sidebarThreshold
                    let effectivelyVisible = state.isSidebarVisible && canFit
                    HStack(spacing: 0) {
                        if effectivelyVisible {
                            Sidebar(state: state, updateModel: updateModel)
                                .transition(.move(edge: .leading))
                        }
                        MainCanvas(state: state)
                    }
                    .animation(.easeInOut(duration: 0.18), value: effectivelyVisible)
                    .background(Theme.Palette.surface)
                    // The sidebar toggle floats at a fixed window position on the
                    // traffic-light line (macOS Notes-style): it sits outside the
                    // sidebar/canvas split, so it holds its place while the sidebar
                    // shows/hides — over the sidebar's surface when shown ("in the
                    // sidebar section"), over the canvas when hidden. Ignoring the
                    // top safe area lifts it into the title-bar band, level with the
                    // traffic-lights. (The sidebar has no heading for it to overlap
                    // in fullscreen — the issue that once pushed it into the canvas.)
                    .overlay(alignment: .topLeading) {
                        SidebarToggle(state: state)
                            .padding(.leading, Self.sidebarToggleLeadingInset)
                            .ignoresSafeArea(.container, edges: .top)
                    }
                }
                .frame(minWidth: Self.canvasMin, minHeight: 760)
                // Keep the displayed day in sync with the wall clock while the
                // window stays open: at the exact day boundary
                // (NSCalendarDayChanged), when the app is reactivated (e.g.
                // after waking), and on a periodic fallback tick.
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                    state.refreshCurrentDate()
                    state.refreshAllNotifications()
                }
                .onReceive(dateRefreshTimer) { _ in
                    state.refreshCurrentDate()
                    state.refreshAllNotifications()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        state.refreshCurrentDate()
                        state.refreshAllNotifications()
                    }
                }
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Palette.surface)
            }
        }
        .onAppear {
            if state == nil {
                let created = AppState(context: context, notifier: notifier)
                if let initialDestination { created.selectedDestination = initialDestination }
                state = created
                // First reconcile: arms any reminders/digest already configured.
                // Requests no permission unless something is actually scheduled.
                created.refreshAllNotifications()
            }
        }
        // Refresh calendar subscriptions once `state` exists, then every 30
        // minutes while the window is open. The initial refresh paints over the
        // disk-cached events already shown. Re-runs when state flips nil→set.
        .task(id: state == nil) {
            guard let state else { return }
            await state.calendar.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
                if Task.isCancelled { break }
                await state.calendar.refresh()
            }
        }
        .alert("Data could not be opened", isPresented: $showRecoveryNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(storeRecovery.userMessage ?? "")
        }
    }
}

private struct Sidebar: View {
    @Bindable var state: AppState
    let updateModel: AppUpdateModel
    @State private var showSettings: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Order matches `SidebarDestination.allCases`, which backs the
            // ⌘1/⌘2/⌘3 shortcuts (see `AppState.selectSidebarItem`). Keep in sync.
            VStack(alignment: .leading, spacing: 6) {
                NavItem(
                    icon: "calendar.day.timeline.left", label: "Today", destination: .today,
                    state: state)
                    .help("Today (⌘1)")
                NavItem(
                    icon: "list.bullet.clipboard", label: "Tasks", destination: .tasks, state: state
                )
                .help("Tasks (⌘2)")
                NavItem(icon: "tray.full", label: "Backlog", destination: .backlog, state: state)
                    .help("Backlog (⌘3)")
            }
            .padding(.horizontal, 16)
            .padding(.top, AppShell.contentTopInset)

            Spacer()

            Rectangle()
                .fill(Theme.Palette.outlineVariant)
                .frame(height: 1)
                .padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 6) {
                Button(action: { showSettings = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .regular))
                            .frame(width: 22)
                        Text("Settings")
                            .font(Theme.Font.navLabel)
                            .tracking(0.7)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .frame(width: 256)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.Palette.surfaceContainerLow)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Theme.Palette.outlineVariant)
                .frame(width: 1)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(state: state, updateModel: updateModel, dismiss: { showSettings = false })
        }
    }
}

private struct NavItem: View {
    let icon: String
    let label: String
    let destination: SidebarDestination?
    @Bindable var state: AppState

    @State private var hovered: Bool = false

    private var isActive: Bool {
        guard let destination else { return false }
        return state.selectedDestination == destination
    }

    var body: some View {
        Button(action: {
            guard let destination else { return }
            state.selectedDestination = destination
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: isActive ? .semibold : .regular))
                    .frame(width: 22)
                Text(label)
                    .font(Theme.Font.navLabel)
                    .tracking(0.7)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isActive ? Theme.Palette.primary : Theme.Palette.onSurfaceVariant)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack(alignment: .trailing) {
                    if isActive {
                        Theme.Palette.surfaceContainerHigh
                        Rectangle()
                            .fill(Theme.Palette.primary)
                            .frame(width: 4)
                    } else if hovered {
                        Theme.Palette.surfaceContainerHigh.opacity(0.6)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(destination == nil)
        .onHover { hovered = $0 }
    }
}

private struct MainCanvas: View {
    @Bindable var state: AppState

    var body: some View {
        Group {
            switch state.selectedDestination {
            case .today:
                todayLayout
            case .tasks:
                scrolling {
                    TasksScreen()
                        .padding(.horizontal, 64)
                        .padding(.bottom, 48)
                }
            case .backlog:
                scrolling {
                    BacklogScreen(state: state)
                        .padding(.horizontal, 64)
                        .padding(.bottom, 48)
                }
            }
        }
        // ⌘1/⌘2/⌘3 destination shortcuts. Hosted here (always rendered) rather
        // than in the Sidebar, which is torn out of the hierarchy — taking its
        // key equivalents with it — when collapsed or hidden.
        .background { NavigationShortcuts(state: state) }
    }

    private var todayLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            DateHeader(state: state)
                .padding(.horizontal, 64)
                .padding(.top, AppShell.contentTopInset)
                .padding(.bottom, 28)
            DayView(state: state)
                .id(state.dataGeneration)
                .padding(.horizontal, 64)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func scrolling<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            content()
                .padding(.top, AppShell.contentTopInset)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SidebarToggle: View {
    @Bindable var state: AppState

    var body: some View {
        Button(action: { state.toggleSidebar() }) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
                .frame(width: AppShell.sidebarToggleSize, height: AppShell.sidebarToggleSize)
                .background(Theme.Palette.surfaceContainerLow.opacity(0.0001))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(state.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
        .keyboardShortcut("b", modifiers: [.command])
    }
}

/// Invisible key-equivalent buttons backing ⌘1/⌘2/⌘3 (Today / Tasks / Backlog).
/// Indices map through `AppState.selectSidebarItem(at:)`. Zero-size and fully
/// transparent, so they register window shortcuts without affecting layout or
/// intercepting clicks; `accessibilityHidden` keeps them out of VoiceOver.
private struct NavigationShortcuts: View {
    @Bindable var state: AppState

    var body: some View {
        ZStack {
            Button("Today") { state.selectSidebarItem(at: 0) }
                .keyboardShortcut("1", modifiers: [.command])
            Button("Tasks") { state.selectSidebarItem(at: 1) }
                .keyboardShortcut("2", modifiers: [.command])
            Button("Backlog") { state.selectSidebarItem(at: 2) }
                .keyboardShortcut("3", modifiers: [.command])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }
}

struct DateHeader: View {
    @Bindable var state: AppState

    @State private var hoveringDate: Bool = false
    @State private var showDatePicker: Bool = false

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d, yyyy"
        return f
    }()

    /// Fixed width reserved for the date so the trailing nav arrows never shift
    /// as the date string changes day-to-day. Sized (with slack) to the widest
    /// abbreviated date at headlineLg; a longer one truncates rather than
    /// pushing the arrows. Verified by `captureDateHeaderButtonAlignment`.
    private static let dateBoxWidth: CGFloat = 300

    private var formattedDate: String {
        Self.formatter.string(from: state.selectedDate)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Button { showDatePicker = true } label: {
                        DateLabel(text: formattedDate, isHovered: hoveringDate)
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in
                        hoveringDate = inside
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    .onDisappear {
                        // Pop only if we pushed, so unmounting mid-hover (e.g.
                        // switching sidebar tab) can't leave the hand cursor stuck.
                        if hoveringDate { NSCursor.pop(); hoveringDate = false }
                    }
                    .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                        MonthCalendarView(state: state, dismiss: { showDatePicker = false })
                    }
                    .frame(width: Self.dateBoxWidth, alignment: .leading)

                    DayStepButton(systemName: "chevron.left", help: "Previous day", isDimmed: false) {
                        state.goToPreviousDay()
                    }
                    DayStepButton(systemName: "chevron.right", help: "Next day", isDimmed: state.isToday) {
                        state.goToNextDay()
                    }
                    .disabled(state.isToday)
                }
                .padding(.leading, -8)  // cancel DateLabel's pill inset so the date stays flush-left

                Text(
                    "\u{201C}\(state.currentWiseSaying.quote)\u{201D}\u{00A0}— \(state.currentWiseSaying.author)"
                )
                .font(Theme.Font.bodyMdItalic)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 640, alignment: .leading)
            }
        }
    }
}

/// The date text with an injectable hover state so the pill is renderable in a
/// static snapshot (mirrors `Top3Section`'s `isHovered` parameter pattern).
struct DateLabel: View {
    let text: String
    var isHovered: Bool = false

    var body: some View {
        Text(text)
            .font(Theme.Font.headlineLg)
            .tracking(-0.3)
            .lineLimit(1)
            .foregroundStyle(Theme.Palette.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.Palette.primary.opacity(isHovered ? 0.07 : 0))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// A borderless chevron step button matching MonthCalendarView's nav style,
/// with a matching hover highlight. `isDimmed` greys it out (the next-day
/// button at today, which is also `.disabled`).
private struct DayStepButton: View {
    let systemName: String
    let help: String
    let isDimmed: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isDimmed ? Theme.Palette.outline : Theme.Palette.primary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.Palette.primary.opacity(hovering && !isDimmed ? 0.07 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering = $0 }
    }
}
