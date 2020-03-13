#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftAWSLambdaRuntime open source project
##
## Copyright (c) 2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

# docker run --privileged -it -v `pwd`:/code -w /code swiftlang/swift:nightly-5.2-bionic bash

apt-get update -y
apt-get install -y vim htop strace linux-tools-common linux-tools-generic

echo 0 > /proc/sys/kernel/kptr_restrict

cd /usr/bin
rm -rf perf
ln -s /usr/lib/linux-tools/4.15.0-88-generic/perf perf
cd -

cd /opt
git clone https://github.com/brendangregg/FlameGraph.git
cd -

# build the code in relase mode with debug symbols
# swift build -c release -Xswiftc -g
#
# run the server
# (.build/release/MockServer) &
#
# strace
# export MAX_REQUESTS=10000
# strace -o .build/strace-c-string-$MAX_REQUESTS -c .build/release/StringSample
# strace -o .build/strace-ffftt-string-$MAX_REQUESTS -fftt .build/release/StringSample
#
# perf
# export MAX_REQUESTS=10000
# perf record -o .build/perf-$MAX_REQUESTS.data -g .build/release/StringSample dwarf
# perf script -i .build/perf-$MAX_REQUESTS.data | /opt/FlameGraph/stackcollapse-perf.pl | swift-demangle | /opt/FlameGraph/flamegraph.pl > .build/flamegraph-$MAX_REQUESTS.svg
