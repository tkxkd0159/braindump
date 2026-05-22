import SwiftUI
import SwiftData

public struct AppShell: View {
    @Environment(\.modelContext) private var context
    @State private var state: AppState?

    public init() {}

    public var body: some View {
        Group {
            if let state {
                HStack(spacing: 0) {
                    Sidebar(state: state)
                    MainCanvas(state: state)
                }
                .background(Theme.Palette.surface)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Deep Work Planner")
                    .font(Theme.Font.headlineMd)
                    .foregroundStyle(Theme.Palette.primary)
                Text("Research Fellow")
                    .font(Theme.Font.labelMd)
                    .tracking(0.5)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 40)

            VStack(alignment: .leading, spacing: 6) {
                NavItem(icon: "calendar.day.timeline.left", label: "Today", destination: .today, state: state)
                NavItem(icon: "list.bullet.clipboard", label: "Tasks", destination: .tasks, state: state)
                NavItem(icon: "tray.full", label: "Backlog", destination: .backlog, state: state)
            }
            .padding(.horizontal, 16)

            Spacer()

            Rectangle()
                .fill(Theme.Palette.outlineVariant)
                .frame(height: 1)
                .padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 6) {
                NavItem(icon: "gearshape", label: "Settings", destination: nil, state: state)
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
                switch state.selectedDestination {
                case .today:
                    DateHeader(state: state)
                        .padding(.horizontal, 64)
                        .padding(.top, 36)
                        .padding(.bottom, 48)
                    DayView(state: state)
                        .padding(.horizontal, 64)
                        .padding(.bottom, 48)
                case .tasks:
                    TasksScreen()
                        .padding(.horizontal, 64)
                        .padding(.top, 36)
                        .padding(.bottom, 48)
                case .backlog:
                    BacklogScreen(state: state)
                        .padding(.horizontal, 64)
                        .padding(.top, 36)
                        .padding(.bottom, 48)
                }
            }
            .frame(maxWidth: 1280, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

                Text("\u{201C}\(state.currentWiseSaying.quote)\u{201D} — \(state.currentWiseSaying.author)")
                    .font(Theme.Font.bodyMdItalic)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 640, alignment: .leading)
            }
            Spacer()
            CalendarAvatarBlock(state: state)
        }
    }
}

private struct CalendarAvatarBlock: View {
    @Bindable var state: AppState
    @State private var showPicker: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Button(action: { showPicker = true }) {
                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.Palette.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.clear))
            }
            .buttonStyle(.plain)
            .help("Open Calendar")
            .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                MonthCalendarView(state: state, dismiss: { showPicker = false })
            }

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

