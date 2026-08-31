# Agenda Estado

Aplicación Flutter para registrar incidencias, adjuntar fotografías y
reenviar formularios pendientes cuando vuelve la conectividad.

## Configuración local

La URL y la credencial del backend no se guardan en el repositorio. Para una
compilación privada:

```powershell
flutter run `
  --dart-define=AGENDA_BACKEND_URL=https://servidor.example/submit `
  --dart-define=AGENDA_API_TOKEN=credencial-temporal
```

La URL debe usar HTTPS. Si falta algún valor, la aplicación muestra
`Configuración pendiente` y no abre el formulario.

`--dart-define` evita publicar la credencial en el código fuente, pero no la
convierte en un secreto: puede recuperarse de una aplicación compilada. Antes
de distribuir la app, el backend debe usar autenticación por usuario/dispositivo
y credenciales de corta duración. También debe revocarse la credencial que
estuvo incluida en versiones anteriores.

## Verificación local

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug `
  --dart-define=AGENDA_BACKEND_URL=https://servidor.example/submit `
  --dart-define=AGENDA_API_TOKEN=credencial-temporal
```

## Datos pendientes

Si el servidor no responde o devuelve un error reintentable, los campos y una
copia estable de las fotos quedan en el almacenamiento privado de la app. La
cola limita su tamaño, usa escritura con recuperación y conserva los datos si
detecta corrupción. Los campos y las fotografías pendientes se cifran con una
clave aleatoria guardada en el almacén seguro del dispositivo.

## Punto kilométrico

La demostración nunca interpreta un número de portal como PK. Una instalación
real debe consultar los hitos oficiales desde un proxy HTTPS autenticado en su
propio backend; así evita exponer infraestructura privada y mantiene un único
cálculo verificable para todos los móviles.

## Política remota firmada

La aplicación descarga `policy.json` y `policy.sig` desde GitHub y verifica la
firma Ed25519 antes de confiar en la política.

El campo `ts` es obligatorio, debe estar en UTC y caduca después de
`ttlDays`. Al llegar esa fecha, la app queda bloqueada incluso con conexión.
Para renovarla hay que actualizar `ts` y volver a generar `policy.sig` con la
clave privada original. Cambiar solo el JSON invalida la firma.

## Distribución

El identificador Android sigue siendo `com.example.agenda_estado`. Cambiarlo,
configurar la firma release, probar en dispositivos reales y publicar requieren
una decisión explícita del responsable del proyecto.
