import XCTest
@testable import NotesCore

final class ConflictResolverTests: XCTestCase {
    private let base = DriveClient.contentHash("base")

    /// T6.01–T6.05 Steady-state table.
    func test_T6_01_nothingWhenNeitherChanged() {
        XCTAssertEqual(
            ConflictResolver.decide(local: "base", remote: "base", baseHash: base),
            .nothing
        )
    }

    func test_T6_02_takeRemoteWhenOnlyRemoteChanged() {
        XCTAssertEqual(
            ConflictResolver.decide(local: "base", remote: "remote", baseHash: base),
            .takeRemote
        )
    }

    func test_T6_03_uploadLocalWhenOnlyLocalChanged() {
        XCTAssertEqual(
            ConflictResolver.decide(local: "local", remote: "base", baseHash: base),
            .uploadLocal
        )
    }

    func test_T6_04_markSyncedWhenBothChangedButIdentical() {
        XCTAssertEqual(
            ConflictResolver.decide(local: "same", remote: "same", baseHash: base),
            .markSynced
        )
    }

    func test_T6_05_conflictWhenBothDiffer() {
        XCTAssertEqual(
            ConflictResolver.decide(local: "L", remote: "R", baseHash: base),
            .keepRemoteSaveLocalAsConflict
        )
    }

    /// T6.06–T6.09 First-connect table.
    func test_T6_06_firstConnectCreateWhenRemoteMissing() {
        XCTAssertEqual(
            ConflictResolver.decideFirstConnect(local: "x", remote: nil),
            .createRemoteFromLocal
        )
    }

    func test_T6_07_firstConnectTakeRemoteWhenLocalEmpty() {
        XCTAssertEqual(
            ConflictResolver.decideFirstConnect(local: "", remote: "remote"),
            .takeRemote
        )
    }

    func test_T6_08_firstConnectMarkSyncedWhenIdentical() {
        XCTAssertEqual(
            ConflictResolver.decideFirstConnect(local: "same", remote: "same"),
            .markSynced
        )
    }

    func test_T6_09_firstConnectConflictWhenDiffer() {
        XCTAssertEqual(
            ConflictResolver.decideFirstConnect(local: "L", remote: "R"),
            .takeRemoteSaveLocalAsConflict
        )
    }

    /// T6.10 Line endings differ → different texts (no normalisation).
    func test_T6_10_lineEndingsAreSignificant() {
        XCTAssertEqual(
            ConflictResolver.decide(local: "a\n", remote: "a\r\n", baseHash: DriveClient.contentHash("x")),
            .keepRemoteSaveLocalAsConflict
        )
    }

    /// T6.11 Conflict copy name unique + sanitised.
    func test_T6_11_conflictCopyName() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let a = ConflictResolver.conflictCopyFileName(now: now, deviceName: "iPad/Pro", uniqueSalt: "aa")
        let b = ConflictResolver.conflictCopyFileName(now: now, deviceName: "iPad/Pro", uniqueSalt: "bb")
        XCTAssertNotEqual(a, b)
        XCTAssertFalse(a.contains("/"))
        XCTAssertTrue(a.hasPrefix("Notes (conflict "))
        XCTAssertTrue(a.hasSuffix(".txt"))
    }
}
