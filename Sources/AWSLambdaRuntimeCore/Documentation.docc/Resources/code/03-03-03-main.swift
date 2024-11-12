import AWSLambdaRuntime

// the data structure to represent the input parameter
struct Request: Decodable {
    let number: Double
}

// the data structure to represent the output response
struct Response: Encodable {
    let result: Double
}

// the Lambda runtime
let runtime = LambdaRuntime {
