import Foundation
import Logging
import NIO
import NIOHTTP1

internal struct MockServer {
    private let logger: Logger
    private let group: EventLoopGroup
    private let host: String
    private let port: Int
    private let mode: Mode
    private let keepAlive: Bool

    public init() {
        var logger = Logger(label: "MockServer")
        logger.logLevel = env("LOG_LEVEL").flatMap(Logger.Level.init) ?? .info
        self.logger = logger
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.host = env("HOST") ?? "127.0.0.1"
        self.port = env("PORT").flatMap(Int.init) ?? 7000
        self.mode = env("MODE").flatMap(Mode.init) ?? .string
        self.keepAlive = env("KEEP_ALIVE").flatMap(Bool.init) ?? true
    }

    func start() throws {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap { _ in
                    channel.pipeline.addHandler(HTTPHandler(logger: self.logger,
                                                            keepAlive: self.keepAlive,
                                                            mode: self.mode))
                }
            }
        try bootstrap.bind(host: self.host, port: self.port).flatMap { channel -> EventLoopFuture<Void> in
            guard let localAddress = channel.localAddress else {
                return channel.eventLoop.makeFailedFuture(ServerError.cantBind)
            }
            self.logger.info("\(self) started and listening on \(localAddress)")
            return channel.eventLoop.makeSucceededFuture(())
        }.wait()
    }
}

internal final class HTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    private let logger: Logger
    private let mode: Mode
    private let keepAlive: Bool

    private var requestHead: HTTPRequestHead!
    private var requestBody: ByteBuffer?

    public init(logger: Logger, keepAlive: Bool, mode: Mode) {
        self.logger = logger
        self.mode = mode
        self.keepAlive = keepAlive
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = unwrapInboundIn(data)

        switch requestPart {
        case .head(let head):
            self.requestHead = head
            self.requestBody?.clear()
        case .body(var buffer):
            if self.requestBody == nil {
                self.requestBody = context.channel.allocator.buffer(capacity: buffer.readableBytes)
            }
            self.requestBody!.writeBuffer(&buffer)
        case .end:
            self.processRequest(context: context)
        }
    }

    func processRequest(context: ChannelHandlerContext) {
        self.logger.debug("\(self) processing \(self.requestHead.uri)")

        var responseStatus: HTTPResponseStatus
        var responseBody: String?
        var responseHeaders: [(String, String)]?

        if self.requestHead.uri.hasSuffix("/next") {
            let requestId = UUID().uuidString
            responseStatus = .ok
            switch self.mode {
            case .string:
                responseBody = requestId
            case .json:
                responseBody = "{ \"body\": \"\(requestId)\" }"
            }
            responseHeaders = [(AmazonHeaders.requestID, requestId)]
        } else if self.requestHead.uri.hasSuffix("/response") {
            responseStatus = .accepted
        } else {
            responseStatus = .notFound
        }
        self.writeResponse(context: context, status: responseStatus, headers: responseHeaders, body: responseBody)
    }

    func writeResponse(context: ChannelHandlerContext, status: HTTPResponseStatus, headers: [(String, String)]? = nil, body: String? = nil) {
        var headers = HTTPHeaders(headers ?? [])
        headers.add(name: "Content-Length", value: "\(body?.utf8.count ?? 0)")
        headers.add(name: "Connection", value: self.keepAlive ? "keep-alive" : "close")
        let head = HTTPResponseHead(version: HTTPVersion(major: 1, minor: 1), status: status, headers: headers)

        context.write(wrapOutboundOut(.head(head))).whenFailure { error in
            self.logger.error("\(self) write error \(error)")
        }

        if let b = body {
            var buffer = context.channel.allocator.buffer(capacity: b.utf8.count)
            buffer.writeString(b)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer)))).whenFailure { error in
                self.logger.error("\(self) write error \(error)")
            }
        }

        context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { result in
            if case .failure(let error) = result {
                self.logger.error("\(self) write error \(error)")
            }
            if !self.self.keepAlive {
                context.close().whenFailure { error in
                    self.logger.error("\(self) close error \(error)")
                }
            }
        }
    }
}

internal enum ServerError: Error {
    case notReady
    case cantBind
}

internal enum AmazonHeaders {
    static let requestID = "Lambda-Runtime-Aws-Request-Id"
    static let traceID = "Lambda-Runtime-Trace-Id"
    static let clientContext = "X-Amz-Client-Context"
    static let cognitoIdentity = "X-Amz-Cognito-Identity"
    static let deadline = "Lambda-Runtime-Deadline-Ms"
    static let invokedFunctionARN = "Lambda-Runtime-Invoked-Function-Arn"
}

internal enum Mode: String {
    case string
    case json
}

func env(_ name: String) -> String? {
    guard let value = getenv(name) else {
        return nil
    }
    return String(utf8String: value)
}

// main
let server = MockServer()
try! server.start()
dispatchMain()
