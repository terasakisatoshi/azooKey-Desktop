import Foundation

private let userDefaultsTestIsolationLock = NSLock()

public func withIsolatedUserDefaults<T>(_ body: () -> T) -> T {
    userDefaultsTestIsolationLock.lock()
    defer {
        userDefaultsTestIsolationLock.unlock()
    }
    return body()
}
