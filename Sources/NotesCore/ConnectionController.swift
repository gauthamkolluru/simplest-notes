import Foundation

public enum AccountSheet: Equatable, Sendable {
    case account(email: String)
}

/// Connection / account-sheet state machine (R9–R11). Pure NotesCore — no Combine/UIKit.
public final class ConnectionController: @unchecked Sendable {
    public private(set) var state: ConnectionState = .notConnected
    public private(set) var sheet: AccountSheet?
    public private(set) var inlineError: String?

    public var onChange: (() -> Void)?

    private let auth: any AuthProviding
    private let lock = NSLock()
    private var busy = false

    public init(auth: any AuthProviding) {
        self.auth = auth
    }

    public func handleIconTap() async {
        let style = DriveIconStyle.from(currentState())
        guard style.acceptsTap else { return }

        switch currentState() {
        case .notConnected, .authExpired:
            await signIn()
        case .connected(let email, _):
            let label = (email?.isEmpty == false) ? email! : "Google account"
            setSheet(.account(email: label))
        case .connecting:
            break
        }
    }

    public func dismissSheet() {
        setSheet(nil)
    }

    public func disconnect(keepingLocalNote: inout Bool) async {
        keepingLocalNote = true
        await disconnect()
    }

    public func disconnect() async {
        guard beginBusy() else { return }
        defer { endBusy() }
        await auth.disconnect()
        setState(.notConnected)
        setSheet(nil)
        setInlineError(nil)
    }

    public func switchAccount() async {
        guard beginBusy() else { return }
        await auth.disconnect()
        setState(.notConnected)
        setSheet(nil)
        endBusy()
        await signIn()
    }

    public static func displayEmail(_ email: String, maxLength: Int = 28) -> String {
        guard email.count > maxLength else { return email }
        let keep = max(1, (maxLength - 1) / 2)
        let prefix = email.prefix(keep)
        let suffix = email.suffix(keep)
        return "\(prefix)…\(suffix)"
    }

    public static func accessibilityEmail(_ email: String) -> String { email }

    private func signIn() async {
        guard beginBusy() else { return }
        setState(.connecting)
        setInlineError(nil)
        let result = await auth.signIn()
        switch result {
        case .success(let email):
            setState(.connected(email: email))
        case .cancelled:
            setState(.notConnected)
        case .failure(.network):
            setState(.notConnected)
            setInlineError("Couldn't reach Google. Check your connection and try again.")
        case .failure(.scopeDeclined):
            setState(.notConnected)
            setInlineError("Drive access is required to back up your note.")
        case .failure(.unknown):
            setState(.notConnected)
            setInlineError("Sign-in failed. Please try again.")
        }
        endBusy()
    }

    private func currentState() -> ConnectionState {
        lock.lock(); defer { lock.unlock() }
        return state
    }

    private func setState(_ newValue: ConnectionState) {
        lock.lock()
        state = newValue
        lock.unlock()
        onChange?()
    }

    private func setSheet(_ newValue: AccountSheet?) {
        lock.lock()
        sheet = newValue
        lock.unlock()
        onChange?()
    }

    private func setInlineError(_ newValue: String?) {
        lock.lock()
        inlineError = newValue
        lock.unlock()
        onChange?()
    }

    private func beginBusy() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if busy { return false }
        busy = true
        return true
    }

    private func endBusy() {
        lock.lock()
        busy = false
        lock.unlock()
    }
}
