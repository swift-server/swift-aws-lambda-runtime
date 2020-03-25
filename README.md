# SwiftAWSLambdaRuntimeSample

This repository is a deployable example demonstrating how to package and deploy
a Swift based Lambda to AWS.

Steps to deploy this sample to ASW:

* Login to AWS Console and create an AWS Lambda with the following settings:
  * Runtime: Custom runtime
  * Handler: Can be any string, does not matter in this case


* Build, package and deploy the Lambda

  ```
  ./scripts/deploy.sh
  ```

  This script assumes you have AWS CLI installed and credentials setup in `~/.aws/credentials`

* Test it with the following example payloads:

  ``
  {
    "requestId": "1",
    "error": "none"
  }
  ``

  or

  ``
  {
    "requestId": "2",
    "error": "managed"
  }
  ``

  or

  ``
  {
    "requestId": "3",
    "error": "boom"
  }
  ``

  or

  ``
  {
    "requestId": "4",
    "error": "fatal"
  }
  ``
