import Foundation
import os

/// Logs a reader failure once per launch, so a broken sensor doesn't flood the log.
final class ReaderLog: Sendable {
    private let logger: Logger
    private let didLog = OSAllocatedUnfairLock(initialState: false)

    init(category: String) {
        logger = Logger(subsystem: "com.popam.PopAM", category: category)
    }

    func failure(_ message: String) {
        let first = didLog.withLock { logged in
            defer { logged = true }
            return !logged
        }
        if first { logger.error("\(message, privacy: .public)") }
    }
}
