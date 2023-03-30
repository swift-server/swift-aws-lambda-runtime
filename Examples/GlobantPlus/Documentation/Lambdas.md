# Compilación de Lambas con Swift

Debemos abrir la aplicación **Terminal** y situarnos en la carpeta con el Swift Package que queremos compilar y generar su paquete y ejecutar el siguiente comando.

```zsh
swift package --disable-sandbox archive 
```

Si queremos que el empaquetedo se genere en una ruta determinada se debe usar el parámetro `--output-path`

```zsh
swift package --disable-sandbox archive --output-path /Users/JohnAppleseed/Desktop --verbose 2
```

El parámetro `verbose` establece el nivel de detalle del log que sale por pantalla con el resultado de la operación

Para una información más detallada sobre los parámetros que acepta el nuevo comando `archive` visita la sección [Deploy to AWS Lambda](https://github.com/swift-server/swift-aws-lambda-runtime#deploying-to-aws-lambda) del proyecto [Swift AWS Lambda runtime](https://github.com/swift-server/swift-aws-lambda-runtime)

## Preparativos previos

Debido a que las funciones AWS Lambda se ejecutan sobre un sistema [Amazon Linux 2](https://aws.amazon.com/es/amazon-linux-2/?amazon-linux-whats-new.sort-by=item.additionalFields.postDateTime&amazon-linux-whats-new.sort-order=desc), el empaquetado de las funciones Lambda se hace compilando el código fuente en una imagen Docker de dicho sistema operativo.

![Docker con Amazon Linux 2](https://github.com/fitomad/TechTalk-AWS-Lamba-Swift/raw/main/Documentation/Images/Docker.png)

Gracias al plugin `archive` presente desde la versión 1 de **Swift AWS Lamnda runtime** la gestión de dicha imagen se hace de forma transparente para nosotros, sólo es necesario tener instalado el cliente de Docker y ejecutándose mientras se realiza la compilación y empaquetado.

## Resultado de la operación

Una vez que se ha generado el paquete ya podemos cargar nuestra función Lambda en AWS. Para ello debemos ir a la carpeta donde hemos indicado que se genere el paquete y seleccionar el archivo `zip`

![Terminal-Empaquetado](https://github.com/fitomad/TechTalk-AWS-Lamba-Swift/raw/main/Documentation/Images/Lambda-Paquete.png)

* [GitHub](https://github.com/fitomad)
* [LinkedIn](https://www.linkedin.com/in/adolfo-vera)
