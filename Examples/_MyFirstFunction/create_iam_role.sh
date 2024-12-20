#
# Create an IAM role for the Lambda function
#
create_lambda_execution_role() {
    role_name=$1

    # Allow the Lambda service to assume the IAM role
    cat <<EOF > trust-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

    # Create the IAM role
    echo "🔐 Create the IAM role for the Lambda function"
    aws iam create-role \
    --role-name $role_name \
    --assume-role-policy-document file://trust-policy.json > /dev/null 2>&1

    # Attach basic permissions to the role
    # The AWSLambdaBasicExecutionRole policy grants permissions to write logs to CloudWatch Logs
    echo "🔒 Attach basic permissions to the role"
    aws iam attach-role-policy \
    --role-name $role_name \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole > /dev/null 2>&1

    echo "⏰ Waiting 10 secs for IAM role to propagate..."
    sleep 10
}