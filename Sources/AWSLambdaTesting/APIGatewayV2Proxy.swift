
#if DEBUG
import AWSLambdaEvents
import NIO

struct APIGatewayV2Proxy: LocalLambdaInvocationProxy {
    let eventLoop: EventLoop

    init(eventLoop: EventLoop) {
        self.eventLoop = eventLoop
    }

    func invocation(from request: HTTPRequest) -> EventLoopFuture<ByteBuffer> {
        switch (request.method, request.uri) {
        case (.POST, "/invoke"):
            guard let body = request.body else {
                return self.eventLoop.makeFailedFuture(InvocationHTTPError(.init(status: .badRequest)))
            }
            return self.eventLoop.makeSucceededFuture(body)
        default:
            return self.eventLoop.makeFailedFuture(InvocationHTTPError(.init(status: .notFound)))
        }
    }

    func processResult(_ result: ByteBuffer?) -> EventLoopFuture<HTTPResponse> {
        self.eventLoop.makeSucceededFuture(.init(status: .ok, body: result))
    }

    func processError(_ error: ByteBuffer?) -> EventLoopFuture<HTTPResponse> {
        self.eventLoop.makeSucceededFuture(.init(status: .internalServerError, body: error))
    }
}
#endif
