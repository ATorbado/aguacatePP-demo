# Nieve Java — demostración

Aplicación de escritorio para practicar un flujo ficticio de vialidad invernal.
Funciona de forma local y genera vistas previas con contenido de ejemplo.

## Requisitos

- JDK 17 o posterior.
- Maven 3.9.16 mediante el Wrapper incluido.

## Ejecutar la demostración

```powershell
.\mvnw.cmd clean verify
java -jar target\vialidad-invernal-demo.jar
```

## Escaneo del artefacto

Después de compilar:

```powershell
.\scripts\verify-artifact.ps1 `
  -JarPath .\target\vialidad-invernal-demo.jar
```

La dependencia de Apache POI permite leer y crear documentos de ejemplo con
formatos abiertos. La demostración no realiza envíos ni conexiones externas.
