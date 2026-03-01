import PortalCore
import SwiftUI

struct PortalPopoverView: View {
    @ObservedObject var viewModel: PortalViewModel
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 8)
            Divider()
                .padding(.horizontal, 12)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

            if let lastActionSuccess = viewModel.lastActionSuccess {
                Divider()
                    .padding(.horizontal, 12)
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(nsColor: .systemGreen))
                    Text(lastActionSuccess)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .transition(.opacity)
            }

            if let lastActionError = viewModel.lastActionError {
                Divider()
                    .padding(.horizontal, 12)
                Text(lastActionError)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(nsColor: .systemRed))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.easeOut(duration: 0.18), value: viewModel.lastActionSuccess)
    }

    private var header: some View {
        HStack {
            Text("Portal")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button("Quit") {
                onQuit()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            LoadingStateView()
        case .empty:
            EmptyServersStateView()
        case let .softError(message):
            MessageStateView(message: message)
        case let .ready(servers):
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(servers.enumerated()), id: \.element.id) { index, server in
                        ServerRowView(
                            server: server,
                            isBusy: viewModel.busyServerIDs.contains(server.id),
                            onKill: { viewModel.kill(server) },
                            onOpen: { viewModel.open(server) }
                        )

                        if index < servers.count - 1 {
                            Divider()
                                .padding(.leading, 38)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.never)
        }
    }
}

private struct ServerRowView: View {
    let server: ServerRecord
    let isBusy: Bool
    let onKill: () -> Void
    let onOpen: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(nsColor: .systemGreen))
                        .frame(width: 7, height: 7)
                    Text(server.appName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                Text(server.subtitleDisplayText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 15)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 6) {
                    NativeActionButton(
                        title: "Kill",
                        kind: .destructive,
                        isDisabled: isBusy,
                        action: onKill
                    )
                        .disabled(isBusy)

                    NativeActionButton(
                        title: "Open",
                        kind: .neutral,
                        isDisabled: isBusy,
                        action: onOpen
                    )
                        .disabled(isBusy)
                }

                Text(DurationFormatter.string(since: server.startedAt))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    isHovered || isBusy
                        ? Color(nsColor: .selectedContentBackgroundColor).opacity(isBusy ? 0.18 : 0.12)
                        : .clear
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct EmptyServersStateView: View {
    var body: some View {
        VStack(spacing: 10) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
                    .frame(width: 40, height: 40)

                Image(systemName: "bolt.slash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 3) {
                Text("No local servers")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Start a local app and it will appear here.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 26)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MessageStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Text(message)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LoadingStateView: View {
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Scanning local servers…")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NativeActionButton: View {
    enum Kind {
        case neutral
        case destructive
    }

    let title: String
    let kind: Kind
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(title, action: action)
            .buttonStyle(NativeMenuActionButtonStyle(kind: kind, isHovered: isHovered))
            .onHover { hovering in
                isHovered = hovering
            }
            .opacity(isDisabled ? 0.55 : 1)
    }
}

private struct NativeMenuActionButtonStyle: ButtonStyle {
    let kind: NativeActionButton.Kind
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        let isActive = isHovered || configuration.isPressed
        let palette = palette(isActive: isActive, isPressed: configuration.isPressed)

        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(palette.foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(palette.background)
            )
            .overlay(
                Capsule()
                    .stroke(palette.border, lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
    }

    private func palette(isActive: Bool, isPressed: Bool) -> (background: Color, foreground: Color, border: Color) {
        switch kind {
        case .neutral:
            let background = Color(nsColor: .controlBackgroundColor).opacity(isActive ? 0.92 : 0.68)
            let foreground = Color.primary.opacity(isPressed ? 0.8 : 1)
            let border = Color(nsColor: .separatorColor).opacity(isActive ? 0.62 : 0.45)
            return (background, foreground, border)

        case .destructive:
            let background = Color(nsColor: .systemRed).opacity(isActive ? 0.18 : 0.1)
            let foreground = Color(nsColor: .systemRed).opacity(isPressed ? 0.8 : 1)
            let border = Color(nsColor: .systemRed).opacity(isActive ? 0.28 : 0.18)
            return (background, foreground, border)
        }
    }
}
