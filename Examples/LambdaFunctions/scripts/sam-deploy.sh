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

DIR="$(cd "$(dirname "$0")" && pwd)"

executables=( $(swift package dump-package | sed -e 's|: null|: ""|g' | jq '.products[] | (select(.type.executable)) | .name' | sed -e 's|"||g') )

if [[ ${#executables[@]} = 0 ]]; then
    echo "no executables found"
    exit 1
elif [[ ${#executables[@]} = 1 ]]; then
    executable=${executables[0]}
elif [[ ${#executables[@]} > 1 ]]; then
    echo "multiple executables found:"
    for executable in ${executables[@]}; do
      echo "  * $executable"
    done
    echo ""
    read -p "select which executables to deploy: " executable
fi

echo -e "\ndeploying $executable"

echo "-------------------------------------------------------------------------"
echo "preparing docker build image"
echo "-------------------------------------------------------------------------"
docker build . -q -t builder

$DIR/build-and-package.sh ${executable}

echo "-------------------------------------------------------------------------"
echo "deploying using SAM"
echo "-------------------------------------------------------------------------"

sam deploy --template "${executable}-template.yml" $@
