#!/bin/bash
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


if [[ -f .swiftformatignore ]]; then
    log "Found swiftformatignore file..."

    log "Running swift format format..."
    tr '\n' '\0' < .swiftformatignore| xargs -0 -I% printf '":(exclude)%" '| xargs git ls-files -z '*.swift' | xargs -0 swift format format --parallel --in-place

    log "Running swift format lint..."

    tr '\n' '\0' < .swiftformatignore | xargs -0 -I% printf '":(exclude)%" '| xargs git ls-files -z '*.swift' | xargs -0 swift format lint --strict --parallel
else
    log "Running swift format format..."
    git ls-files -z '*.swift' | xargs -0 swift format format --parallel --in-place

    log "Running swift format lint..."

    git ls-files -z '*.swift' | xargs -0 swift format lint --strict --parallel
fi



log "Checking for modified files..."

GIT_PAGER='' git diff --exit-code '*.swift'

log "✅ Found no formatting issues."
