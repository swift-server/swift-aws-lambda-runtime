#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftAWSLambdaRuntime open source project
##
## Copyright (c) 2017-2024 Apple Inc. and the SwiftAWSLambdaRuntime project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

test -n "${EXAMPLE:-}" || fatal "EXAMPLE unset"

OUTPUT_DIR=.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager

pushd "Examples" || exit 1

# package the example (docker and swift toolchain are installed on the GH runner)
LAMBDA_USE_LOCAL_DEPS=.. swift package archive --product "${EXAMPLE}" --allow-network-connections docker || exit 1

# find the zip file in the OUTPUT_FILE directory
ZIP_FILE=$(find "${OUTPUT_DIR}" -type f -name "*.zip" | head -n 1)
OUTPUT_FILE=$(find "${OUTPUT_DIR}" -type f -name "bootstrap" | head -n 1)

# did the plugin generated a Linux binary?
[ -f "${OUTPUT_FILE}" ] || exit 1
file "${OUTPUT_FILE}" | grep --silent ELF || exit 1

# did the plugin created a ZIP file?
[ -f "${ZIP_FILE}" ] || exit 1

# does the ZIP file contain the bootstrap?
unzip -l "${ZIP_FILE}" | grep --silent bootstrap || exit 1

# if EXAMPLE is ResourcesPackaging, check if the ZIP file contains hello.txt
if [ "$EXAMPLE" == "ResourcesPackaging" ]; then
    echo "Checking if resource was added to the ZIP file"
    unzip -l "${ZIP_FILE}" | grep --silent hello.txt 
    SUCCESS=$?
    if [ "$SUCCESS" -eq 1 ]; then
        log "❌ Resource not found." && exit 1
    else
        log "✅ Resource found."
    fi
fi    

echo "✅ The archive plugin is OK with example ${EXAMPLE}"
popd || exit 1
