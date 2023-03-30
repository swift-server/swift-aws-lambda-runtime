# Compiling Lambdas with Swift

We must open the **Console** application and navigate to the folder with the Swift Package that we want to compile and generate its package, then execute the following command

```zsh
swift package --disable-sandbox archive 
```

If we want the package to be generated in a specific path, we should use the `--output-path` parameter.

```zsh
swift package --disable-sandbox archive --output-path /Users/JohnAppleseed/Desktop --verbose 2
```

The verbose parameter sets the level of detail of the log that appears on the screen with the result of the operation.

For more detailed information on the parameters accepted by the new archive command, visit the [Deploy to AWS Lambda](https://github.com/swift-server/swift-aws-lambda-runtime#deploying-to-aws-lambda) section of the [Swift AWS Lambda runtime](https://github.com/swift-server/swift-aws-lambda-runtime) project.

## Preparations

Since AWS Lambda functions run on an [Amazon Linux 2](https://aws.amazon.com/es/amazon-linux-2/?amazon-linux-whats-new.sort-by=item.additionalFields.postDateTime&amazon-linux-whats-new.sort-order=desc) system, packaging Lambda functions involves compiling the source code in a Docker image of that operating system.

![Docker con Amazon Linux 2](https://github.com/fitomad/TechTalk-AWS-Lamba-Swift/raw/main/Documentation/Images/Docker.png)

Thanks to the `archive` plugin present since version 1 of the **Swift AWS Lambda runtime**, the management of this image is done transparently for us. We only need to have the Docker client installed and running while we compile and package.

## Operation result

Once the package has been generated, we can upload our Lambda function to AWS. To do this, we must go to the folder where we indicated the package should be generated and select the `zip` file.

![Terminal-Empaquetado](https://github.com/fitomad/TechTalk-AWS-Lamba-Swift/raw/main/Documentation/Images/Lambda-Paquete.png)

## Contact

* [GitHub](https://github.com/fitomad)
* [LinkedIn](https://www.linkedin.com/in/adolfo-vera)