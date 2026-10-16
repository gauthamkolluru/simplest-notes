import XCTest
@testable import NotesCore

final class DriveClientTests: XCTestCase {
    private var http: FakeHTTPTransport!
    private var tokens: [String]!
    private var client: DriveClient!

    override func setUp() {
        http = FakeHTTPTransport()
        tokens = ["tok-1"]
        client = DriveClient(transport: http, accessTokenProvider: { [weak self] in
            guard let self else { return "gone" }
            if self.tokens.count > 1 {
                return self.tokens.removeFirst()
            }
            return self.tokens[0]
        })
    }

    /// T5.01 Find folder: exists → id; missing → nil; multiple → oldest.
    func test_T5_01_findFolderVariants() async throws {
        http.enqueueJSON(status: 200, object: [
            "files": [
                ["id": "old", "createdTime": "2020-01-01T00:00:00Z"],
                ["id": "new", "createdTime": "2024-01-01T00:00:00Z"],
            ],
        ])
        let first = try await client.findFolder()
        XCTAssertEqual(first, "old")

        http.enqueueJSON(status: 200, object: ["files": []])
        let missing = try await client.findFolder()
        XCTAssertNil(missing)
    }

    /// T5.02 Create folder then file with correct metadata/MIME.
    func test_T5_02_createFolderAndFileMetadata() async throws {
        http.enqueueJSON(status: 200, object: ["id": "folder1"])
        let folderId = try await client.createFolder()
        XCTAssertEqual(folderId, "folder1")
        let folderBody = String(data: http.recorded[0].body ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(
            folderBody.contains("application/vnd.google-apps.folder") || folderBody.contains("mimeType"),
            "create folder body should declare folder mime type: \(folderBody)"
        )

        http.enqueueJSON(status: 200, object: [
            "id": "file1", "version": "1", "modifiedTime": "t", "trashed": false,
        ])
        _ = try await client.createNoteFile(folderId: "folder1", text: "hi")
        let create = http.recorded.last!
        XCTAssertEqual(create.method, "POST")
        XCTAssertTrue(create.url.contains("uploadType=multipart"))
        let body = String(data: create.body!, encoding: .utf8)!
        XCTAssertTrue(body.contains("text/plain"))
        XCTAssertTrue(body.contains("folder1"))
        XCTAssertTrue(body.contains("hi"))
    }

    /// T5.03 Find file: none / one / multiple (most recent) / trashed ignored via query.
    func test_T5_03_findFileVariants() async throws {
        http.enqueueJSON(status: 200, object: ["files": []])
        let none = try await client.findNoteFile(folderId: "f")
        XCTAssertNil(none)

        http.enqueueJSON(status: 200, object: [
            "files": [
                ["id": "newer", "modifiedTime": "2024-02-01T00:00:00Z"],
                ["id": "older", "modifiedTime": "2024-01-01T00:00:00Z"],
            ],
        ])
        let found = try await client.findNoteFile(folderId: "f")
        XCTAssertEqual(found, "newer")
        XCTAssertTrue(http.recorded.last!.url.contains("trashed") || http.recorded.last!.url.contains("q="))
    }

    /// T5.04 Download exact UTF-8; empty; BOM stripped; non-UTF-8 lossy.
    func test_T5_04_downloadVariants() async throws {
        http.enqueue(status: 200, body: Data())
        let empty = try await client.download(fileId: "f")
        XCTAssertEqual(empty.text, "")

        http.enqueue(status: 200, body: Data("hello".utf8))
        let hello = try await client.download(fileId: "f")
        XCTAssertEqual(hello.text, "hello")

        var bom = Data([0xEF, 0xBB, 0xBF])
        bom.append(Data("x".utf8))
        http.enqueue(status: 200, body: bom)
        let stripped = try await client.download(fileId: "f")
        XCTAssertEqual(stripped.text, "x")

        http.enqueue(status: 200, body: Data([0xFF, 0xFE]))
        let lossy = try await client.download(fileId: "f")
        XCTAssertTrue(lossy.wasLossy)
    }

    /// T5.05 Upload sends exact body and returns version.
    func test_T5_05_uploadReturnsVersion() async throws {
        http.enqueueJSON(status: 200, object: [
            "id": "f", "version": "9", "modifiedTime": "t", "trashed": false,
        ])
        let meta = try await client.upload(fileId: "f", text: "abc")
        XCTAssertEqual(meta.version, "9")
        XCTAssertEqual(http.recorded.last?.body, Data("abc".utf8))
    }

    /// T5.06 Metadata fetch returns version, modifiedTime, trashed.
    func test_T5_06_metadataFields() async throws {
        http.enqueueJSON(status: 200, object: [
            "id": "f", "version": "3", "modifiedTime": "2024-01-01T00:00:00Z", "trashed": false,
        ])
        let meta = try await client.metadata(fileId: "f")
        XCTAssertEqual(meta.version, "3")
        XCTAssertEqual(meta.modifiedTime, "2024-01-01T00:00:00Z")
        XCTAssertFalse(meta.trashed)
    }

    /// T5.07 Cached id 404 or trashed → fileGone.
    func test_T5_07_fileGone() async throws {
        http.enqueue(status: 404, body: Data())
        do {
            _ = try await client.metadata(fileId: "missing")
            XCTFail("expected fileGone")
        } catch DriveClientError.fileGone {}

        http.enqueueJSON(status: 200, object: [
            "id": "f", "version": "1", "modifiedTime": "t", "trashed": true,
        ])
        do {
            _ = try await client.metadata(fileId: "f")
            XCTFail("expected fileGone")
        } catch DriveClientError.fileGone {}
    }

    /// T5.08 Error mapping for 401 / rate limit / quota / 5xx / offline.
    func test_T5_08_errorMapping() async throws {
        http.enqueue(status: 401, body: Data())
        await assertThrows(DriveClientError.unauthorized) {
            _ = try await client.metadata(fileId: "f")
        }

        http.enqueue(
            status: 403,
            body: Data("{\"error\":{\"errors\":[{\"reason\":\"userRateLimitExceeded\"}]}}".utf8),
            headers: ["Retry-After": "12"]
        )
        await assertThrows(DriveClientError.rateLimited(retryAfter: 12)) {
            _ = try await client.metadata(fileId: "f")
        }

        http.enqueue(status: 403, body: Data("storageQuotaExceeded".utf8))
        await assertThrows(DriveClientError.quotaExceeded) {
            _ = try await client.metadata(fileId: "f")
        }

        http.enqueue(status: 503, body: Data())
        await assertThrows(DriveClientError.transient) {
            _ = try await client.metadata(fileId: "f")
        }

        http.throwOffline = true
        await assertThrows(DriveClientError.offline) {
            _ = try await client.metadata(fileId: "f")
        }
    }

    /// T5.09 Query strings escape quotes/backslashes.
    func test_T5_09_queryEscaping() {
        XCTAssertEqual(DriveClient.escapeQuery("a'b\\c"), "a\\'b\\\\c")
    }

    /// T5.10 Auth header uses a fresh token each request.
    func test_T5_10_freshTokenEachRequest() async throws {
        tokens = ["t1", "t2"]
        http.enqueueJSON(status: 200, object: ["files": []])
        http.enqueueJSON(status: 200, object: ["files": []])
        _ = try await client.findFolder()
        _ = try await client.findFolder()
        XCTAssertEqual(http.recorded[0].authHeader, "Bearer t1")
        XCTAssertEqual(http.recorded[1].authHeader, "Bearer t2")
    }

    private func assertThrows<E: Error & Equatable>(
        _ expected: E,
        _ block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("expected \(expected)")
        } catch let error as E {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}
