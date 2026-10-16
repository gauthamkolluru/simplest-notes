import Foundation

public enum ConnectionState: Equatable, Sendable {
    case notConnected
    case connecting
    case connected(email: String?, syncIssue: Bool = false)
    case authExpired
}

public enum DriveIconAppearance: Equatable, Sendable {
    case dull
    case active
}

public struct DriveIconStyle: Equatable, Sendable {
    public var appearance: DriveIconAppearance
    public var showsSpinner: Bool
    public var showsWarningBadge: Bool
    public var acceptsTap: Bool
    public var accessibilityLabel: String

    public static func from(_ state: ConnectionState) -> DriveIconStyle {
        switch state {
        case .notConnected:
            return DriveIconStyle(
                appearance: .dull,
                showsSpinner: false,
                showsWarningBadge: false,
                acceptsTap: true,
                accessibilityLabel: "Connect Google Drive"
            )
        case .connecting:
            return DriveIconStyle(
                appearance: .dull,
                showsSpinner: true,
                showsWarningBadge: false,
                acceptsTap: false,
                accessibilityLabel: "Connecting to Google Drive"
            )
        case .connected(let email, let syncIssue):
            let mail = email ?? "Google account"
            return DriveIconStyle(
                appearance: .active,
                showsSpinner: false,
                showsWarningBadge: syncIssue,
                acceptsTap: true,
                accessibilityLabel: "Google Drive connected as \(mail)"
            )
        case .authExpired:
            return DriveIconStyle(
                appearance: .dull,
                showsSpinner: false,
                showsWarningBadge: true,
                acceptsTap: true,
                accessibilityLabel: "Google Drive sign-in expired. Tap to reconnect."
            )
        }
    }
}
