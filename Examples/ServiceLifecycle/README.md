# ServiceLifecycle Lambda with PostgreSQL

This example demonstrates a Swift Lambda function that uses ServiceLifecycle to manage a PostgreSQL connection. The function connects to an RDS PostgreSQL database in private subnets and queries user data.

## Architecture

- **Swift Lambda Function**: Uses ServiceLifecycle to manage PostgreSQL client lifecycle, deployed in public subnets
- **PostgreSQL RDS**: Database instance in private subnets with SSL/TLS encryption
- **HTTP API Gateway**: HTTP endpoint to invoke the Lambda function
- **VPC**: Custom VPC with public subnets for Lambda/NAT Gateway and private subnets for RDS
- **Security**: SSL/TLS connections with RDS root certificate verification, secure networking with security groups
- **Timeout Handling**: 3-second timeout mechanism to prevent database connection hangs
- **Secrets Manager**: Secure credential storage and management

For detailed infrastructure information, see `INFRASTRUCTURE.md`.

## Implementation Details

The Lambda function demonstrates several key concepts:

1. **ServiceLifecycle Integration**: The PostgreSQL client and Lambda runtime are managed together using ServiceLifecycle, ensuring proper initialization and cleanup.

2. **SSL/TLS Security**: Connections to RDS use SSL/TLS with full certificate verification using region-specific RDS root certificates.

3. **Timeout Protection**: A custom timeout mechanism prevents the function from hanging when the database is unreachable (addresses PostgresNIO issue #489).

4. **Structured Response**: Returns a JSON array of `User` objects, making it suitable for API integration.

5. **Error Handling**: Comprehensive error handling for database connections, queries, and certificate loading.

## Prerequisites

- Swift 6.x toolchain
- Docker (for building Lambda functions)
- AWS CLI configured with appropriate permissions
- SAM CLI installed

## Database Schema

In the context of this demo, the Lambda function creates the table and populates it with data at first run.

The Lambda function expects a `users` table with the following structure and returns results as `User` objects:

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL
);

-- Insert some sample data
INSERT INTO users (username) VALUES ('alice'), ('bob'), ('charlie');
```

The Swift `User` model:
```swift
struct User: Codable {
    let id: Int
    let username: String
}
```

## Environment Variables

The Lambda function uses the following environment variables for database connection:
- `DB_HOST`: Database hostname (set by CloudFormation from RDS endpoint)
- `DB_USER`: Database username (retrieved from Secrets Manager)
- `DB_PASSWORD`: Database password (retrieved from Secrets Manager)
- `DB_NAME`: Database name (defaults to "test")
- `AWS_REGION`: AWS region for selecting the correct RDS root certificate

## Deployment

### Option 1: Using the deployment script

```bash
./deploy.sh
```

### Option 2: Manual deployment

1. **Build the Lambda function:**
   ```bash
   swift package archive --allow-network-connections docker
   ```

2. **Deploy with SAM:**
   ```bash
   sam deploy
   ```

## Getting Connection Details

After deployment, get the database and API Gateway connection details:

```bash
aws cloudformation describe-stacks \
  --stack-name servicelifecycle-stack \
  --query 'Stacks[0].Outputs'
```

The output will include:
- **DatabaseEndpoint**: Hostname to connect to
- **DatabasePort**: Port number (5432)
- **DatabaseName**: Database name
- **DatabaseUsername**: Username
- **DatabasePassword**: Password
- **DatabaseConnectionString**: Complete connection string

## Connecting to the Database

The database is deployed in **private subnets** and is **not directly accessible** from the internet. This follows AWS security best practices.

You may create an Amazon EC2 instance (virtual machine) in the public subnet of the VPC and use it as a jump host to connect to the database.  The SAM template doesn't create this for you. [This is left as an exercise to the reader](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/LaunchingAndUsingInstances.html).

You can access the database connection details in the output of the SAM template:

```bash
# Get the connection details from CloudFormation outputs
DB_HOST=$(aws cloudformation describe-stacks --stack-name servicelifecycle-stack --query 'Stacks[0].Outputs[?OutputKey==`DatabaseEndpoint`].OutputValue' --output text)
DB_PORT=$(aws cloudformation describe-stacks --stack-name servicelifecycle-stack --query 'Stacks[0].Outputs[?OutputKey==`DatabasePort`].OutputValue' --output text)
DB_NAME=$(aws cloudformation describe-stacks --stack-name servicelifecycle-stack --query 'Stacks[0].Outputs[?OutputKey==`DatabaseName`].OutputValue' --output text)

# Get the database password from Secrets Manager
SECRET_ARN=$(aws cloudformation describe-stacks --stack-name servicelifecycle-stack --query 'Stacks[0].Outputs[?OutputKey==`DatabaseSecretArn`].OutputValue' --output text)
DB_USERNAME=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query 'SecretString' --output text | jq -r '.username')
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query 'SecretString' --output text | jq -r '.password')

# Connect with psql on Amazon EC2
psql -h "$DB_HOST:$DB_PORT" -U "$DB_USER" -d "$DB_NAME"
```

## Testing the Lambda Function

Get the API Gateway endpoint and test the function:

```bash
# Get the API endpoint
API_ENDPOINT=$(aws cloudformation describe-stacks --stack-name servicelifecycle-stack --query 'Stacks[0].Outputs[?OutputKey==`APIGatewayEndpoint`].OutputValue' --output text)

# Test the function
curl "$API_ENDPOINT"
```

The function will:
1. Connect to the PostgreSQL database using SSL/TLS with RDS root certificate verification
2. Query the `users` table with a 3-second timeout to prevent hanging
3. Log the results for each user found
4. Return a JSON array of `User` objects with `id` and `username` fields

Example response:
```json
[
  {"id": 1, "username": "alice"},
  {"id": 2, "username": "bob"},
  {"id": 3, "username": "charlie"}
]
```

## Monitoring

Check the Lambda function logs:

```bash
sam logs -n ServiceLifecycleLambda --stack-name servicelifecycle-stack --tail
```

## Security Considerations

✅ **Security Best Practices Implemented**:

This example follows AWS security best practices:

1. **Private Database**: Database is deployed in private subnets with no internet access
2. **Network Segmentation**: Separate public and private subnets with proper routing
3. **Security Groups**: Restrictive security groups following least privilege principle
4. **Secrets Management**: Database credentials stored in AWS Secrets Manager
5. **Encryption**: SSL/TLS for database connections with certificate verification
6. **VPC Endpoints**: Administrative access through SSM VPC endpoints

The infrastructure implements secure networking patterns suitable for production workloads.

## Cost Optimization

The template uses:
- `db.t3.micro` instance (eligible for free tier)
- Minimal storage allocation (20GB)
- No Multi-AZ deployment
- No automated backups

For production workloads, adjust these settings based on your requirements.

## Cleanup

To delete all resources:

```bash
sam delete --stack-name servicelifecycle-stack
```

## SSL Certificate Support

This example includes RDS root certificates for secure SSL/TLS connections. Currently supported regions:
- `us-east-1`: US East (N. Virginia)
- `eu-central-1`: Europe (Frankfurt)

To add support for additional regions:
1. Download the appropriate root certificate from [AWS RDS SSL documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html)
2. Create a new Swift file in `Sources/RDSCertificates/` with the certificate PEM data
3. Add the region mapping to `rootRDSCertificates` dictionary in `RootRDSCert.swift`

## Troubleshooting

when deploying with SAM and the `template.yaml` file included in this example, there shouldn't be any error. However, when you try to create such infarstructure on your own or using different infrastructure as code (IaC) tools, it's likely to iterate before getting everything configured. We compiled a couple of the most common configuration errors and their solution:

### Lambda can't connect to database

1. Check security groups allow traffic on port 5432 between Lambda and RDS security groups
2. Verify the Lambda function is deployed in subnets with proper routing to private subnets
3. Check VPC configuration and routing tables
4. Verify database credentials are correctly retrieved from Secrets Manager and that the Lambda execution policies have permissions to read the secret.
5. Ensure the RDS instance is running and healthy

### Database connection timeout

The PostgreSQL client may freeze if the database is unreachable. This example implements a 3-second timeout mechanism to prevent this issue. If the connection or query takes longer than 3 seconds, the function will timeout and return an empty array. Ensure:
1. Database is running and accessible
2. Security groups are properly configured
3. Network connectivity is available
4. SSL certificates are properly configured for your AWS region

### Build failures

Ensure you have:
1. Swift 6.x toolchain installed
2. Docker running
3. Proper network connectivity for downloading dependencies
4. All required dependencies: PostgresNIO, AWSLambdaRuntime, and ServiceLifecycle

## Files

- `template.yaml`: SAM template defining all AWS resources
- `INFRASTRUCTURE.md`: Detailed infrastructure architecture documentation
- `samconfig.toml`: SAM configuration file
- `deploy.sh`: Deployment script
- `Sources/Lambda.swift`: Swift Lambda function code with ServiceLifecycle integration
- `Sources/Timeout.swift`: Timeout utility to prevent database connection hangs
- `Sources/RDSCertificates/RootRDSCert.swift`: RDS root certificate management
- `Sources/RDSCertificates/us-east-1.swift`: US East 1 region root certificate
- `Sources/RDSCertificates/eu-central-1.swift`: EU Central 1 region root certificate
- `Package.swift`: Swift package definition with PostgresNIO, AWSLambdaRuntime, and ServiceLifecycle dependencies
