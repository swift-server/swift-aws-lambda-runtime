#!/bin/sh

alias aws="aws --profile seb"

echo "This script deletes the Lambda function and the IAM role created in the previous step and deletes the project files."
read -p "Are you you sure you want to delete everything that was created? [y/n] " continue
if [[ ! $continue =~ ^[Yy]$ ]]; then
  echo "OK, try again later when you feel ready"
  exit 1
fi

echo "🚀 Deleting the Lambda function and the role"
aws lambda delete-function --function-name MyLambda
aws iam detach-role-policy            \
    --role-name lambda_basic_execution \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name lambda_basic_execution

echo "🚀 Deleting the project files"
rm -rf .build
rm -rf ./Sources
rm trust-policy.json
rm Package.swift Package.resolved

echo "🎉 Done! Your project is cleaned up and ready for a fresh start."