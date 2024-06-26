# GlobantPlus - Globant's Fictional Streaming Service

This app serves as a thread to showcase the use of Swift for developing AWS Lambdas and how we can use them from applications developed for Apple devices, in this case for an AppleTV.

## What is GlobantPlus?

It is an tvOS application that displays the catalog of Globant's fictional streaming service.

It has only two scenes, a dashboard where you can see trends in series, movies, and documentaries, and a detailed view of the series.

It is important to note that the purpose of the application is to showcase the use of AWS services from an app, so aspects such as dependency injection or the creation of the AWS session for the Soto framework have been adapted to better show the workflow with those services.

## AWS Services

The AWS services we are going to use from the app are the following:

* AWS API Gateway: When we add or remove a series from our *Favorites*, we will invoke an endpoint defined in the API Gateway. The code can be found in `GlobantPlus > Data > Network > AmazonAPI`.

* AWS SQS: To track user activity within the application, we will send data to the AWS message queue service. The code can be found in `GlobantPlus > Data > Queues > AmazonSQS`.

## Frameworks

To work with AWS services, we use the [Soto](https://github.com/soto-project/soto) package.

## Contact

* [GitHub](https://github.com/fitomad)
* [LinkedIn](https://www.linkedin.com/in/adolfo-vera)