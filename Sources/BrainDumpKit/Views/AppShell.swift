import SwiftData
import SwiftUI

public struct AppShell: View {
    @Environment(\.modelContext) private var context
    @State private var state: AppState?

    private let storeRecovery: StoreRecovery
    private let initialDestination: SidebarDestination?
    @State private var showRecoveryNotice: Bool

    static let sidebarWidth: CGFloat = 256
    // Left column (Top3 + BrainDump) >= 360, schedule >= 480, gutter 24,
    // canvas horizontal padding 64 * 2.
    static let canvasMin: CGFloat = 64 + 360 + 24 + 480 + 64
    static let sidebarThreshold: CGFloat = canvasMin + sidebarWidth

    // Top inset shared by the sidebar title and every tab's content, so each
    // tab's first row lines up with the "Daily Timebox Planner" title.
    static let contentTopInset: CGFloat = 28
    // Reminders-style toolbar metrics for the floating sidebar toggle. With
    // `.windowStyle(.hiddenTitleBar)` the macOS traffic-lights keep their
    // standard frames — close/min/zoom span x≈9–69, vertically centered at
    // y≈16 — so the toggle drops just to their right on the same line.
    static let toolbarLeadingInset: CGFloat = 76
    // 32pt toggle anchored at the top edge centers its glyph at y≈16, matching
    // the traffic-light line. Kept explicit so it can be nudged independently.
    static let toolbarTopInset: CGFloat = 0

    public init(
        storeRecovery: StoreRecovery = .normal,
        initialDestination: SidebarDestination? = nil
    ) {
        self.storeRecovery = storeRecovery
        self.initialDestination = initialDestination
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
                            Sidebar(state: state)
                                .transition(.move(edge: .leading))
                        }
                        MainCanvas(state: state)
                    }
                    .animation(.easeInOut(duration: 0.18), value: effectivelyVisible)
                    .background(Theme.Palette.surface)
                    // The sidebar toggle floats on the traffic-light line at a
                    // fixed window position (Reminders-style) — outside the
                    // sidebar/canvas split, so it stays put when the sidebar
                    // shows/hides and never reserves space in the content.
                    // `.hiddenTitleBar` keeps a full-size background but insets
                    // layout below the title-bar band; ignoring the top safe
                    // area lifts the toggle into that band, beside the lights.
                    .overlay(alignment: .topLeading) {
                        SidebarToggle(state: state)
                            .padding(.leading, Self.toolbarLeadingInset)
                            .padding(.top, Self.toolbarTopInset)
                            .ignoresSafeArea(.container, edges: .top)
                    }
                }
                .frame(minWidth: Self.canvasMin, minHeight: 760)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Palette.surface)
            }
        }
        .onAppear {
            if state == nil {
                let created = AppState(context: context)
                if let initialDestination { created.selectedDestination = initialDestination }
                state = created
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
    @State private var showSettings: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Timebox Planner")
                    .font(Theme.Font.headlineSmall)
                    .tracking(0.5)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
            }
            .padding(.horizontal, 24)
            .padding(.top, AppShell.contentTopInset)
            .padding(.bottom, 40)

            VStack(alignment: .leading, spacing: 6) {
                NavItem(
                    icon: "calendar.day.timeline.left", label: "Today", destination: .today,
                    state: state)
                NavItem(
                    icon: "list.bullet.clipboard", label: "Tasks", destination: .tasks, state: state
                )
                NavItem(icon: "tray.full", label: "Backlog", destination: .backlog, state: state)
            }
            .padding(.horizontal, 16)

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
                            .font(Theme.Font.labelMd)
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
            SettingsSheet(state: state, dismiss: { showSettings = false })
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
                    .font(Theme.Font.labelMd)
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

    // Today fills the window: the date + wise-saying header sits at the top,
    // its top lined up with the sidebar's "Daily Timebox Planner" title, and
    // DayView takes all the remaining height, running its own internal scroll
    // regions (brain dump + schedule). The sidebar toggle lives in AppShell's
    // window overlay (traffic-light line), so nothing reserves space above the
    // header here.
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

    // Tasks / Backlog scroll the whole page. The header starts at the shared
    // top inset so its title lines up with the sidebar title; the toggle no
    // longer occupies a reserved row (it floats in AppShell's overlay).
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
                .frame(width: 32, height: 32)
                .background(Theme.Palette.surfaceContainerLow.opacity(0.0001))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(state.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
        .keyboardShortcut("b", modifiers: [.command])
    }
}

private struct DateHeader: View {
    @Bindable var state: AppState

    @State private var hoveringDate: Bool = false
    @State private var showDatePicker: Bool = false

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        return f
    }()

    private var formattedDate: String {
        Self.formatter.string(from: state.selectedDate)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(formattedDate)
                        .font(Theme.Font.headlineLg)
                        .tracking(-0.3)
                        .foregroundStyle(Theme.Palette.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.Palette.primaryContainer)
                        .opacity(hoveringDate ? 1 : 0)
                }
                .contentShape(Rectangle())
                .onTapGesture { showDatePicker = true }
                .onHover { hoveringDate = $0 }
                .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                    MonthCalendarView(state: state, dismiss: { showDatePicker = false })
                }

                Text(
                    "\u{201C}\(state.currentWiseSaying.quote)\u{201D}\u{00A0}— \(state.currentWiseSaying.author)"
                )
                .font(Theme.Font.bodyMdItalic)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 640, alignment: .leading)
            }
            Spacer()
            WorkspaceAvatar()
        }
    }
}

private struct WorkspaceAvatar: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Rectangle()
                    .fill(Theme.Palette.surfaceContainerHigh)
                Text("RF")
                    .font(Theme.Font.labelMd)
                    .tracking(0.5)
                    .foregroundStyle(Theme.Palette.primary)
            }
            .frame(width: 40, height: 40)
        }
    }
}
