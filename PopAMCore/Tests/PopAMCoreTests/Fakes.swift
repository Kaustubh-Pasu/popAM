@testable import PopAMCore

/// Returns scripted values in order; repeats the last one when exhausted.
final class Script<T> {
    private var values: [T]
    init(_ values: [T]) { self.values = values }
    func next() -> T {
        values.count > 1 ? values.removeFirst() : values[0]
    }
}
