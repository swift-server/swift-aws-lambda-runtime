import Foundation 
import XCTest

enum TestData : String {
    case apiGatewayV2 = "apiv2"
    case sqs = "sqs"
}

class LambdaTest: XCTestCase {
    // return the URL of a test file
    // files are copied to the bundle during build by the `resources` directive in `Package.swift`
    private func urlForTestData(file: TestData) throws -> URL {
        let filePath = Bundle.module.path(forResource: file.rawValue, ofType: "json")!
        return URL(fileURLWithPath: filePath)
    }

    // load a test file added as a resource to the executable bundle
    func loadTestData(file: TestData) throws -> Data {
        // load list from file
        return try Data(contentsOf: urlForTestData(file: file))
    }
}