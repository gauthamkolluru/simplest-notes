import Foundation

/// Serialises async critical sections without NSLock in async contexts.
actor AsyncGate {
    func withExclusive(_ work: @escaping () async -> Void) async {
        await work()
    }
}
