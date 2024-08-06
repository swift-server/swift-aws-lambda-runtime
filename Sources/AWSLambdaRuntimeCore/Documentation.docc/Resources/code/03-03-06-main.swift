import AWSLambdaRuntime

struct Input: Codable {
    let number: Double
}

struct Number: Codable {
    let result: Double
}

@main
struct SquareNumberHandler: SimpleLambdaHandler {
    typealias Event = Input
    typealias Output = Number

    func handle(_ event: Event, context: LambdaContext) async throws -> Output {
        Number(result: event.number * event.number)
    }
}
