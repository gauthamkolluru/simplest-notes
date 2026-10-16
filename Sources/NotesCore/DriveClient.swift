import Foundation

public struct DriveFileMetadata: Equatable, Sendable {
    public var id: String
    public var version: String
    public var modifiedTime: String
    public var trashed: Bool

    public init(id: String, version: String, modifiedTime: String, trashed: Bool) {
        self.id = id
        self.version = version
        self.modifiedTime = modifiedTime
        self.trashed = trashed
    }
}

public struct DriveDownload: Equatable, Sendable {
    public var text: String
    public var wasLossy: Bool
}

/// Google Drive v3 client over an injectable transport (ADR-0004).
public final class DriveClient: @unchecked Sendable {
    public static let folderName = "Simplest Notes"
    public static let noteFileName = "Notes.txt"
    public static let mimePlain = "text/plain"
    public static let mimeFolder = "application/vnd.google-apps.folder"

    private let transport: any HTTPTransport
    private let accessTokenProvider: () async throws -> String
    private let baseURL: URL

    public init(
        transport: any HTTPTransport,
        accessTokenProvider: @escaping () async throws -> String,
        baseURL: URL = URL(string: "https://www.googleapis.com/drive/v3")!
    ) {
        self.transport = transport
        self.accessTokenProvider = accessTokenProvider
        self.baseURL = baseURL
    }

    // MARK: - Folder / file location

    public func findFolder() async throws -> String? {
        let q = "name = '\(Self.escapeQuery(Self.folderName))' and mimeType = '\(Self.mimeFolder)' and trashed = false"
        let files = try await listFiles(query: q, orderBy: "createdTime")
        return files.first?["id"] as? String
    }

    public func createFolder() async throws -> String {
        let body: [String: Any] = [
            "name": Self.folderName,
            "mimeType": Self.mimeFolder,
        ]
        let json = try await postJSON(path: "files", body: body)
        guard let id = json["id"] as? String else {
            throw DriveClientError.unexpected("createFolder missing id")
        }
        return id
    }

    public func findNoteFile(folderId: String) async throws -> String? {
        let q = "name = '\(Self.escapeQuery(Self.noteFileName))' and '\(folderId)' in parents and trashed = false"
        let files = try await listFiles(query: q, orderBy: "modifiedTime desc")
        return files.first?["id"] as? String
    }

    public func createNoteFile(folderId: String, text: String) async throws -> DriveFileMetadata {
        try await uploadNewFile(name: Self.noteFileName, folderId: folderId, text: text)
    }

    // MARK: - Content

    public func download(fileId: String) async throws -> DriveDownload {
        let url = baseURL.appendingPathComponent("files").appendingPathComponent(fileId)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "alt", value: "media")]
        let response = try await authorized(method: "GET", url: components.url!)
        try throwIfNeeded(response)
        var data = response.body
        // Strip UTF-8 BOM if present
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            data = data.dropFirst(3)
        }
        if let text = String(data: data, encoding: .utf8) {
            return DriveDownload(text: text, wasLossy: false)
        }
        return DriveDownload(text: String(decoding: data, as: UTF8.self), wasLossy: true)
    }

    public func upload(fileId: String, text: String) async throws -> DriveFileMetadata {
        let uploadBase = URL(string: "https://www.googleapis.com/upload/drive/v3/files")!
        var components = URLComponents(url: uploadBase.appendingPathComponent(fileId), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "uploadType", value: "media")]
        let response = try await authorized(
            method: "PATCH",
            url: components.url!,
            headers: ["Content-Type": Self.mimePlain],
            body: Data(text.utf8)
        )
        try throwIfNeeded(response)
        return try parseMetadata(response.body, fallbackId: fileId)
    }

    public func metadata(fileId: String) async throws -> DriveFileMetadata {
        let url = baseURL.appendingPathComponent("files").appendingPathComponent(fileId)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "fields", value: "id,version,modifiedTime,trashed"),
        ]
        let response = try await authorized(method: "GET", url: components.url!)
        if response.statusCode == 404 {
            throw DriveClientError.fileGone
        }
        try throwIfNeeded(response)
        let meta = try parseMetadata(response.body, fallbackId: fileId)
        if meta.trashed { throw DriveClientError.fileGone }
        return meta
    }

    public func uploadConflictCopy(folderId: String, text: String, fileName: String) async throws -> DriveFileMetadata {
        try await uploadNewFile(name: fileName, folderId: folderId, text: text)
    }

    public static func escapeQuery(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }

    public static func sha256Hex(_ text: String) -> String {
        SHA256Hasher.hex(Data(text.utf8))
    }

    public static func contentHash(_ text: String) -> String {
        sha256Hex(text)
    }

    // MARK: - Internals

    private func uploadNewFile(name: String, folderId: String, text: String) async throws -> DriveFileMetadata {
        let metadata: [String: Any] = [
            "name": name,
            "mimeType": Self.mimePlain,
            "parents": [folderId],
        ]
        let metaData = try JSONSerialization.data(withJSONObject: metadata)
        let boundary = "simplestnotes-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metaData)
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(Self.mimePlain)\r\n\r\n".data(using: .utf8)!)
        body.append(Data(text.utf8))
        body.append("\r\n--\(boundary)--".data(using: .utf8)!)

        let uploadURL = URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")!
        let response = try await authorized(
            method: "POST",
            url: uploadURL,
            headers: ["Content-Type": "multipart/related; boundary=\(boundary)"],
            body: body
        )
        try throwIfNeeded(response)
        return try parseMetadata(response.body, fallbackId: "unknown")
    }

    private func listFiles(query: String, orderBy: String) async throws -> [[String: Any]] {
        var components = URLComponents(url: baseURL.appendingPathComponent("files"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "spaces", value: "drive"),
            URLQueryItem(name: "fields", value: "files(id,name,modifiedTime,createdTime)"),
            URLQueryItem(name: "orderBy", value: orderBy),
        ]
        let response = try await authorized(method: "GET", url: components.url!)
        try throwIfNeeded(response)
        let json = try JSONSerialization.jsonObject(with: response.body) as? [String: Any]
        return json?["files"] as? [[String: Any]] ?? []
    }

    private func postJSON(path: String, body: [String: Any]) async throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: body)
        let response = try await authorized(
            method: "POST",
            url: baseURL.appendingPathComponent(path),
            headers: ["Content-Type": "application/json"],
            body: data
        )
        try throwIfNeeded(response)
        return (try JSONSerialization.jsonObject(with: response.body) as? [String: Any]) ?? [:]
    }

    private func authorized(
        method: String,
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> HTTPResponse {
        var headers = headers
        let token = try await accessTokenProvider()
        headers["Authorization"] = "Bearer \(token)"
        do {
            return try await transport.perform(HTTPRequest(method: method, url: url, headers: headers, body: body))
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                throw DriveClientError.offline
            default:
                throw DriveClientError.transient
            }
        }
    }

    private func throwIfNeeded(_ response: HTTPResponse) throws {
        switch response.statusCode {
        case 200..<300:
            return
        case 401:
            throw DriveClientError.unauthorized
        case 403:
            let body = String(data: response.body, encoding: .utf8) ?? ""
            if body.contains("userRateLimitExceeded") || body.contains("rateLimitExceeded") {
                let retry = response.headers["Retry-After"].flatMap(TimeInterval.init)
                throw DriveClientError.rateLimited(retryAfter: retry)
            }
            if body.contains("storageQuotaExceeded") {
                throw DriveClientError.quotaExceeded
            }
            throw DriveClientError.unexpected("403: \(body)")
        case 404:
            throw DriveClientError.fileGone
        case 500..<600:
            throw DriveClientError.transient
        default:
            throw DriveClientError.unexpected("HTTP \(response.statusCode)")
        }
    }

    private func parseMetadata(_ data: Data, fallbackId: String) throws -> DriveFileMetadata {
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let id = json["id"] as? String ?? fallbackId
        let version = json["version"] as? String ?? "0"
        let modified = json["modifiedTime"] as? String ?? ""
        let trashed = json["trashed"] as? Bool ?? false
        return DriveFileMetadata(id: id, version: version, modifiedTime: modified, trashed: trashed)
    }
}
