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

set -eu

export HOST=127.0.0.1
export PORT=3000
export AWS_LAMBDA_RUNTIME_API="$HOST:$PORT"
export LOG_LEVEL=warning # important, otherwise log becomes a bottleneck

# using gdate on mdarwin for nanoseconds
if [[ $(uname -s) == "Linux" ]]; then
  shopt -s expand_aliases
  alias gdate="date"
fi

swift build -c release -Xswiftc -g

cleanup() {
  kill -9 $server_pid
}

trap "cleanup" ERR

cold_iterations=1000
warm_iterations=10000
results=()

#------------------
# string
#------------------

export MODE=string

# start (fork) mock server
pkill -9 MockServer && echo "killed previous servers" && sleep 1
echo "starting server in $MODE mode"
(./.build/release/MockServer) &
server_pid=$!
sleep 1
kill -0 $server_pid # check server is alive

# cold start
echo "running $MODE mode cold test"
cold=()
export MAX_REQUESTS=1
for (( i=0; i<$cold_iterations; i++ )); do
  start=$(gdate +%s%N)
  ./.build/release/StringSample
  end=$(gdate +%s%N)
  cold+=( $(($end-$start)) )
done
sum_cold=$(IFS=+; echo "$((${cold[*]}))")
avg_cold=$(($sum_cold/$cold_iterations))
results+=( "$MODE, cold: $avg_cold (ns)" )

# normal calls
echo "running $MODE mode warm test"
export MAX_REQUESTS=$warm_iterations
start=$(gdate +%s%N)
./.build/release/StringSample
end=$(gdate +%s%N)
sum_warm=$(($end-$start-$avg_cold)) # substract by avg cold since the first call is cold
avg_warm=$(($sum_warm/($warm_iterations-1))) # substract since the first call is cold
results+=( "$MODE, warm: $avg_warm (ns)" )

#------------------
# JSON
#------------------

export MODE=json

# start (fork) mock server
pkill -9 MockServer && echo "killed previous servers" && sleep 1
echo "starting server in $MODE mode"
(./.build/release/MockServer) &
server_pid=$!
sleep 1
kill -0 $server_pid # check server is alive

# cold start
echo "running $MODE mode cold test"
cold=()
export MAX_REQUESTS=1
for (( i=0; i<$cold_iterations; i++ )); do
  start=$(gdate +%s%N)
  ./.build/release/CodableSample
  end=$(gdate +%s%N)
  cold+=( $(($end-$start)) )
done
sum_cold=$(IFS=+; echo "$((${cold[*]}))")
avg_cold=$(($sum_cold/$cold_iterations))
results+=( "$MODE, cold: $avg_cold (ns)" )

# normal calls
echo "running $MODE mode warm test"
export MAX_REQUESTS=$warm_iterations
start=$(gdate +%s%N)
./.build/release/CodableSample
end=$(gdate +%s%N)
sum_warm=$(($end-$start-$avg_cold)) # substract by avg cold since the first call is cold
avg_warm=$(($sum_warm/($warm_iterations-1))) # substract since the first call is cold
results+=( "$MODE, warm: $avg_warm (ns)" )

# print results
echo "-----------------------------"
echo "results"
echo "-----------------------------"
for i in "${results[@]}"; do
   echo $i
done
echo "-----------------------------"

# cleanup
cleanup
