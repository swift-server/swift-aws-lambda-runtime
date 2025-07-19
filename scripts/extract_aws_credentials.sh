#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftAWSLambdaRuntime open source project
##
## Copyright (c) 2025 Apple Inc. and the SwiftAWSLambdaRuntime project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

# Extract AWS credentials from ~/.aws/credentials and ~/.aws/config (default profile)
# and set environment variables

set -e

# Default profile name
PROFILE="default"

# Check if a different profile is specified as argument
if [ $# -eq 1 ]; then
    PROFILE="$1"
fi

# AWS credentials file path
CREDENTIALS_FILE="$HOME/.aws/credentials"
CONFIG_FILE="$HOME/.aws/config"

# Check if credentials file exists
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "Error: AWS credentials file not found at $CREDENTIALS_FILE"
    exit 1
fi

# Function to extract value from AWS config files
extract_value() {
    local file="$1"
    local profile="$2"
    local key="$3"
    
    # Use awk to extract the value for the specified profile and key
    awk -v profile="[$profile]" -v key="$key" '
    BEGIN { in_profile = 0 }
    $0 == profile { in_profile = 1; next }
    /^\[/ && $0 != profile { in_profile = 0 }
    in_profile && $0 ~ "^" key " *= *" {
        gsub("^" key " *= *", "")
        gsub(/^[ \t]+|[ \t]+$/, "")  # trim whitespace
        print $0
        exit
    }
    ' "$file"
}

# Extract credentials
AWS_ACCESS_KEY_ID=$(extract_value "$CREDENTIALS_FILE" "$PROFILE" "aws_access_key_id")
AWS_SECRET_ACCESS_KEY=$(extract_value "$CREDENTIALS_FILE" "$PROFILE" "aws_secret_access_key")
AWS_SESSION_TOKEN=$(extract_value "$CREDENTIALS_FILE" "$PROFILE" "aws_session_token")

# Extract region from config file (try both credentials and config files)
AWS_REGION=$(extract_value "$CREDENTIALS_FILE" "$PROFILE" "region")
if [ -z "$AWS_REGION" ] && [ -f "$CONFIG_FILE" ]; then
    # Try config file with profile prefix for non-default profiles
    if [ "$PROFILE" = "default" ]; then
        AWS_REGION=$(extract_value "$CONFIG_FILE" "$PROFILE" "region")
    else
        AWS_REGION=$(extract_value "$CONFIG_FILE" "profile $PROFILE" "region")
    fi
fi

# Validate required credentials
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "Error: aws_access_key_id not found for profile '$PROFILE'"
    exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Error: aws_secret_access_key not found for profile '$PROFILE'"
    exit 1
fi

# Set default region if not found
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="us-east-1"
    echo "Warning: No region found for profile '$PROFILE', defaulting to us-east-1"
fi

# Export environment variables
export AWS_REGION="$AWS_REGION"
export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"

# Only export session token if it exists (for temporary credentials)
if [ -n "$AWS_SESSION_TOKEN" ]; then
    export AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN"
fi

# Print confirmation (without sensitive values)
echo "AWS credentials loaded for profile: $PROFILE"
echo "AWS_REGION: $AWS_REGION"
echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:4}****"
echo "AWS_SECRET_ACCESS_KEY: ****"
if [ -n "$AWS_SESSION_TOKEN" ]; then
    echo "AWS_SESSION_TOKEN: ****"
fi

# Optional: Print export commands for manual sourcing
echo ""
echo "To use these credentials in your current shell, run:"
echo "source $(basename "$0")"
echo ""
echo "Or copy and paste these export commands:"
echo "export AWS_REGION='$AWS_REGION'"
echo "export AWS_ACCESS_KEY_ID='$AWS_ACCESS_KEY_ID'"
echo "export AWS_SECRET_ACCESS_KEY='$AWS_SECRET_ACCESS_KEY'"
if [ -n "$AWS_SESSION_TOKEN" ]; then
    echo "export AWS_SESSION_TOKEN='$AWS_SESSION_TOKEN'"
fi