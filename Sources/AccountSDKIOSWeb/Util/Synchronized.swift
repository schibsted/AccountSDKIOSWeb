//
// Copyright © 2025 Schibsted.
// Licensed under the terms of the MIT license. See LICENSE in the project root.
//

import Foundation

final class Synchronized<T> {
    private var _value: T
    private let queue = DispatchQueue(label: "com.schibsted.synchronized.queue", attributes: [.concurrent])

    public init(_ value: T) {
        assert(!isReferenceType(value))
        _value = value
    }

    public func modify(_ function: @escaping (T) -> T) {
        queue.sync(flags: [.barrier]) {
            self._value = function(self._value)
        }
    }

    public var value: T {
        return queue.sync { _value }
    }
}

func isReferenceType(_ any: Any) -> Bool {
    return Mirror(reflecting: any).displayStyle == .class
}
