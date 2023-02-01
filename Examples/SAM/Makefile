build:
	swift build

update: 
	swift package update

test:
	swift test

release:
	swift build -c release

archive: build
	swift package --disable-sandbox archive

deploy: build
	swift package --disable-sandbox deploy --configuration debug 

nodeploy: build
	swift package --disable-sandbox deploy --verbose --nodeploy --configuration debug 

clean:
	# find . -name .build -exec rm -rf {} \;
	# find . -name .swiftpm -exec rm -rf {} \;
	# find . -name dist -exec rm -rf {} \;
	rm -rf ../../.build 
	rm -rf .build

test-generate:
	/usr/bin/swift \
		-L .build/debug  \
		-I .build/debug \
		-lAWSLambdaDeploymentDescriptor \
		./Deploy.swift
