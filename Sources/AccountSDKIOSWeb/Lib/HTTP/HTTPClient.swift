import Foundation

public typealias HTTPResultHandler<T> = (Result<T, HTTPError>) -> Void

public protocol HTTPClient {
    func execute<T: Decodable>(request: URLRequest, withRetryPolicy: RetryPolicy, completion: @escaping HTTPResultHandler<T>)
}

extension HTTPClient {
    func execute<T: Decodable>(request: URLRequest, withRetryPolicy: RetryPolicy = NoRetries.policy, completion: @escaping HTTPResultHandler<T>) {
        execute(request: request, withRetryPolicy: withRetryPolicy, completion: completion)
    }
}