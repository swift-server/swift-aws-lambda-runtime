#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftAWSLambdaRuntime open source project
##
## Copyright SwiftAWSLambdaRuntime project authors
## Copyright (c) Amazon.com, Inc. or its affiliates.
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2024 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0 with Runtime Library Exception
##
## See https://swift.org/LICENSE.txt for license information
## See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
##
##===----------------------------------------------------------------------===##

set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

if [ ! -f .spi.yml ]; then
  log "No '.spi.yml' found, no documentation targets to check."
  exit 0
fi

if ! command -v yq &> /dev/null; then
  fatal "yq could not be found. Please install yq to proceed."
fi

package_files=$(find . -maxdepth 1 -name 'Package*.swift')
if [ -z "$package_files" ]; then
  fatal "Package.swift not found. Please ensure you are running this script from the root of a Swift package."
fi

# yq 3.1.0-3 doesn't have filter, otherwise we could replace the grep call with "filter(.identity == "swift-docc-plugin") | keys | .[]"
hasDoccPlugin=$(swift package dump-package | yq -r '.dependencies[].sourceControl' | grep -e "\"identity\": \"swift-docc-plugin\"" || true)
if [[ -n $hasDoccPlugin ]]
then
    log "swift-docc-plugin already exists"
else
    log "Appending swift-docc-plugin"
    for package_file in $package_files; do
      log "Editing $package_file..."
      cat <<EOF >> "$package_file"

package.dependencies.append(
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0")
)
EOF
    done
fi

log "Checking documentation targets..."
for target in $(yq -r '.builder.configs[].documentation_targets[]' .spi.yml); do
  log "Checking target $target..."
  # shellcheck disable=SC2086 # We explicitly want to explode "$ADDITIONAL_DOCC_ARGUMENTS" into multiple arguments.
  swift package plugin generate-documentation --target "$target" --warnings-as-errors --analyze $ADDITIONAL_DOCC_ARGUMENTS
done

log "✅ Found no documentation issues."