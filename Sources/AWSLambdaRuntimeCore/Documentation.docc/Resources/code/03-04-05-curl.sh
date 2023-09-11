curl --header "Content-Type: application/json" \
     --request POST                            \
     --data '{"number": 3}'                    \
     http://localhost:7000/invoke

{"result":9}
