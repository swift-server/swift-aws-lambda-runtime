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

sudo apt update && sudo apt -y upgrade

# Install Swift 6.0.3
sudo apt-get -y install \
          binutils \
          git \
          gnupg2 \
          libc6-dev \
          libcurl4-openssl-dev \
          libedit2 \
          libgcc-13-dev \
          libncurses-dev \
          libpython3-dev \
          libsqlite3-0 \
          libstdc++-13-dev \
          libxml2-dev \
          libz3-dev \
          pkg-config \
          tzdata \
          unzip \
          zip \
          zlib1g-dev

wget https://download.swift.org/swift-6.0.3-release/ubuntu2404-aarch64/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE-ubuntu24.04-aarch64.tar.gz

tar xfvz swift-6.0.3-RELEASE-ubuntu24.04-aarch64.tar.gz

export PATH=/home/ubuntu/swift-6.0.3-RELEASE-ubuntu24.04-aarch64/usr/bin:"${PATH}"

swift --version

# Install Docker
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add the current user to the docker group
sudo usermod -aG docker "$USER"

# LOGOUT and LOGIN to apply the changes
exit

# reconnect with ssh 

export PATH=/home/ubuntu/swift-6.0.3-RELEASE-ubuntu24.04-aarch64/usr/bin:"${PATH}"

# clone a project 
git clone https://github.com/swift-server/swift-aws-lambda-runtime.git

# build the project
cd swift-aws-lambda-runtime/Examples/ResourcesPackaging/
LAMBDA_USE_LOCAL_DEPS=../.. swift package archive --allow-network-connections docker                                      
