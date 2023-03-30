import XCTest
@testable import AWSLambdaBasic

final class AWSLambdaBasicTests: XCTestCase {
    func testResponse() throws {
        let myName = "Adolfo"
        let response = BasicResponse(name: myName)
        
        XCTAssertEqual(response.salute, "¡Hola \(myName)! 👋")
        
    }
}
