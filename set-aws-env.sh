#!/bin/bash

# Script to set AWS environment variables from AWS CLI default profile
# Usage: source ./set-aws-env.sh

# Get AWS credentials from the default profile
AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
AWS_SESSION_TOKEN=$(aws configure get aws_session_token)
AWS_DEFAULT_REGION=$(aws configure get region)

# Check if we got the basic credentials
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Error: Could not retrieve AWS credentials from default profile"
    echo "Make sure you have configured AWS CLI with 'aws configure'"
    return 1 2>/dev/null || exit 1
fi

# Export the environment variables
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY

# Only export session token if it exists (for temporary credentials)
if [ -n "$AWS_SESSION_TOKEN" ]; then
    export AWS_SESSION_TOKEN
    echo "Set AWS_SESSION_TOKEN (temporary credentials detected)"
else
    # Unset session token in case it was previously set
    unset AWS_SESSION_TOKEN
fi

# Export region if available
if [ -n "$AWS_DEFAULT_REGION" ]; then
    export AWS_DEFAULT_REGION
    echo "Set AWS_DEFAULT_REGION to: $AWS_DEFAULT_REGION"
fi

echo "AWS environment variables set successfully:"
echo "  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:8}..."
echo "  AWS_SECRET_ACCESS_KEY: [HIDDEN]"
echo "  AWS_REGION: ${AWS_REGION}"

# Verify the credentials work
if command -v aws >/dev/null 2>&1; then
    echo "Testing credentials..."
    if aws sts get-caller-identity >/dev/null 2>&1; then
        echo "✓ Credentials are valid"
    else
        echo "⚠ Warning: Credentials may be invalid or expired"
    fi
fi