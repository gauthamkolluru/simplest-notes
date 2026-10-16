import Foundation

public struct HTTPRequest: Equatable, Sendable {
    public var method: String
    public var url: URL
    public var headers: [String: String]
    public var body: Data?

    public init(method: String, url: URL, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Equatable, Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

public protocol HTTPTransport: AnyObject {
    func perform(_ request: HTTPRequest) async throws -> HTTPResponse
}

public enum DriveClientError: Error, Equatable, Sendable {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case quotaExceeded
    case transient
    case offline
    case fileGone
    case unexpected(String)
}
