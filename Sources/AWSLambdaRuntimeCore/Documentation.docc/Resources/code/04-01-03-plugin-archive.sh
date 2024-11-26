# shellcheck disable=all

swift package archive --allow-network-connections docker 

-------------------------------------------------------------------------
building "squarenumberlambda" in docker
-------------------------------------------------------------------------
updating "swift:amazonlinux2" docker image
  amazonlinux2: Pulling from library/swift
  Digest: sha256:5b0cbe56e35210fa90365ba3a4db9cd2b284a5b74d959fc1ee56a13e9c35b378
  Status: Image is up to date for swift:amazonlinux2
  docker.io/library/swift:amazonlinux2
building "SquareNumberLambda"
  Building for production...
...
-------------------------------------------------------------------------
archiving "SquareNumberLambda"
-------------------------------------------------------------------------
1 archive created
  * SquareNumberLambda at /Users/YourUserName/SquareNumberLambda/.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/SquareNumberLambda/SquareNumberLambda.zip

