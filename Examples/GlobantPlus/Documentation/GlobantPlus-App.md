# GlobantPlus - El servicio ficticio de Streaming de Globant

Esta app sirve como hilo conductor a la hora de mostrar el uso de Swift para desarrollar AWS Lambdas y como podemos usarlas desde aplicaciones desarrolladas para dispositivos Apple, en este caso para un AppleTV.

## ¿Qué es GlobantPlus?

Es una aplicación para tvOS que muestra el catálago del servicio ficticio de streaming de Globant.

Sólo tiene dos escenas, un dashboard donde se pueden ver las tendencias de series, películas y documentales, y una vista detallada de las series.

Hay que tener en cuenta que la finalidad de la aplicación es mostrar el uso de los servicios de AWS desde una app, por lo que aspector como la inyección de dependencias, o la creación de la sesión AWS del framework Soto se han adaptado para mostrar con mayor claridad el flujo de trabajo con esos servicios.

## Servicios AWS

Los servicios AWS que vamos a usar desde la app son los siguientes:

* **AWS API Gateway**: Cuando añadamos o eliminemos una serie de nuestros *Favoritos* invocaremos un endpoint definido en el API Gateway. El código se puede encontrar en `GlobantPlus > Data > Network > AmazonAPI`

* **AWS SQS**: Para obtener un seguimiento de la actividad del usuario dentro de al aplicación enviaremos los datos al servicio de cola de mensajes de AWS. El código se puede encontrar en `GlobantPlus > Data > Queues > AmazonSQS`

## Frameworks

Para poder trabajar con los servicios de AWS se usa el paquete [Soto](https://github.com/soto-project/soto).

## Contacto

* [GitHub](https://github.com/fitomad)
* [LinkedIn](https://www.linkedin.com/in/adolfo-vera)