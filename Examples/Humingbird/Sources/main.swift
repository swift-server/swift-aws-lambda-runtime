import AWSLambdaEvents
import HummingbirdLambda
import Logging

typealias AppRequestContext = BasicLambdaRequestContext<APIGatewayV2Request>
let router = Router(context: AppRequestContext.self)

router.get("hello") { _, _ in
    "Hello"
}

let lambda = APIGatewayV2LambdaFunction(router: router)
try await lambda.runService()
