# shellcheck disable=all

export LOCAL_LAMBDA_SERVER_ENABLED=true
swift run

Building for debugging...
Build complete! (0.20s)
2023-04-14T10:52:25+0200 info LocalLambdaServer : [AWSLambdaRuntimeCore] LocalLambdaServer started and listening on 127.0.0.1:7000, receiving events on /invoke
2023-04-14T10:52:25+0200 info Lambda : [AWSLambdaRuntimeCore] lambda runtime starting with LambdaConfiguration
  General(logLevel: info))
  Lifecycle(id: 102943961260250, maxTimes: 0, stopSignal: TERM)
  RuntimeEngine(ip: 127.0.0.1, port: 7000, requestTimeout: nil
