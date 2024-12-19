#!/opt/homebrew/opt/node/bin/node
import * as cdk from 'aws-cdk-lib';
import { LambdaApiStack } from '../lib/lambda-api-project-stack';

const app = new cdk.App();
new LambdaApiStack(app, 'LambdaApiStack');
