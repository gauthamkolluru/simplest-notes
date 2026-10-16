import Foundation
@testable import NotesCore

/// Deterministic clock for Debouncer / Autosave tests.
final class ManualClock: Clock, @unchecked Sendable {
    private(set) var now: Date
    private var scheduled: [(deadline: Date, id: UUID, work: () -> Void)] = []

    init(start: Date = Date(timeIntervalSince1970: 1_000_000)) {
        self.now = start
    }

    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) -> any ClockCancellable {
        let id = UUID()
        let deadline = now.addingTimeInterval(delay)
        scheduled.append((deadline, id, work))
        scheduled.sort { $0.deadline < $1.deadline }
        return Token { [weak self] in
            self?.scheduled.removeAll { $0.id == id }
        }
    }

    /// Advance time and fire due work in order.
    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
        drain()
    }

    func drain() {
        while let next = scheduled.first, next.deadline <= now {
            scheduled.removeFirst()
            next.work()
        }
    }

    private final class Token: ClockCancellable {
        private var onCancel: (() -> Void)?
        init(_ onCancel: @escaping () -> Void) { self.onCancel = onCancel }
        func cancel() {
            onCancel?()
            onCancel = nil
        }
        deinit { cancel() }
    }
}
