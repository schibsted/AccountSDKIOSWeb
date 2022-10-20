//
// Copyright © 2022 Schibsted.
// Licensed under the terms of the MIT license. See LICENSE in the project root.
//

import Foundation
import XCTest
@testable import AccountSDKIOSWeb

private class FakeDataTask: URLSessionDataTask {
    private let completionHandler: () -> Void
    
    init(completionHandler: @escaping () -> Void) {
        self.completionHandler = completionHandler
    }
    
    override func resume() {
        completionHandler()
    }
}

class MockURLSessionProtocol: URLSessionProtocol {
    var request: URLRequest
    var results: [(Data?, HTTPURLResponse?, Error?)]
    var counter: Int = 0
    
    init (request: URLRequest, results: [(Data?, HTTPURLResponse?, Error?)]){
        self.request = request
        self.results = results
    }
    
    func dataTask(with: URLRequest, completionHandler: @escaping DataTaskResult) -> URLSessionDataTask {
        counter += 1
        let result = results.first
        results.removeFirst()
        return FakeDataTask {
            completionHandler(result?.0, result?.1, result?.2)
        }
    }
}
