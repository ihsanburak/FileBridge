import SwiftUI

struct ConnectionVisualizer: View {
    let connectionState: ConnectionState
    let connectionProgress: ConnectionProgress
    let activeProfile: SFTPConnectionProfile?
    let activity: ConnectionVisualizerActivity

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stageStartedAt = Date()

    private var presentation: ConnectionVisualizerPresentation {
        ConnectionVisualizerPresentation(
            state: connectionState,
            progress: connectionProgress,
            activeProfile: activeProfile
        )
    }

    var body: some View {
        VStack(spacing: 2) {
            ConnectionTopology(
                presentation: presentation,
                startedAt: stageStartedAt,
                reduceMotion: reduceMotion,
                activity: activity
            )
            ConnectionStatusLine(
                presentation: presentation,
                host: presentation.host
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: presentation)
        .task(id: presentation) {
            stageStartedAt = Date()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presentation.accessibilityDescription)
    }
}

private enum ConnectionVisualizerPresentation: Equatable {
    case offline
    case connecting(host: String)
    case sshHandshake(host: String)
    case awaitingHostTrust(host: String)
    case authenticating(host: String)
    case secure(profileName: String)
    case hostKeyMismatch(host: String, message: String)
    case failed(host: String, title: String, message: String)

    init(
        state: ConnectionState,
        progress: ConnectionProgress,
        activeProfile: SFTPConnectionProfile?
    ) {
        switch state {
        case .disconnected:
            self = .offline
        case .connecting:
            if progress == .sshHandshake {
                self = .sshHandshake(host: activeProfile?.host ?? "")
            } else {
                self = .connecting(host: activeProfile?.host ?? "")
            }
        case let .awaitingHostTrust(hostKey):
            self = .awaitingHostTrust(host: hostKey.host)
        case let .authenticating(profile):
            self = .authenticating(host: profile.host)
        case let .connected(profile):
            self = .secure(profileName: profile.name)
        case let .failed(message):
            let host = activeProfile?.host ?? ""
            if message.localizedCaseInsensitiveContains("host key changed") {
                self = .hostKeyMismatch(host: host, message: message)
            } else if message.localizedCaseInsensitiveContains("authentication") {
                self = .failed(host: host, title: "AUTHENTICATION FAILED", message: message)
            } else if message.localizedCaseInsensitiveContains("SFTP") {
                self = .failed(host: host, title: "SFTP FAILED", message: message)
            } else {
                self = .failed(host: host, title: "CONNECTION FAILED", message: message)
            }
        }
    }

    var host: String {
        switch self {
        case .offline:
            ""
        case let .secure(profileName):
            profileName
        case let .connecting(host), let .sshHandshake(host), let .awaitingHostTrust(host), let .authenticating(host):
            host
        case let .hostKeyMismatch(host, _), let .failed(host, _, _):
            host
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .offline:
            "FileBridge connection status: offline."
        case let .connecting(host):
            host.isEmpty ? "FileBridge is connecting." : "FileBridge is connecting to \(host)."
        case .sshHandshake:
            "FileBridge is negotiating the SSH handshake."
        case .awaitingHostTrust:
            "FileBridge is waiting for host key verification."
        case .authenticating:
            "FileBridge is authenticating and starting SFTP."
        case let .secure(profileName):
            "FileBridge has a secure SFTP channel to \(profileName)."
        case .hostKeyMismatch:
            "FileBridge blocked the connection because the host key changed."
        case let .failed(_, title, _):
            "FileBridge connection error: \(title)."
        }
    }

    var isConnected: Bool {
        if case .secure = self { return true }
        return false
    }

    var isError: Bool {
        switch self {
        case .hostKeyMismatch, .failed:
            true
        default:
            false
        }
    }

    var lockSymbol: String {
        switch self {
        case .awaitingHostTrust:
            "lock.open"
        case .authenticating, .secure:
            "lock.fill"
        case .hostKeyMismatch:
            "exclamationmark.triangle.fill"
        case .failed:
            "xmark.octagon.fill"
        case .offline, .connecting, .sshHandshake:
            "circle.dashed"
        }
    }
}

private struct ConnectionTopology: View {
    let presentation: ConnectionVisualizerPresentation
    let startedAt: Date
    let reduceMotion: Bool
    let activity: ConnectionVisualizerActivity

    var body: some View {
        HStack(spacing: 8) {
            PixelMacEndpoint(isActive: presentation != .offline, isError: presentation.isError)

            ConnectionTunnel(
                presentation: presentation,
                startedAt: startedAt,
                reduceMotion: reduceMotion,
                activity: activity
            )
            .frame(maxWidth: .infinity)
            .frame(height: 20)

            PixelServerEndpoint(isActive: presentation.isConnected, isError: presentation.isError)
        }
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity)
    }
}

private struct ConnectionTunnel: View {
    let presentation: ConnectionVisualizerPresentation
    let startedAt: Date
    let reduceMotion: Bool
    let activity: ConnectionVisualizerActivity

    var body: some View {
        if presentation.isConnected && activity != .idle && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { context in
                tunnel(at: context.date)
            }
        } else if isAnimated && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { context in
                tunnel(at: context.date)
            }
        } else {
            tunnel(at: startedAt)
        }
    }

    private var isAnimated: Bool {
        switch presentation {
        case .connecting, .sshHandshake, .authenticating:
            true
        default:
            false
        }
    }

    private func tunnel(at date: Date) -> some View {
        ZStack {
            PixelTunnelCanvas(
                presentation: presentation,
                elapsed: date.timeIntervalSince(startedAt),
                animatePackets: (isAnimated || (presentation.isConnected && activity != .idle)) && !reduceMotion,
                activity: activity
            )

            Image(systemName: presentation.lockSymbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(symbolColor)
                .padding(4)
                .background(.bar, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
    }

    private var symbolColor: Color {
        if presentation.isError { return .red }
        if presentation.isConnected { return .green }
        switch presentation {
        case .awaitingHostTrust:
            return .orange
        case .authenticating:
            return .accentColor
        default:
            return .secondary
        }
    }
}

private struct PixelTunnelCanvas: View {
    let presentation: ConnectionVisualizerPresentation
    let elapsed: TimeInterval
    let animatePackets: Bool
    let activity: ConnectionVisualizerActivity

    var body: some View {
        Canvas { context, size in
            let centerY = size.height / 2
            let lockGap: CGFloat = 22
            let centerX = size.width / 2
            let lineColor = tunnelColor.opacity(0.78)
            let step: CGFloat = 8

            var x: CGFloat = 0
            while x < size.width {
                if abs(x - centerX) > lockGap {
                    let rect = CGRect(x: x, y: centerY - 1, width: 4, height: 2)
                    context.fill(Path(rect), with: .color(lineColor))
                }
                x += step
            }

            if presentation.isError {
                let breakRect = CGRect(x: centerX - 4, y: centerY - 4, width: 8, height: 8)
                context.fill(Path(breakRect), with: .color(.red))
                return
            }

            guard animatePackets else { return }
            drawPackets(in: &context, size: size, centerY: centerY, centerX: centerX)
        }
    }

    private var tunnelColor: Color {
        if presentation.isConnected { return .green }
        switch presentation {
        case .connecting, .sshHandshake, .authenticating:
            return .accentColor
        case .awaitingHostTrust:
            return .orange
        default:
            return .secondary
        }
    }

    private func drawPackets(
        in context: inout GraphicsContext,
        size: CGSize,
        centerY: CGFloat,
        centerX: CGFloat
    ) {
        let period = max(elapsed.truncatingRemainder(dividingBy: 1.2), 0)
        let normalized = CGFloat(period / 1.2)
        let packetColor: Color = presentation.isConnected ? .green : .accentColor

        switch presentation {
        case .connecting:
            let packetX = 8 + (size.width - 16) * normalized
            drawPacket(in: &context, x: packetX, y: centerY, color: packetColor)
        case .sshHandshake:
            let forwardX = 8 + (size.width - 16) * normalized
            let reverseX = size.width - 8 - (size.width - 16) * normalized
            drawPacket(in: &context, x: forwardX, y: centerY - 4, color: packetColor)
            drawPacket(in: &context, x: reverseX, y: centerY + 4, color: packetColor)
        case .authenticating:
            for offset in [0.0, 0.24, 0.48] {
                let position = CGFloat((period + offset).truncatingRemainder(dividingBy: 1.2) / 1.2)
                drawPacket(in: &context, x: 8 + (size.width - 16) * position, y: centerY, color: packetColor)
            }
        case .secure:
            switch activity {
            case .request, .uploading:
                let packetX = 8 + (size.width - 16) * normalized
                drawBinaryPacket(in: &context, x: packetX, y: centerY, color: packetColor, direction: .outgoing)
            case .response, .downloading:
                let packetX = size.width - 8 - (size.width - 16) * normalized
                drawBinaryPacket(in: &context, x: packetX, y: centerY, color: packetColor, direction: .incoming)
            case .idle:
                break
            }
        default:
            break
        }
    }

    private enum PacketDirection {
        case outgoing
        case incoming
    }

    private func drawPacket(in context: inout GraphicsContext, x: CGFloat, y: CGFloat, color: Color) {
        let rect = CGRect(x: x - 2, y: y - 3, width: 5, height: 5)
        context.fill(Path(rect), with: .color(color))
    }

    private func drawBinaryPacket(
        in context: inout GraphicsContext,
        x: CGFloat,
        y: CGFloat,
        color: Color,
        direction: PacketDirection
    ) {
        drawPacket(in: &context, x: x, y: y, color: color)
        let label = Text("01010101")
            .font(.system(size: 6, weight: .bold, design: .monospaced))
            .foregroundColor(color)
        let point = CGPoint(x: direction == .outgoing ? x + 5 : x - 5, y: y - 7)
        let anchor: UnitPoint = direction == .outgoing ? .leading : .trailing
        context.draw(label, at: point, anchor: anchor)
    }
}

private struct PixelMacEndpoint: View {
    let isActive: Bool
    let isError: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(endpointColor, lineWidth: 2)
                    .frame(width: 24, height: 16)
                Rectangle()
                    .fill(endpointColor.opacity(0.35))
                    .frame(width: 16, height: 8)
                    .offset(y: -1)
                Rectangle()
                    .fill(endpointColor)
                    .frame(width: 10, height: 2)
                    .offset(y: 10)
            }
            Text("MAC")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var endpointColor: Color {
        isError ? .red : (isActive ? .accentColor : .secondary)
    }
}

private struct PixelServerEndpoint: View {
    let isActive: Bool
    let isError: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(endpointColor, lineWidth: 2)
                    .frame(width: 25, height: 18)
                VStack(spacing: 3) {
                    PixelIndicators(color: endpointColor)
                    Rectangle().fill(endpointColor.opacity(0.5)).frame(width: 17, height: 1)
                    PixelIndicators(color: endpointColor)
                }
            }
            Text("SERVER")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var endpointColor: Color {
        isError ? .red : (isActive ? .green : .secondary)
    }
}

private struct PixelIndicators: View {
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Rectangle().fill(color).frame(width: 3, height: 2)
            Rectangle().fill(color.opacity(0.65)).frame(width: 3, height: 2)
            Rectangle().fill(color.opacity(0.4)).frame(width: 3, height: 2)
        }
    }
}

private struct ConnectionStatusLine: View {
    let presentation: ConnectionVisualizerPresentation
    let host: String

    var body: some View {
        HStack(spacing: 6) {
            Text(statusText)
                .font(.caption2.monospaced().weight(.semibold))
            if !host.isEmpty {
                Text(host)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let detailText {
                Text(detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .foregroundStyle(statusColor)
    }

    private var statusText: String {
        switch presentation {
        case .offline:
            "OFFLINE"
        case .connecting:
            "CONNECTING TO"
        case .sshHandshake:
            "SSH HANDSHAKE"
        case .awaitingHostTrust:
            "VERIFYING HOST KEY"
        case .authenticating:
            "AUTHENTICATING • STARTING SFTP"
        case .secure:
            "SECURE CHANNEL"
        case .hostKeyMismatch:
            "HOST KEY CHANGED"
        case let .failed(_, title, _):
            title
        }
    }

    private var detailText: String? {
        switch presentation {
        case .secure:
            "SFTP / SSH"
        case let .hostKeyMismatch(_, message), let .failed(_, _, message):
            message
        default:
            nil
        }
    }

    private var statusColor: Color {
        if presentation.isError { return .red }
        if presentation.isConnected { return .green }
        switch presentation {
        case .awaitingHostTrust:
            return .orange
        case .connecting, .sshHandshake, .authenticating:
            return .accentColor
        default:
            return .secondary
        }
    }
}

private struct CompactSecureStatus: View {
    let profileName: String

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(.green)
                .frame(width: 7, height: 7)
            Text("SECURE")
                .font(.caption2.monospaced().weight(.bold))
            Text("•")
                .foregroundStyle(.secondary)
            Text("SFTP")
                .font(.caption2.monospaced())
            Text("•")
                .foregroundStyle(.secondary)
            Text(profileName)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Secure SFTP connection to \(profileName)")
    }
}
