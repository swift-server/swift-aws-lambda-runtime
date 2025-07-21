# ServiceLifecycle Lambda with PostgreSQL

This example demonstrates a Swift Lambda function that uses ServiceLifecycle to manage a PostgreSQL connection. The function connects to a publicly accessible RDS PostgreSQL database and queries user data.

## Architecture

- **Swift Lambda Function**: Uses ServiceLifecycle to manage PostgreSQL client lifecycle
- **PostgreSQL RDS**: Publicly accessible database instance
- **API Gateway**: HTTP endpoint to invoke the Lambda function
- **VPC**: Custom VPC with public subnets for RDS and Lambda

## Prerequisites

- Swift 6.x toolchain
- Docker (for building Lambda functions)
- AWS CLI configured with appropriate permissions
- SAM CLI installed

## Database Schema

The Lambda function expects a `users` table with the following structure:

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL
);

-- Insert some sample data
INSERT INTO users (username) VALUES ('alice'), ('bob'), ('charlie');
```

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

### Option 3: Deploy with custom parameters

```bash
sam deploy --parameter-overrides \
  DBUsername=myuser \
  DBPassword=MySecurePassword123! \
  DBName=mydatabase
```

## Getting Connection Details

After deployment, get the database connection details:

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

### Using psql

```bash
# Get the connection details from CloudFormation outputs
DB_HOST=$(aws cloudformation describe-stacks --stack-name servicelifecycle-stack --query 'Stacks[0].Outputs[?OutputKey==`DatabaseEndpoint`].OutputValue' --output text)
DB_USER=$(aws cloudformation describe-stacks --stack-name servicelifecycle-stack --query 'Stacks[0].Outputs[?OutputKey==`DatabaseUsername`].OutputValue' --output text)
DB_NAME=$(aws cloudformation describe-stacks --stack-name servicelifecycle-stack --query 'Stacks[0].Outputs[?OutputKey==`DatabaseName`].OutputValue' --output text)
DB_PASSWORD=$(aws cloudformation describe-stacks --stack-name servicelifecycle-stack --query 'Stacks[0].Outputs[?OutputKey==`DatabasePassword`].OutputValue' --output text)

# Connect with psql
psql -h $DB_HOST -U $DB_USER -d $DB_NAME
```

### Using connection string

```bash
# Get the complete connection string
CONNECTION_STRING=$(aws cloudformation describe-stacks --stack-name servicelifecycle-stack --query 'Stacks[0].Outputs[?OutputKey==`DatabaseConnectionString`].OutputValue' --output text)

# Connect with psql
psql "$CONNECTION_STRING"
```

## Setting up the Database

Once connected to the database, create the required table and sample data:

```sql
-- Create the users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL
);

-- Insert sample data
INSERT INTO users (username) VALUES 
    ('alice'), 
    ('bob'), 
    ('charlie'),
    ('diana'),
    ('eve');
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
1. Connect to the PostgreSQL database
2. Query the `users` table
3. Log the results
4. Return "Done"

## Monitoring

Check the Lambda function logs:

```bash
sam logs -n ServiceLifecycleLambda --stack-name servicelifecycle-stack --tail
```

## Security Considerations

⚠️ **Important**: This example creates a publicly accessible PostgreSQL database for demonstration purposes. In production:

1. **Use private subnets** and VPC endpoints
2. **Implement proper authentication** (IAM database authentication)
3. **Use AWS Secrets Manager** for password management
4. **Enable encryption** at rest and in transit
5. **Configure proper security groups** with minimal required access
6. **Enable database logging** and monitoring

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

## Troubleshooting

### Lambda can't connect to database

1. Check security groups allow traffic on port 5432
2. Verify the database is publicly accessible
3. Check VPC configuration and routing
4. Verify database credentials in environment variables

### Database connection timeout

The PostgreSQL client may freeze if the database is unreachable. This is a known issue with PostgresNIO. Ensure:
1. Database is running and accessible
2. Security groups are properly configured
3. Network connectivity is available

### Build failures

Ensure you have:
1. Swift 6.x toolchain installed
2. Docker running
3. Proper network connectivity for downloading dependencies

## Files

- `template.yaml`: SAM template defining all AWS resources
- `samconfig.toml`: SAM configuration file
- `deploy.sh`: Deployment script
- `Sources/Lambda.swift`: Swift Lambda function code
- `Sources/RootRDSCert.swift`: RDS root certificate for SSL connections
- `Package.swift`: Swift package definition
