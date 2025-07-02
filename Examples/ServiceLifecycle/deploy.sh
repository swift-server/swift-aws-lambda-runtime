#!/bin/bash

# ServiceLifecycle Lambda Deployment Script
set -e

echo "🚀 Building and deploying ServiceLifecycle Lambda with PostgreSQL..."

# Build the Lambda function
echo "📦 Building Swift Lambda function..."
swift package --disable-sandbox archive --allow-network-connections docker

# Deploy with SAM
echo "🌩️  Deploying with SAM..."
sam deploy

echo "✅ Deployment complete!"
echo ""
echo "📋 To get the database connection details, run:"
echo "aws cloudformation describe-stacks --stack-name servicelifecycle-stack --query 'Stacks[0].Outputs'"
echo ""
echo "🧪 To test the Lambda function:"
echo "curl \$(aws cloudformation describe-stacks --stack-name servicelifecycle-stack --query 'Stacks[0].Outputs[?OutputKey==\`APIGatewayEndpoint\`].OutputValue' --output text)"
