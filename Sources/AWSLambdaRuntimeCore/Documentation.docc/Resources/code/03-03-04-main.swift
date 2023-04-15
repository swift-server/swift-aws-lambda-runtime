import AWSLambdaRuntime

struct Input: Codable {
    let number: Double
}

struct Number: Codable {
    let result: Double
}

@main
struct SquareNumberHandler: SimpleLambdaHandler {

    func handle(_ event: Event, context: LambdaContext) async throws -> Output {

    }
}
