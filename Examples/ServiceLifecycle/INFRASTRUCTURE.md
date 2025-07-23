# Infrastructure Architecture

This document describes the AWS infrastructure deployed by the ServiceLifecycle example's SAM template.

## Overview

The infrastructure consists of a secure VPC setup with public and private subnets, a PostgreSQL RDS instance in private subnets, and a Lambda function with VPC access. The architecture follows AWS best practices for security and network isolation.

## Network Architecture

### VPC Configuration
- **VPC**: Custom VPC with CIDR block `10.0.0.0/16`
- **DNS Support**: DNS hostnames and DNS resolution enabled

### Subnet Layout
- **Public Subnets**:
  - Public Subnet 1: `10.0.1.0/24` (AZ 1)
  - Public Subnet 2: `10.0.2.0/24` (AZ 2)
  - Used for Lambda functions and NAT Gateway
  - Auto-assign public IP addresses enabled

- **Private Subnets**:
  - Private Subnet 1: `10.0.3.0/24` (AZ 1)
  - Private Subnet 2: `10.0.4.0/24` (AZ 2)
  - Used for RDS PostgreSQL database
  - No public IP addresses assigned

### Network Components
- **Internet Gateway**: Provides internet access for public subnets
- **NAT Gateway**: Deployed in Public Subnet 1, allows private subnets to access the internet
- **Route Tables**:
  - Public Route Table: Routes traffic to the Internet Gateway
  - Private Route Table: Routes traffic through the NAT Gateway

## Security Groups

### Lambda Security Group
- **Outbound Rules**:
  - PostgreSQL (5432): Restricted to VPC CIDR `10.0.0.0/16`
  - HTTPS (443): Open to `0.0.0.0/0` for AWS service access

### Database Security Group
- **Inbound Rules**:
  - PostgreSQL (5432): Only allows connections from the Lambda Security Group

## Database Configuration

### PostgreSQL RDS Instance
- **Instance Type**: `db.t3.micro` (cost-optimized)
- **Engine**: PostgreSQL 15.7
- **Storage**: 20GB GP2 (SSD)
- **Network**: Deployed in private subnets with no public access
- **Security**:
  - Storage encryption enabled
  - SSL/TLS connections supported
  - Credentials stored in AWS Secrets Manager
- **High Availability**: Multi-AZ disabled (development configuration)
- **Backup**: Automated backups disabled (development configuration)

### Database Subnet Group
- Spans both private subnets for availability

## Lambda Function Configuration

### Service Lifecycle Lambda
- **Runtime**: Custom runtime (provided.al2)
- **Architecture**: ARM64
- **Memory**: 512MB
- **Timeout**: 60 seconds
- **Network**: Deployed in public subnets with access to both internet and private resources
- **Environment Variables**:
  - `LOG_LEVEL`: trace
  - `DB_HOST`: RDS endpoint address
  - `DB_USER`: Retrieved from Secrets Manager
  - `DB_PASSWORD`: Retrieved from Secrets Manager
  - `DB_NAME`: Database name from parameter

## API Gateway

- **Type**: HTTP API
- **Integration**: Direct Lambda integration
- **Authentication**: None (for demonstration purposes)

## Secrets Management

### Database Credentials
- **Storage**: AWS Secrets Manager
- **Secret Name**: `{StackName}-db-credentials`
- **Content**:
  - Username: "postgres"
  - Password: Auto-generated 16-character password
  - Special characters excluded: `"@/\`

## SAM Outputs

The template provides several outputs to facilitate working with the deployed resources:

- **APIGatewayEndpoint**: URL to invoke the Lambda function
- **DatabaseEndpoint**: Hostname for the PostgreSQL instance
- **DatabasePort**: Port number for PostgreSQL (5432)
- **DatabaseName**: Name of the created database
- **DatabaseSecretArn**: ARN of the secret containing credentials
- **DatabaseConnectionInstructions**: Instructions for retrieving connection details
- **ConnectionDetails**: Consolidated connection information

## Security Considerations

This infrastructure implements several security best practices:

1. **Network Isolation**: Database is placed in private subnets with no direct internet access
2. **Least Privilege**: Security groups restrict traffic to only necessary ports and sources
3. **Encryption**: Database storage is encrypted at rest
4. **Secure Credentials**: Database credentials are managed through AWS Secrets Manager
5. **Secure Communication**: Lambda function connects to database over encrypted connections

## Cost Optimization

The template uses cost-effective resources suitable for development:

- `db.t3.micro` instance (eligible for free tier)
- Minimal storage allocation (20GB)
- No Multi-AZ deployment
- No automated backups

For production workloads, consider adjusting these settings based on your requirements.