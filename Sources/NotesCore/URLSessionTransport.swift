import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Production HTTP transport for DriveClient.
public final class URLSessionTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func perform(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        urlRequest.httpBody = request.body
        let (data, response) = try await session.data(for: urlRequest)
        let http = response as? HTTPURLResponse
        var headers: [String: String] = [:]
        http?.allHeaderFields.forEach { key, value in
            if let k = key as? String {
                headers[k] = "\(value)"
            }
        }
        return HTTPResponse(statusCode: http?.statusCode ?? 0, headers: headers, body: data)
    }
}
