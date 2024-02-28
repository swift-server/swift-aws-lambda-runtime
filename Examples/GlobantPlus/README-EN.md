# Tech Talk: AWS Lambda with Swift

This is the repository with all the code shown in the Tech Talk by [Globant](https://www.globant.com/) where we talked about using the Swift language to develop Amazon Web Services Lambdas.

## Organization

Inside this repository you will find the following projects

* **App** folder
    * **GlobantPlus**. It is the tvOS application developed as a guide in the talk. It calls the Lambdas that store the user's favorites and tracking while using the application.
* Lambdas folder
    * **AWSLambdaBasic** The most basic Lambda.
    * **AWSLambdaBackend** Handles `POST` and `DELETE` events received by AWS API Gateway and inserts them into a DynamoDB database.
    * **AWSLambdaTracking** Receives an event from an AWS SQS message queue.
    * **AWSMultipleFunctions** Multiple Lambdas inside the same Swift Package.


## Preparing the GlobantPlus app

To be able to compile and run the GlobantPlus application, a project configuration file (`.xcconfig`) is required which will contain the user account data for The Movie Database and the identity keys created for our Amazon Web Services user.

```xcconfig
TMDB_API_KEY = [API Key para Movie Database ]
TMDB_API_AUTH_KEY = [Tu AUTH KEY de The Movie Database]

AWS_ACCESS_KEY_ID = [Tu clave de acceso de AWS]
AWS_SECRET_ACCESS_KEY = [Clave secreta de acceso a AWS]

AWS_SQS_QUEUE_URL = [URL de la cola de mensajes SQS]
AWS_API_GATEWAY_URL = [URL base de AWS API Gateway]
```

After adding the file, you must set it to be used by the Debug and Release environments.

![Xcode-xcconfig](https://github.com/fitomad/TechTalk-AWS-Lamba-Swift/raw/main/Documentation/Images/XCConfig-Xcode.png)

### The Movie Database

You need to have a user on [themoviedb.org](https://www.themoviedb.org/).

To get your API credentials, go to User > Settings > API and copy the values from the **API Key (v3 auth)** and **Read Access Token for the API (v4 auth)** sections.

![TMDB](https://github.com/fitomad/TechTalk-AWS-Lamba-Swift/raw/main/Documentation/Images/tmdb.png)

## AWS Access Keys

Click on your user avatar and then on Security Credentials. Once there, go to the **Access keys** section and create the keys.

## Documentation

In the **Documentation** folder inside this repository, you will find details about some aspects discussed during the talk.

## Contact

* **GitHub**: [fitomad](https://github.com/fitomad)
* **LinkedIn**: [www.linkedin.com/in/adolfo-vera](www.linkedin.com/in/adolfo-vera)