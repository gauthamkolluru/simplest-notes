import Foundation
@testable import NotesCore

final class FakeHTTPTransport: HTTPTransport, @unchecked Sendable {
    struct Recorded: Equatable {
        var method: String
        var url: String
        var authHeader: String?
        var body: Data?
    }

    var recorded: [Recorded] = []
    var handlers: [(HTTPRequest) -> HTTPResponse] = []
    var defaultResponse = HTTPResponse(statusCode: 500, body: Data("no handler".utf8))
    var throwOffline = false

    /// When true, the next `perform` waits until `releaseHold()` is called (T6.21).
    private let lock = NSLock()
    private var holdEnabled = false
    private var holdContinuation: CheckedContinuation<Void, Never>?

    func armHold() {
        lock.lock()
        holdEnabled = true
        lock.unlock()
    }

    func releaseHold() {
        lock.lock()
        let cont = holdContinuation
        holdContinuation = nil
        holdEnabled = false
        lock.unlock()
        cont?.resume()
    }

    func perform(_ request: HTTPRequest) async throws -> HTTPResponse {
        if throwOffline { throw URLError(.notConnectedToInternet) }

        let shouldHold: Bool = {
            lock.lock(); defer { lock.unlock() }
            if holdEnabled {
                holdEnabled = false
                return true
            }
            return false
        }()
        if shouldHold {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                lock.lock()
                holdContinuation = cont
                lock.unlock()
            }
        }

        recorded.append(
            Recorded(
                method: request.method,
                url: request.url.absoluteString,
                authHeader: request.headers["Authorization"],
                body: request.body
            )
        )
        if handlers.isEmpty { return defaultResponse }
        let handler = handlers.removeFirst()
        return handler(request)
    }

    func enqueueJSON(status: Int, object: Any, headers: [String: String] = [:]) {
        let data = try! JSONSerialization.data(withJSONObject: object)
        handlers.append { _ in HTTPResponse(statusCode: status, headers: headers, body: data) }
    }

    func enqueue(status: Int, body: Data, headers: [String: String] = [:]) {
        handlers.append { _ in HTTPResponse(statusCode: status, headers: headers, body: body) }
    }
}
