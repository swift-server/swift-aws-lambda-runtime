// the data structure to represent the input parameter
struct Request: Decodable {
    let text: String
}

// the data structure to represent the response parameter
struct Response: Encodable {
    let text: String
    let isPalindrome: Bool
    let message: String
}
