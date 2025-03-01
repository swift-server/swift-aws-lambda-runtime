import AWSLambdaRuntime

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

// the business function
func isPalindrome(_ text: String) -> Bool {
    let cleanedText = text.lowercased().filter { $0.isLetter }
    return cleanedText == String(cleanedText.reversed())
}
