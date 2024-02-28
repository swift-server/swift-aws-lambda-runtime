import Foundation

public enum NetworkError: Error {
    case malformedRequest
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case internalError
    case serviceUnavailable
    case jsonDecode
    case backendError(code: Int)
}
