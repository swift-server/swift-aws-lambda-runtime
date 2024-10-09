#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftAWSLambdaRuntime open source project
##
## Copyright (c) 2017-2018 Apple Inc. and the SwiftAWSLambdaRuntime project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

# set +x -e

# for EXAMPLE in $(find Examples -type d -d 1);
# do
# 	echo "Building $EXAMPLE"
# 	pushd $EXAMPLE
# 	LAMBDA_USE_LOCAL_DEPS=../.. swift build
# 	popd
# done 

set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

test -n "${SWIFT_VERSION:-}" || fatal "SWIFT_VERSION unset"
test -n "${COMMAND:-}" || fatal "COMMAND unset"
test -n "${EXAMPLE:-}" || fatal "EXAMPLE unset"
swift_version="$SWIFT_VERSION"
command="$COMMAND"
command_nightly_6_0="$COMMAND_OVERRIDE_NIGHTLY_6_0"
command_nightly_main="$COMMAND_OVERRIDE_NIGHTLY_MAIN"
example="$EXAMPLE"

if [[ "$swift_version" == "nightly-6.0" ]] && [[ -n "$command_nightly_6_0" ]]; then
  log "Running nightly 6.0 command override"
  eval "$command_nightly_6_0"
elif [[ "$swift_version" == "nightly-main" ]] && [[ -n "$command_nightly_main" ]]; then
  log "Running nightly main command override"
  eval "$command_nightly_main"
else
  log "Running default command"
  eval "$command"
fi
