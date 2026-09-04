# Aplicaciones Flutter — edición de demostración

Este repositorio contiene versiones públicas y ejecutables de siete aplicaciones
Flutter. Los datos operativos, credenciales, dominios privados, matrículas,
personas, ubicaciones y elementos de marca se han sustituido por ejemplos
sintéticos.

## Aplicaciones

- `agenda_estado`
- `animalesapp`
- `inspecciones`
- `maquinaria_m`
- `mi_diario`
- `nieve_vial`
- `nieve_vial_vuelta`

## Modo de demostración

`DEMO_MODE` está activado de forma predeterminada. En este modo las aplicaciones
no contactan con la infraestructura privada: usan datos locales de ejemplo y
simulan las operaciones que normalmente se enviarían a un servidor.

Para ejecutar una aplicación:

```powershell
cd apps\agenda_estado
flutter pub get
flutter run
```

También se puede indicar el modo explícitamente:

```powershell
flutter run --dart-define=DEMO_MODE=true
```

## Uso con infraestructura propia

El modo real requiere un backend, autenticación y configuración creados por
quien reutilice el código. Este repositorio no proporciona ni revela la
infraestructura privada original.

No añadas secretos al código ni al historial de Git. Usa variables de entorno,
`--dart-define` o archivos locales ignorados y aplica autenticación revocable por
dispositivo o usuario.

## Licencia

El código se publica bajo la licencia MIT. Consulta `LICENSE` para conocer los
términos completos.
