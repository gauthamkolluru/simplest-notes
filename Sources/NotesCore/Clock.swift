import Foundation

/// Injectable clock so Debouncer / SyncEngine tests stay deterministic.
public protocol Clock: AnyObject {
    var now: Date { get }
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) -> any ClockCancellable
}

public protocol ClockCancellable: AnyObject {
    func cancel()
}

/// Production clock backed by `DispatchQueue.main` (or a custom queue).
public final class DispatchClock: Clock, @unchecked Sendable {
    private let queue: DispatchQueue

    public init(queue: DispatchQueue = .main) {
        self.queue = queue
    }

    public var now: Date { Date() }

    public func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) -> any ClockCancellable {
        let workItem = DispatchWorkItem(block: work)
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
        return WorkItemToken(workItem)
    }

    private final class WorkItemToken: ClockCancellable {
        private let item: DispatchWorkItem
        init(_ item: DispatchWorkItem) { self.item = item }
        func cancel() { item.cancel() }
    }
}
