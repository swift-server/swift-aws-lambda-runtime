#
# --region            the AWS Region to send the command
# --function-name     the name of your function
# --cli-binary-format tells the cli to use raw data as input (default is base64)
# --payload           the payload to pass to your function code
# result.json         the name of the file to store the response from the function

aws lambda invoke                                \
           --region us-west-2                    \
           --function-name SquaredNumberLambda   \
           --cli-binary-format raw-in-base64-out \
           --payload '{"number":3}'              \
           result.json

{
    "StatusCode": 200,
    "ExecutedVersion": "$LATEST"
}

cat result.json
