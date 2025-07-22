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

# For testing purposes, this script sets up a local PostgreSQL database using Docker.

# Create a named volume for PostgreSQL data
docker volume create pgdata

# Run PostgreSQL container with the volume mounted
docker run -d \
  --name postgres-db \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=test \
  -p 5432:5432 \
  -v pgdata:/var/lib/postgresql/data \
  postgres:latest

# Stop the container
docker stop postgres-db

# Start it again (data persists)
docker start postgres-db

# Connect to the database using psql in a new container
docker run -it --rm --network host \
  -e PGPASSWORD=secret \
  postgres:latest \
  psql -h localhost -U postgres -d servicelifecycle

# Alternative: Connect using the postgres-db container itself
docker exec -it postgres-db psql -U postgres -d servicelifecycle

