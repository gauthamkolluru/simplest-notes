import XCTest
@testable import NotesCore

final class DebouncerTests: XCTestCase {
    private var clock: ManualClock!
    private var fired: [String]!
    private var debouncer: Debouncer<String>!

    override func setUp() {
        clock = ManualClock()
        fired = []
        debouncer = Debouncer(delay: 0.3, clock: clock) { [weak self] value in
            self?.fired.append(value)
        }
    }

    /// T1.12 Single call fires once after the delay.
    func test_T1_12_singleCallFiresOnceAfterDelay() {
        debouncer.schedule("a")
        clock.advance(by: 0.29)
        XCTAssertEqual(fired, [])
        clock.advance(by: 0.02)
        XCTAssertEqual(fired, ["a"])
    }

    /// T1.13 Burst of calls fires once, with the last value.
    func test_T1_13_burstFiresOnceWithLastValue() {
        debouncer.schedule("a")
        clock.advance(by: 0.1)
        debouncer.schedule("b")
        clock.advance(by: 0.1)
        debouncer.schedule("c")
        clock.advance(by: 0.29)
        XCTAssertEqual(fired, [])
        clock.advance(by: 0.02)
        XCTAssertEqual(fired, ["c"])
    }

    /// T1.14 Calls spaced beyond the delay each fire.
    func test_T1_14_callsSpacedBeyondDelayEachFire() {
        debouncer.schedule("a")
        clock.advance(by: 0.31)
        debouncer.schedule("b")
        clock.advance(by: 0.31)
        XCTAssertEqual(fired, ["a", "b"])
    }

    /// T1.15 flush() fires the pending value immediately and cancels the timer.
    func test_T1_15_flushFiresPendingImmediately() {
        debouncer.schedule("a")
        debouncer.flush()
        XCTAssertEqual(fired, ["a"])
        clock.advance(by: 1)
        XCTAssertEqual(fired, ["a"])
    }

    /// T1.16 flush() with nothing pending does nothing.
    func test_T1_16_flushWithNothingPendingDoesNothing() {
        debouncer.flush()
        XCTAssertEqual(fired, [])
    }

    /// T1.17 cancel() drops pending value.
    func test_T1_17_cancelDropsPending() {
        debouncer.schedule("a")
        debouncer.cancel()
        clock.advance(by: 1)
        XCTAssertEqual(fired, [])
    }

    /// T1.18 Delay of zero fires on next clock drain / schedule path.
    func test_T1_18_zeroDelayFiresOnNextTick() {
        let zero = Debouncer(delay: 0, clock: clock) { [weak self] value in
            self?.fired.append(value)
        }
        zero.schedule("z")
        clock.drain()
        XCTAssertEqual(fired, ["z"])
    }

    /// T1.19 Deallocation with pending work does not crash or fire afterwards.
    func test_T1_19_deinitWithPendingDoesNotFire() {
        var local: Debouncer<String>? = Debouncer(delay: 0.3, clock: clock) { [weak self] value in
            self?.fired.append(value)
        }
        local?.schedule("x")
        local = nil
        clock.advance(by: 1)
        XCTAssertEqual(fired, [])
    }
}
