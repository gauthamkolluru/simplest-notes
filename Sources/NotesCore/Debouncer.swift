import Foundation

/// Coalesces rapid updates; fires the latest value after `delay`.
public final class Debouncer<Value> {
    private let delay: TimeInterval
    private let clock: any Clock
    private let onFire: (Value) -> Void

    private var pending: Value?
    private var token: (any ClockCancellable)?
    private var alive = true

    public init(delay: TimeInterval, clock: any Clock, onFire: @escaping (Value) -> Void) {
        self.delay = delay
        self.clock = clock
        self.onFire = onFire
    }

    deinit {
        alive = false
        token?.cancel()
        token = nil
        pending = nil
    }

    public func schedule(_ value: Value) {
        pending = value
        token?.cancel()
        let delay = self.delay
        token = clock.schedule(after: delay) { [weak self] in
            guard let self, self.alive else { return }
            self.firePending()
        }
    }

    public func flush() {
        token?.cancel()
        token = nil
        firePending()
    }

    public func cancel() {
        token?.cancel()
        token = nil
        pending = nil
    }

    private func firePending() {
        guard let value = pending else { return }
        pending = nil
        token = nil
        onFire(value)
    }
}
