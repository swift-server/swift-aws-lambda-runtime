# Tech Talk: AWS Lambda con Swift

Este es el repositorio con todo el código mostrado en la Tech Talk de [Globant](https://www.globant.com/) en que hablamos sobre el uso del lenguaje Swift para desarrollar Amazon Web Services Lambdas.

## Organización

Dentro de este repositorio encontrarás los siguientes proyectos

* Carpeta **App**
    * **GlobantPlus**. Es la aplicación desarrollada para tvOS que sirve de guía en la charla. Hace las llamadas a las Lambdas que almacenan los favoritos y el tracking del usuario mientras usa la aplicación
* Carpeta **Lambdas**
    * **AWSLambdaBasic** La Lambda más básica.
    * **AWSLambdaBackend** Se encanrga de los eventos `POST` y `DELETE` recibidos por AWS API Gateway y los inserta en una base de datos DynamoDB
    * **AWSLambdaTracking** Recibe un evento de una cola de mensaje AWS SQS.
    * **AWSMultipleFunctions** Varias Lambdas dentro de un mismo Swift Package.

## Preparar la app GlobantPlus

Para poder compilar y ejecutar la aplicación GlobantPlus es necesario un archivo de configuración de proyecto (`.xcconfig`) que contendrá los datos de cuentas de usuario para The Movie Database y las claves de identidad creadas para nuestro usuario de Amazon Web Services

```xcconfig
TMDB_API_KEY = [API Key para Movie Database ]
TMDB_API_AUTH_KEY = [Tu AUTH KEY de The Movie Database]

AWS_ACCESS_KEY_ID = [Tu clave de acceso de AWS]
AWS_SECRET_ACCESS_KEY = [Clave secreta de acceso a AWS]

AWS_SQS_QUEUE_URL = [URL de la cola de mensajes SQS]
AWS_API_GATEWAY_URL = [URL base de AWS API Gateway]
```

Tras añadir el archivo debe establecer que los entornos de **Debug** y **Release** lo usen

![Xcode-xcconfig](https://github.com/fitomad/TechTalk-AWS-Lamba-Swift/raw/main/Documentation/Images/XCConfig-Xcode.png)

### The Movie Database

Necesitas tener un usuario en [themoviedb.org](https://www.themoviedb.org/).

Para conseguir tus credenciales de API debes dirigirte a Usuario > Configuración > API y copiar
los valores de las sección **Clave de la API (v3 auth)** y **Token de acceso de lectura a la API (v4 auth)**

![TMDB](https://github.com/fitomad/TechTalk-AWS-Lamba-Swift/raw/main/Documentation/Images/tmdb.png)

# Access Keys de AWS

Debes pulsar sobre tu avatar de usuario y luego Credenciales de seguridad. Una vez allí dirígite a la sección **Claves de acceso** y crea las claves.

## Documentación

En la carpeta **Documentación** dentro de este repositorio encontraréis detalles sobre algunos aspectos comentados durante la charla.

## Contacto

* **GitHub**: [fitomad](https://github.com/fitomad)
* **LinkedIn**: [www.linkedin.com/in/adolfo-vera](www.linkedin.com/in/adolfo-vera)
