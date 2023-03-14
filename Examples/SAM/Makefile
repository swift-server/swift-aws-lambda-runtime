build:
	swift build

update: 
	swift package update

testlambda:
	swift test

test:
	(cd ../.. && swift test --filter AWSLambdaDeploymentDescriptor)

release:
	swift build -c release

archive: build
	swift package --disable-sandbox archive

deploy: build
	swift package --disable-sandbox deploy --configuration debug 

nodeploy: build
	swift package --disable-sandbox deploy --verbose --nodeploy --configuration debug 

localtest:
	sam local invoke -t sam.yaml -e Tests/LambdaTests/data/apiv2.json HttpApiLambda 

list: 
	sam list endpoints -t sam.yaml --stack-name swift-aws-lambda-runtime-example --output json

logs:
	sam logs --stack-name swift-aws-lambda-runtime-example  

logstail:
	sam logs --stack-name swift-aws-lambda-runtime-example -t 

delete:
	sam delete --stack-name swift-aws-lambda-runtime-example 
	
clean:
	# find . -name .build -exec rm -rf {} \;
	# find . -name .swiftpm -exec rm -rf {} \;
	# find . -name dist -exec rm -rf {} \;
	rm -rf ../../.build 
	rm -rf .build

test-generate:
	/usr/bin/swift \
		-L ../../.build/debug  \
		-I ../../.build/debug \
		-lAWSLambdaDeploymentDescriptor \
		./Deploy.swift
