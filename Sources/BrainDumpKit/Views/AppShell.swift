import SwiftData
import SwiftUI

public struct AppShell: View {
    @Environment(\.modelContext) private var context
    @State private var state: AppState?

    static let sidebarWidth: CGFloat = 256
    // Left column (Top3 + BrainDump) >= 360, schedule >= 480, gutter 24,
    // canvas horizontal padding 64 * 2.
    static let canvasMin: CGFloat = 64 + 360 + 24 + 480 + 64
    static let sidebarThreshold: CGFloat = canvasMin + sidebarWidth

    public init() {}

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
            if state == nil { state = AppState(context: context) }
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
            .padding(.top, 28)
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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                switch state.selectedDestination {
                case .today:
                    DateHeader(state: state)
                        .padding(.horizontal, 64)
                        .padding(.bottom, 48)
                    DayView(state: state)
                        .id(state.dataGeneration)
                        .padding(.horizontal, 64)
                        .padding(.bottom, 48)
                case .tasks:
                    TasksScreen()
                        .padding(.horizontal, 64)
                        .padding(.top, 24)
                        .padding(.bottom, 48)
                case .backlog:
                    BacklogScreen(state: state)
                        .padding(.horizontal, 64)
                        .padding(.top, 24)
                        .padding(.bottom, 48)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var topBar: some View {
        HStack(spacing: 0) {
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
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
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
