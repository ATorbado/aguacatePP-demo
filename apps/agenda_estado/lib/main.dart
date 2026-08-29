import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

import 'app_config.dart';
import 'offline_queue.dart';
import 'remote_security.dart';
import 'retry_backoff.dart';

/* ------------------------- Accesibilidad ------------------------- */
final ValueNotifier<bool> seniorMode = ValueNotifier<bool>(true);

ThemeData _buildTheme(bool senior) {
  const naranjaPrincipal = Color(0xFFFF7700);
  const negroMedianoche = Color(0xFF222222);
  const grisPerlado = Color(0xFFF3EEE4);

  final borderRadius = BorderRadius.circular(senior ? 16 : 12);
  final base = ThemeData(
    primaryColor: naranjaPrincipal,
    scaffoldBackgroundColor: grisPerlado,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    appBarTheme: const AppBarTheme(
      backgroundColor: negroMedianoche,
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    iconTheme: IconThemeData(size: senior ? 30 : 24),
    visualDensity: VisualDensity.comfortable,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: naranjaPrincipal,
        foregroundColor: Colors.white,
        minimumSize: Size(0, senior ? 56 : 48),
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, senior ? 56 : 48),
        side: const BorderSide(color: negroMedianoche),
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: TextStyle(fontSize: senior ? 18 : 16),
      hintStyle: TextStyle(fontSize: senior ? 18 : 16),
      contentPadding: EdgeInsets.symmetric(
        vertical: senior ? 24 : 18,
        horizontal: senior ? 22 : 14,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(borderRadius: borderRadius),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: negroMedianoche),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: naranjaPrincipal, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    ),
    checkboxTheme: CheckboxThemeData(
      visualDensity: VisualDensity.comfortable,
      side: const BorderSide(width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      margin: EdgeInsets.symmetric(vertical: senior ? 10 : 8),
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
    ),
    useMaterial3: true,
  );

  return base;
}

/* ------------------------- Constantes ------------------------- */
const _maxBytes = 30 * 1024 * 1024; // 30 MB

class _SendResult {
  final bool success;
  final bool retryable;
  final int? statusCode;

  const _SendResult({
    required this.success,
    required this.retryable,
    this.statusCode,
  });
}

/* ------------------------ Envío al servidor ------------------------ */
Future<_SendResult> _sendToServer(
  AppConfig config,
  Map<String, String> fields,
  List<String> photoPaths,
) => _sendRequest(
  config,
  fields,
  buildPhotos:
      photoPaths.isEmpty
          ? null
          : () async => [
            await http.MultipartFile.fromPath('fotoInicio', photoPaths[0]),
            if (photoPaths.length >= 2)
              await http.MultipartFile.fromPath('fotoFin', photoPaths[1]),
          ],
);

Future<_SendResult> _sendQueuedToServer(
  AppConfig config,
  Map<String, String> fields,
  List<QueuedPhoto> photos,
) => _sendRequest(
  config,
  fields,
  buildPhotos:
      photos.isEmpty
          ? null
          : () async => [
            http.MultipartFile.fromBytes(
              'fotoInicio',
              photos[0].bytes,
              filename: photos[0].filename,
            ),
            if (photos.length >= 2)
              http.MultipartFile.fromBytes(
                'fotoFin',
                photos[1].bytes,
                filename: photos[1].filename,
              ),
          ],
);

typedef _PhotoFilesBuilder = Future<List<http.MultipartFile>> Function();

Future<_SendResult> _sendRequest(
  AppConfig config,
  Map<String, String> fields, {
  _PhotoFilesBuilder? buildPhotos,
}) async {
  if (config.demoMode) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const _SendResult(success: true, retryable: false, statusCode: 200);
  }

  final backendUri = config.backendUri;
  if (backendUri == null || !config.isValid) {
    return const _SendResult(success: false, retryable: false);
  }

  try {
    if (buildPhotos == null) {
      final res = await http
          .post(
            backendUri,
            headers: {
              'Authorization': 'Bearer ${config.apiToken}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(fields),
          )
          .timeout(const Duration(seconds: 30));

      final ok = res.statusCode >= 200 && res.statusCode < 300;
      return _SendResult(
        success: ok,
        retryable: !ok && _isRetryableStatus(res.statusCode),
        statusCode: res.statusCode,
      );
    }

    final req =
        http.MultipartRequest('POST', backendUri)
          ..headers['Authorization'] = 'Bearer ${config.apiToken}'
          ..fields.addAll(fields);

    req.files.addAll(await buildPhotos());

    final streamed = await req.send().timeout(const Duration(seconds: 45));
    final res = await http.Response.fromStream(streamed);
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    return _SendResult(
      success: ok,
      retryable: !ok && _isRetryableStatus(res.statusCode),
      statusCode: res.statusCode,
    );
  } on SocketException {
    return const _SendResult(success: false, retryable: true);
  } on TimeoutException {
    return const _SendResult(success: false, retryable: true);
  } catch (_) {
    return const _SendResult(success: false, retryable: true);
  }
}

bool _isRetryableStatus(int statusCode) =>
    statusCode == 408 || statusCode == 429 || statusCode >= 500;

bool _hasNetwork(List<ConnectivityResult> results) =>
    results.isNotEmpty && !results.contains(ConnectivityResult.none);

/* ----------------------- Catálogos fijos ----------------------- */
const _identificadores = [
  'Equipo de Vigilancia (Personal UTE)',
  'Guardia Civil de Tráfico',
  'Personal de servicio de ejemplo',
  'Otro personal de la UTE',
  'Policía Local',
  'Otras personas, ajenas a la conservación',
  'Otros sectores de Conservación aledaños',
  'SIN DATOS',
];
const _carreteras = ['N-120', 'N-601', 'N-621', 'N-625', 'A-60', 'Ramal A-60'];
const _calzadas = ['Izquierda', 'Derecha', 'Ambas'];
const _margenes = ['Izquierda', 'Derecha', 'Ambas', 'Glorieta'];

const _tipos = [
  'FALTA / AUSENCIA',
  'DETERIORO / MAL ESTADO',
  'NECESIDAD / MEJORA',
  'LIBRE / COMENTARIOS',
];
const _causas = [
  'ACCIDENTE',
  'USO / TIEMPO',
  'DESPRENDIMIENTO',
  'CLIMATOLOGÍA',
  'FALLO INSTALACIONES',
  'VANDALISMO',
  'DETERIORO',
];

const Map<String, List<String>> _subelementosMap = {
  'BALIZAMIENTO': [
    'Baliza luminosa',
    'Baliza H-75',
    'Captafaro Horizontal',
    'Captafaro Vertical',
    'Hito de arista',
    'Hito de vértice',
    'Jalón de nieve',
    'Manga de viento',
    'Panel vertical',
  ],
  'DELIMITADORES': [
    'Acera',
    'Bordillo',
    'Isleta',
    'Paso de mediana',
    'Zona pavimentada exterior',
  ],
  'ENTORNO': [
    'Acceso',
    'Árbol',
    'Elemento antideslumbrante',
    'Elemento ornamental',
    'Instalación de riego',
    'Mobiliario exterior',
    'Pantalla anti ruido',
    'Paso de fauna',
    'Plantación arbustiva',
    'Plantación herbácea',
    'Separación de hidrocarburos',
    'Valla de cerramiento',
    'Zona a segar',
  ],
  'FIRMES': ['Bacheo con aglomerado en frío / caliente', 'Actuación relevante'],
  'INSTALACIONES EXTERIORES (Electricidad)': [
    'Circuito eléctrico',
    'Cuadro de distribución de energía eléctrica',
    'Grupo electrógeno',
    'Línea eléctrica',
    'Panel solar',
    'Transformador',
  ],
  'INSTALACIONES EXTERIORES (Explotación)': [
    'Cámaras de vídeo',
    'Estación de aforo y ETD',
    'Estación de bombeo',
    'Estación meteorológica',
    'Panel mensaje variable',
    'Semáforo',
  ],
  'INSTALACIONES EXTERIORES (Iluminación)': ['Báculo', 'Luminaria'],
  'INSTALACIONES VIALIDAD INVERNAL': [
    'Almacén',
    'Deposito salmuera',
    'Planta salmuera',
    'Silo de fundentes',
  ],
  'LIMPIEZA': [
    'Gestión de animales muertos',
    'Limpieza de paramentos',
    'Retirada de objetos varios en berma y zona contigua',
    'Retirada de piedras y objetos varios en plataforma',
    'Vertidos en plataforma',
  ],
  'MARCAS VIALES': [
    'Marca vial longitudinal',
    'Marca transversal',
    'Flechas',
    'Inscripciones',
    'Otras marcas',
  ],
  'OBRAS DE DRENAJE': [
    'Arqueta o pozo de registro',
    'Bajante de talud',
    'Caz',
    'Colector',
    'Cuneta revestida',
    'Cuneta sin revestir',
    'Drenaje subterráneo',
    'Pequeña obra de fábrica (caño, tajea o alcantarilla)',
    'Sumidero o imbornal',
  ],
  'OBRAS DE FÁBRICA': [
    'Puente / Pontón',
    'Viaducto',
    'Juntas de dilatación',
    'Muros y obras de contención',
  ],
  'OBRAS DE TIERRA': [
    'Anclaje',
    'Malla o red metálica',
    'Pantalla dinámica',
    'Pantalla estática',
    'Pantalla paranieves',
    'Revestimiento de talud',
    'Talud',
  ],
  'SEÑALIZACIÓN VERTICAL': [
    'Banderola',
    'Cartel flecha',
    'Cartel de lamas',
    'Elemento de sustentación',
    'Panel direccional',
    'Panel complementario',
    'Placa de señal',
    'Pórtico',
    'Poste',
    'Señal',
    'Señal luminosa',
  ],
  'SISTEMAS DE CONTENCIÓN': [
    'Atenuador de impacto',
    'Barandilla',
    'Barrera de seguridad',
    'Sistema para protección de motociclista',
    'Dispositivo para protección de paso salvacuneta',
    'Pretil',
  ],
  'TÚNELES': [],
};

/// ----- Flatten subelementos: subelemento -> elemento(grupo) -----
final Map<String, String> _subToElemento = {
  for (final e in _subelementosMap.entries)
    for (final s in e.value) s: e.key,
};

final List<String> _subelementosAll = (_subToElemento.keys.toList()..sort());

/// Normaliza: case-insensitive + tildes básicas
String _norm(String s) {
  var t = s.toLowerCase();
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  for (var i = 0; i < from.length; i++) {
    t = t.replaceAll(from[i], to[i]);
  }
  return t;
}

/// Mapa: Grupo(Elemento) → { SubElementoVisible → NombreServidor }
const Map<String, Map<String, String>> _subrename = {
  'BALIZAMIENTO': {
    'Baliza luminosa': 'Instalaciones de la carretera',
    'Baliza H-75': 'Deterioros Balizamiento',
    'Captafaro Horizontal': 'Deterioros Balizamiento',
    'Captafaro Vertical': 'Deterioros Balizamiento',
    'Hito de arista': 'Deterioros Balizamiento',
    'Hito de vértice': 'Deterioros Balizamiento',
    'Jalón de nieve': 'Deterioros Balizamiento',
    'Manga de viento': 'Instalaciones de la carretera',
    'Panel vertical': 'Deterioros Balizamiento',
  },
  'DELIMITADORES': {
    'Acera': 'Retirada de vertidos',
    'Bordillo': 'Reparación de deterioros',
    'Isleta': 'Reparación de deterioros',
    'Paso de mediana': 'Retirada de vertidos',
    'Zona pavimentada exterior': 'Retirada de vertidos',
  },
  'ENTORNO': {
    'Acceso': 'Retirada de vertidos',
    'Árbol': 'Entorno Vegetación',
    'Elemento antideslumbrante': 'Instalaciones de la carretera',
    'Elemento ornamental': 'Instalaciones de la carretera',
    'Instalación de riego': 'Instalaciones de la carretera',
    'Mobiliario exterior': 'Instalaciones de la carretera',
    'Pantalla anti ruido': 'Instalaciones de la carretera',
    'Paso de fauna': 'Instalaciones de la carretera',
    'Plantación arbustiva': 'Entorno Vegetación',
    'Plantación herbácea': 'Entorno Vegetación',
    'Separación de hidrocarburos': 'Instalaciones de la carretera',
    'Valla de cerramiento': 'Instalaciones de la carretera',
    'Zona a segar': 'Entorno Vegetación',
  },
  'FIRMES': {
    'Bacheo con aglomerado en frío / caliente': 'Deterioros Pavimento (Baches)',
    'Actuación relevante': 'Deterioros Pavimento (Roderas)',
  },
  'INSTALACIONES EXTERIORES (Electricidad)': {
    'Circuito eléctrico': 'Instalaciones de la carretera',
    'Cuadro de distribución de energía eléctrica':
        'Instalaciones de la carretera',
    'Grupo electrógeno': 'Instalaciones de la carretera',
    'Línea eléctrica': 'Instalaciones de la carretera',
    'Panel solar': 'Instalaciones de la carretera',
    'Transformador': 'Instalaciones de la carretera',
  },
  'INSTALACIONES EXTERIORES (Explotación)': {
    'Cámaras de vídeo': 'Instalaciones de la carretera',
    'Estación de aforo y ETD': 'Instalaciones de la carretera',
    'Estación de bombeo': 'Instalaciones de la carretera',
    'Estación meteorológica': 'Instalaciones de la carretera',
    'Panel mensaje variable': 'Instalaciones de la carretera',
    'Semáforo': 'Instalaciones de la carretera',
  },
  'INSTALACIONES EXTERIORES (Iluminación)': {
    'Báculo': 'Instalaciones de la carretera',
    'Luminaria': 'Instalaciones de la carretera',
  },
  'INSTALACIONES VIALIDAD INVERNAL': {
    'Almacén': 'Instalaciones de la carretera',
    'Deposito salmuera': 'Instalaciones de la carretera',
    'Planta salmuera': 'Instalaciones de la carretera',
    'Silo de fundentes': 'Instalaciones de la carretera',
  },
  'LIMPIEZA': {
    'Gestión de animales muertos': 'Retirada de vertidos',
    'Limpieza de paramentos': 'Limpieza de pintadas',
    'Retirada de objetos varios en berma y zona contigua':
        'Retirada de vertido de materiales',
    'Retirada de piedras y objetos varios en plataforma':
        'Retirada de vertido de materiales',
    'Vertidos en plataforma': 'Retirada de vertido de materiales',
  },
  'MARCAS VIALES': {
    'Marca vial longitudinal': 'Deterioros Marcas viales',
    'Marca transversal': 'Deterioros Marcas viales',
    'Flechas': 'Deterioros Marcas viales',
    'Inscripciones': 'Deterioros Marcas viales',
    'Otras marcas': 'Deterioros Marcas viales',
  },
  'OBRAS DE DRENAJE': {
    'Arqueta o pozo de registro': 'Deterioros Elementos drenaje',
    'Bajante de talud': 'Deterioros Elementos drenaje',
    'Caz': 'Deterioros Elementos drenaje',
    'Colector': 'Deterioros Elementos drenaje',
    'Cuneta revestida': 'Deterioros Elementos drenaje',
    'Cuneta sin revestir': 'Deterioros Elementos drenaje',
    'Drenaje subterráneo': 'Deterioros Elementos drenaje',
    'Pequeña obra de fábrica (caño, tajea o alcantarilla)':
        'Deterioros Elementos drenaje',
    'Sumidero o imbornal': 'Deterioros Elementos drenaje',
  },
  'OBRAS DE FÁBRICA': {
    'Puente / Pontón': 'Deterioros obras de fábrica',
    'Viaducto': 'Deterioros obras de fábrica',
    'Juntas de dilatación': 'Deterioros obras de fábrica',
    'Muros y obras de contención': 'Deterioros obras de fábrica',
  },
  'OBRAS DE TIERRA': {
    'Anclaje': 'Deterioros Obras de tierra',
    'Malla o red metálica': 'Deterioros Obras de tierra',
    'Pantalla dinámica': 'Deterioros Obras de tierra',
    'Pantalla estática': 'Deterioros Obras de tierra',
    'Pantalla paranieves': 'Deterioros Obras de tierra',
    'Revestimiento de talud': 'Deterioros Obras de tierra',
    'Talud': 'Desprendimientos y deslizamientos',
  },
  'SEÑALIZACIÓN VERTICAL': {
    'Banderola': 'Deterioros Elementos Señalización especial',
    'Cartel flecha': 'Deterioros Elementos Señalización especial',
    'Cartel de lamas': 'Deterioros Elementos Señalización especial',
    'Elemento de sustentación': 'Deterioros Elementos Señalización habitual',
    'Panel direccional': 'Deterioros Elementos Señalización habitual',
    'Panel complementario': 'Deterioros Elementos Señalización especial',
    'Placa de señal': 'Deterioros Elementos Señalización habitual',
    'Pórtico': 'Deterioros Elementos Señalización especial',
    'Poste': 'Deterioros Elementos Señalización habitual',
    'Señal': 'Deterioros Elementos Señalización habitual',
    'Señal luminosa': 'Deterioros Elementos Señalización especial',
  },
  'SISTEMAS DE CONTENCIÓN': {
    'Atenuador de impacto': 'Deterioros Elementos Defensa especial',
    'Barandilla': 'Deterioros Elementos Defensa estándar',
    'Barrera de seguridad': 'Deterioros Barreras metálicas',
    'Sistema para protección de motociclista': 'Deterioros Barreras metálicas',
    'Dispositivo para protección de paso salvacuneta':
        'Deterioros Elementos Defensa especial',
    'Pretil': 'Deterioros Elementos Defensa estándar',
  },
  'TÚNELES': {'Tunel': 'Instalaciones de la carretera'},
};

/// ----- PK helpers -----
double? _parsePk(String? s) {
  if (s == null) return null;
  var t = s.trim().replaceAll(',', '.');

  final plus = RegExp(r'^(\d+)\+(\d+)$');
  final m1 = plus.firstMatch(t);
  if (m1 != null) {
    final km = double.parse(m1.group(1)!);
    final m = double.parse(m1.group(2)!);
    return km + m / 1000.0;
  }

  final m2 = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(t);
  if (m2 != null) return double.tryParse(m2.group(1)!);

  return double.tryParse(t);
}

/// ----- IMD (tramos) -----
class _ImdSeg {
  final String c;
  final double a;
  final double b;
  final int imd;
  const _ImdSeg(this.c, this.a, this.b, this.imd);
}

const List<_ImdSeg> _imdsegments = [
  // ... lista real
  _ImdSeg('N-120', 238.1, 239.7, 184),
];

int? _imdAt(String carretera, double pk) {
  for (final s in _imdsegments) {
    if (s.c == carretera && pk >= s.a && pk < s.b) return s.imd;
  }
  return null;
}

/// ----- tipo_carretera -----
String _tipoCarretera(String carretera, double? pk) {
  if (carretera == 'A-60') return 'AU';
  if (carretera == 'Ramal A-60') return 'AU - Ramal enlace';
  if (carretera == 'N-601') {
    final p = pk ?? 0.0;
    return (p > 298.0) ? 'CC/AU' : 'CC';
  }
  return 'CC';
}

/// ----- vlimite -----
const Map<String, List<int>> _vlimite = {
  'Instalaciones de la carretera': [72, 86],
  'Deterioros Balizamiento': [48, 60],
  'Retirada de vertidos': [120, 144],
  'Reparación de deterioros': [144, 172],
  'Entorno Vegetación': [48, 60],
  'Deterioros Pavimento (Baches)': [48, 60],
  'Deterioros Pavimento (Roderas)': [144, 172],
  'Limpieza de pintadas': [48, 60],
  'Retirada de vertido de materiales': [120, 144],
  'Deterioros Marcas viales': [120, 144],
  'Deterioros Elementos drenaje': [144, 172],
  'Deterioros obras de fábrica': [144, 172],
  'Deterioros Obras de tierra': [144, 172],
  'Desprendimientos y deslizamientos': [144, 172],
  'Deterioros Elementos Señalización especial': [480, 576],
  'Deterioros Elementos Señalización habitual': [48, 60],
  'Deterioros Barreras metálicas': [48, 60],
  'Deterioros Elementos Defensa especial': [480, 576],
  'Deterioros Elementos Defensa estándar': [72, 86],
};

int? _computeVlimite({
  required String categoriaRenombrada,
  required String carretera,
  required double? pk,
}) {
  final par = _vlimite[categoriaRenombrada];
  if (par == null) return null;

  final imd = (pk != null) ? _imdAt(carretera, pk) : null;

  if (imd == null || imd > 2000) return par[0];
  if (carretera.startsWith('N')) return par[1];
  return par[0];
}

/* ---------------------------- APP ---------------------------- */
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final securityResult = await RemoteSecurity.check();
  final appConfig = AppConfig.fromEnvironment();

  runApp(MyApp(securityResult: securityResult, config: appConfig));
}

class MyApp extends StatelessWidget {
  final RemoteSecurityResult securityResult;
  final AppConfig config;

  const MyApp({super.key, required this.securityResult, required this.config});

  @override
  Widget build(BuildContext _) {
    return ValueListenableBuilder<bool>(
      valueListenable: seniorMode,
      builder:
          (_, isSenior, _) => MaterialApp(
            title: 'Inspecciones',
            theme: _buildTheme(isSenior),
            debugShowCheckedModeBanner: false,
            home:
                !securityResult.isAllowed
                    ? BlockedPage(message: securityResult.message)
                    : !config.isValid
                    ? BlockedPage(
                      title: 'Configuración pendiente',
                      message: config.validationError!,
                    )
                    : FormPage(config: config),
            builder: (context, child) {
              final scaler = TextScaler.linear(isSenior ? 1.3 : 1.0);
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(textScaler: scaler),
                child: child!,
              );
            },
          ),
    );
  }
}

class BlockedPage extends StatelessWidget {
  final String title;
  final String message;

  const BlockedPage({
    super.key,
    this.title = 'Aplicación bloqueada',
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    const naranjaPrincipal = Color(0xFFFF7700);
    const negroMedianoche = Color(0xFF222222);
    const grisPerlado = Color(0xFFF3EEE4);

    return Scaffold(
      backgroundColor: grisPerlado,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 72,
                      color: naranjaPrincipal,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: negroMedianoche,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        color: negroMedianoche,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FormPage extends StatefulWidget {
  final AppConfig config;

  const FormPage({super.key, required this.config});
  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  /* --------- Controllers y estado --------- */
  final _fKey = GlobalKey<FormState>();
  final _fechaDet = TextEditingController();
  final _comentarios = TextEditingController();
  final _fCon = TextEditingController();
  final _hCon = TextEditingController();
  final _fIni = TextEditingController();
  final _hIni = TextEditingController();
  final _fFin = TextEditingController();

  // Campo visible subelemento (readOnly)
  final TextEditingController _subCtrl = TextEditingController();
  // Buscador del bottom sheet
  final TextEditingController _subSearchCtrlSheet = TextEditingController();

  String? _ident,
      _carretera,
      _calzada,
      _margen,
      _elemento,
      _subelemento,
      _causa,
      _tipo;
  String? _lat, _lon, _pk;
  List<File> _photos = [];
  bool _sending = false;
  late final Future<OfflineQueue> _queue;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _queueRetryTimer;
  final RetryBackoff _queueRetryBackoff = RetryBackoff();

  String _dateEs(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  @override
  void initState() {
    super.initState();
    _fechaDet.text = _dateEs(DateTime.now());
    _queue = OfflineQueue.openDefault();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (_hasNetwork(results)) {
        _queueRetryTimer?.cancel();
        _queueRetryBackoff.reset();
        unawaited(_trySendQueued());
      }
    });
    unawaited(_trySendQueued());
    _subCtrl.text = _subelemento ?? '';
  }

  Future<void> _trySendQueued() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!_hasNetwork(connectivity)) {
        _scheduleQueueRetry();
        return;
      }
      final queue = await _queue;
      final report = await queue.drain((fields, photoPaths) async {
        final result = await _sendQueuedToServer(
          widget.config,
          fields,
          photoPaths,
        );
        if (result.success) {
          return const QueueSendResult.sent();
        }
        if (result.retryable) {
          return QueueSendResult.retryable(statusCode: result.statusCode);
        }
        return QueueSendResult.permanent(statusCode: result.statusCode);
      });
      if (report.retryPending) {
        _scheduleQueueRetry();
      } else {
        _queueRetryTimer?.cancel();
        _queueRetryBackoff.reset();
      }
      if (report.quarantined > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${report.quarantined} envío(s) se conservaron para revisión.',
            ),
          ),
        );
      }
    } on OfflineQueueException {
      debugPrint('[queue] No se pudo procesar la cola local.');
    } catch (_) {
      debugPrint('[queue] Falló el reintento automático.');
      _scheduleQueueRetry();
    }
  }

  void _scheduleQueueRetry() {
    if (_queueRetryTimer?.isActive == true) return;
    _queueRetryTimer = Timer(
      _queueRetryBackoff.nextDelay(),
      () => unawaited(_trySendQueued()),
    );
  }

  @override
  void dispose() {
    _queueRetryTimer?.cancel();
    unawaited(_connectivitySubscription?.cancel());
    _fechaDet.dispose();
    _comentarios.dispose();
    _fCon.dispose();
    _hCon.dispose();
    _fIni.dispose();
    _hIni.dispose();
    _fFin.dispose();
    _subCtrl.dispose();
    _subSearchCtrlSheet.dispose();
    super.dispose();
  }

  /* --------- Helpers fecha/hora --------- */
  bool get _isCarreteraN => _carretera?.startsWith('N') == true;

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _isoTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate(TextEditingController c, {bool es = false}) async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
      builder: (ctx, child) {
        final isSenior = seniorMode.value;
        return Theme(data: _buildTheme(isSenior), child: child!);
      },
    );
    if (d != null) c.text = es ? _dateEs(d) : _isoDate(d);
  }

  Future<void> _pickTime(TextEditingController c) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) {
        final isSenior = seniorMode.value;
        return Theme(data: _buildTheme(isSenior), child: child!);
      },
    );
    if (t != null) c.text = _isoTime(t);
  }

  /* --------- Selector subelemento con búsqueda + scroll --------- */
  Future<void> _openSubelementoPicker() async {
    _subSearchCtrlSheet.text = _subCtrl.text;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final q = _norm(_subSearchCtrlSheet.text);

            // SIEMPRE parte de todas (y filtra si hay texto)
            final filtered =
                q.isEmpty
                    ? _subelementosAll
                    : _subelementosAll
                        .where((s) => _norm(s).contains(q))
                        .toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Column(
                  children: [
                    Container(
                      height: 4,
                      width: 44,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    TextField(
                      controller: _subSearchCtrlSheet,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Buscar subelemento',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setModal(() {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = filtered[i];
                          return ListTile(
                            title: Text(s),
                            trailing:
                                (_subelemento == s)
                                    ? const Icon(Icons.check, size: 20)
                                    : null,
                            onTap: () => Navigator.of(ctx).pop(s),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null) return;

    setState(() {
      _subelemento = selected;
      _elemento = _subToElemento[selected]; // interno
      _subCtrl.text = selected;
    });
  }

  /* --------- Coordenadas + PK --------- */
  Future<void> _coordsPk() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    if (await Geolocator.requestPermission() == LocationPermission.denied) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    final lat = pos.latitude.toStringAsFixed(6);
    final lon = pos.longitude.toStringAsFixed(6);
    String? pk;

    try {
      final uri = Uri.parse(
        'https://www.cartociudad.es/geocoder/api/geocoder/reverseGeocode'
        '?lon=$lon&lat=$lat&type=pk',
      );
      final r = await http.get(uri).timeout(const Duration(seconds: 6));

      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);

        Map? firstmap(dynamic v) =>
            v is Map
                ? v
                : (v is List && v.isNotEmpty && v.first is Map)
                ? v.first
                : null;

        final data =
            firstmap(body) ??
            firstmap(body['output']) ??
            firstmap(body['address']);

        pk = data?['pk']?.toString() ?? data?['portalNumber']?.toString();
      } else {
        debugPrint('[PK] CartoCiudad ${r.statusCode}');
      }
    } on TimeoutException {
      debugPrint('[PK] Timeout');
    } on SocketException catch (e) {
      debugPrint('[PK] SocketException: $e');
    } catch (e) {
      debugPrint('[PK] JSON error: $e');
    }

    setState(() {
      _lat = lat;
      _lon = lon;
      _pk = pk;
    });
  }

  /* --------- Foto --------- */
  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final imgs = await picker.pickMultiImage();
    if (imgs.isEmpty) return;

    final files = imgs.take(2).map((x) => File(x.path)).toList();

    for (final f in files) {
      if (await f.length() > _maxBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alguna imagen supera 30 MB')),
          );
        }
        return;
      }
    }

    setState(() => _photos = files);
  }

  // Helpers para opcionales
  String _optSpace(TextEditingController c) =>
      c.text.isEmpty ? ' ' : c.text; // comentarios → " "
  String? _optNull(TextEditingController c) =>
      c.text.isEmpty ? null : c.text; // fechas/horas → no enviar

  String _estadoCalculado() {
    final hasInicio = _fIni.text.isNotEmpty && _hIni.text.isNotEmpty;
    final hasFin = _fFin.text.isNotEmpty;
    if (!hasInicio) return 'Pendiente de actuación';
    if (!hasFin) return 'Actuación iniciada';
    return 'Deterioro solucionado';
  }

  /* --------- Mensaje final y panel copiar/compartir --------- */
  String _buildMensajeFinal(
    Map<String, String> f, {
    String? lat,
    String? lon,
    int fotos = 0,
  }) {
    String pick(String k) => (f[k] ?? '').trim();
    final b = StringBuffer();

    b.writeln('Incidencia registrada');
    b.writeln('Identificador: ${pick('identificador')}');
    b.writeln('Carretera: ${pick('carretera')}  PK: ${pick('pk')}');
    b.writeln('Calzada: ${pick('calzada')}  Margen: ${pick('margen')}');
    //b.writeln('Elemento: ${pick('elemento')}  Subelemento: ${pick('subelemento')}'); OLD
    b.writeln('Subelemento: ${pick('subelemento')}');
    b.writeln('Tipo: ${pick('tipo')}  Causa: ${pick('causa')}');
    if (lat != null && lon != null && lat.isNotEmpty && lon.isNotEmpty) {
      b.writeln('Coordenadas: $lat, $lon');
    }
    if (pick('comentarios').isNotEmpty && pick('comentarios') != ' ') {
      b.writeln('Comentarios: ${pick('comentarios')}');
    }
    if (pick('fecha_conocimiento').isNotEmpty ||
        pick('hora_conocimiento').isNotEmpty) {
      b.writeln(
        'Conocimiento: ${pick('fecha_conocimiento')} ${pick('hora_conocimiento')}',
      );
    }
    if (pick('fecha_inicio').isNotEmpty || pick('hora_inicio').isNotEmpty) {
      b.writeln(
        'Inicio actuación: ${pick('fecha_inicio')} ${pick('hora_inicio')}',
      );
    }
    if (pick('fecha_fin').isNotEmpty) {
      b.writeln('Fin reparación: ${pick('fecha_fin')}');
    }
    if (pick('vlimite').isNotEmpty) {
      b.writeln('Tiempo límite: ${pick('vlimite')} h');
    }
    b.writeln('Estado: ${pick('estado')}');
    if (fotos > 0) b.writeln('Fotos adjuntas: $fotos');

    return b.toString().trim();
  }

  Future<void> _mostrarPanelExito(
    String texto, {
    List<File> fotos = const [],
  }) async {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Datos enviados con éxito')));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Mensaje para copiar y enviar',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEE4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF222222)),
                ),
                child: SelectableText(
                  texto,
                  style: const TextStyle(fontSize: 16, height: 1.3),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: texto));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Texto copiado')),
                          );
                        }
                      },
                      child: const Text('COPIAR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (fotos.isNotEmpty) {
                          await SharePlus.instance.share(
                            ShareParams(
                              files: fotos.map((f) => XFile(f.path)).toList(),
                              text: texto,
                            ),
                          );
                        } else {
                          await SharePlus.instance.share(
                            ShareParams(text: texto),
                          );
                        }
                      },
                      child: const Text('COMPARTIR'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /* --------- Enviar --------- */
  Future<void> _submit() async {
    if (!(_fKey.currentState?.validate() ?? false)) return;
    if (_pk == null || _pk!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Obtenga el PK primero')));
      return;
    }

    _elemento ??= (_subelemento == null) ? null : _subToElemento[_subelemento!];

    final calzada = _isCarreteraN ? 'Única' : _calzada;

    final subelementoMap =
        _subrename[_elemento]?[_subelemento ?? ''] ?? _subelemento ?? '';
    final pkd = _parsePk(_pk);
    final tipoCar = _tipoCarretera(_carretera!, pkd);

    final vl = _computeVlimite(
      categoriaRenombrada: subelementoMap,
      carretera: _carretera!,
      pk: pkd,
    );

    final faltan = <String>[
      if (_ident == null) 'Identificador',
      if (_carretera == null) 'Carretera',
      if (calzada == null || calzada.isEmpty) 'Calzada',
      if (_margen == null) 'Margen',
      if (_tipo == null) 'Tipo',
      if (_causa == null) 'Causa',
      if (_subelemento == null) 'Subelemento',
      if (_elemento == null) 'Elemento',
    ];
    if (faltan.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Faltan: ${faltan.join(', ')}')));
      return;
    }

    final estado = _estadoCalculado();

    final fields = <String, String>{
      'identificador': _ident!,
      'carretera': _carretera!,
      'pk': _pk!,
      'calzada': (_isCarreteraN ? 'Única' : _calzada!),
      'margen': _margen!,
      'elemento': _elemento!,
      'subelemento': _subelemento!,
      'causa': _causa!,
      'tipo': _tipo!,
      'comentarios': _optSpace(_comentarios),
      'fecha_conocimiento': _fCon.text,
      'hora_conocimiento': _hCon.text,
      'observaciones': ' ',
      'estado': estado,
      'subelemento_mapeado':
          (_subrename[_elemento]?[_subelemento ?? ''] ?? _subelemento ?? ''),
      'tipo_carretera': tipoCar,
      'vlimite': (vl?.toString() ?? ''),
    };

    final fi = _optNull(_fIni);
    final hi = _optNull(_hIni);
    final ff = _optNull(_fFin);
    if (fi != null) fields['fecha_inicio'] = fi;
    if (hi != null) fields['hora_inicio'] = hi;
    if (ff != null) fields['fecha_fin'] = ff;

    setState(() => _sending = true);
    final photoPaths = _photos.map((f) => f.path).toList();
    final result = await _sendToServer(widget.config, fields, photoPaths);
    if (!mounted) return;
    setState(() => _sending = false);

    if (!result.success) {
      if (!result.retryable) {
        final status =
            result.statusCode == null ? '' : ' (código ${result.statusCode})';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El servidor rechazó el envío$status. Revisa los datos.',
            ),
          ),
        );
        return;
      }

      try {
        final queue = await _queue;
        await queue.add(fields, photoPaths);
        _scheduleQueueRetry();
      } on OfflineQueueException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
        return;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar el envío pendiente.'),
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sin respuesta del servidor. Datos y fotos guardados para reintento.',
          ),
        ),
      );
      return;
    }

    final mensaje = _buildMensajeFinal(
      fields,
      lat: _lat,
      lon: _lon,
      fotos: _photos.length,
    );
    await _mostrarPanelExito(mensaje, fotos: _photos);
  }

  /* --------- UI helpers --------- */
  Widget _txt(
    String l,
    TextEditingController c, {
    bool ro = false,
    int lines = 1,
    VoidCallback? onTap,
    bool requiredField = true,
  }) => TextFormField(
    controller: c,
    readOnly: ro,
    maxLines: lines,
    onTap: onTap,
    textInputAction: TextInputAction.next,
    textAlignVertical: TextAlignVertical.center,
    style: const TextStyle(height: 1.3),
    scrollPadding: const EdgeInsets.only(bottom: 160),
    decoration: InputDecoration(labelText: l),
    validator:
        (v) =>
            requiredField
                ? (v == null || v.isEmpty ? 'Obligatorio' : null)
                : null,
  );

  Widget _drop(
    String l,
    List<String> items,
    String? v,
    ValueChanged<String?> onC,
  ) => DropdownButtonFormField<String>(
    value: v,
    isExpanded: true,
    isDense: false,
    iconSize: seniorMode.value ? 28 : 24,
    style: TextStyle(
      color: Colors.black,
      fontSize: seniorMode.value ? 18 : 16,
      height: 1.3,
    ),
    menuMaxHeight: 460,
    items:
        items
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    e,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: seniorMode.value ? 18 : 16,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
    decoration: InputDecoration(labelText: l),
    onChanged: onC,
    validator: (v) => v == null ? 'Seleccione' : null,
  );

  /* --------- UI principal --------- */
  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(
      title: const Text(''),
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: seniorMode,
          builder:
              (_, isSenior, _) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        isSenior ? 'Modo grande' : 'Modo normal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Switch.adaptive(
                      value: isSenior,
                      onChanged: (v) => seniorMode.value = v,
                    ),
                  ],
                ),
              ),
        ),
      ],
    ),
    body: Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE8F4FD), Color(0xFFF8FBFD)],
              ),
            ),
          ),
        ),
        Positioned.fill(child: Container(color: Colors.white70)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: Form(
                    key: _fKey,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      physics: const ClampingScrollPhysics(),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _txt(
                                  'Fecha detección',
                                  _fechaDet,
                                  ro: true,
                                  onTap: () => _pickDate(_fechaDet, es: true),
                                ),
                                const SizedBox(height: 12),
                                _drop(
                                  'Identificador',
                                  _identificadores,
                                  _ident,
                                  (v) => setState(() => _ident = v),
                                ),
                                const SizedBox(height: 12),
                                _drop('Carretera', _carreteras, _carretera, (
                                  v,
                                ) {
                                  setState(() {
                                    _carretera = v;
                                    if (v == 'Ramal A-60') {
                                      _calzada = null;
                                    } else if (v?.startsWith('N') == true) {
                                      _calzada = 'Única';
                                    } else {
                                      _calzada = null;
                                    }
                                  });
                                }),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child:
                                          _isCarreteraN
                                              ? TextFormField(
                                                readOnly: true,
                                                initialValue: 'Única',
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'Calzada',
                                                    ),
                                                validator: (_) => null,
                                              )
                                              : _drop(
                                                'Calzada',
                                                _carretera == 'Ramal A-60'
                                                    ? [
                                                      'Ramal-1',
                                                      'Ramal-2',
                                                      'Ramal-3',
                                                      'Ramal-4',
                                                      'Ramal-5',
                                                      'Ramal-6',
                                                      'Ramal-7',
                                                      'Ramal-8',
                                                    ]
                                                    : _calzadas,
                                                _calzada,
                                                (v) => setState(
                                                  () => _calzada = v,
                                                ),
                                              ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _drop(
                                        'Margen',
                                        _margenes,
                                        _margen,
                                        (v) => setState(() => _margen = v),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _drop(
                                  'Tipo',
                                  _tipos,
                                  _tipo,
                                  (v) => setState(() => _tipo = v),
                                ),
                                const SizedBox(height: 12),
                                _drop(
                                  'Causa',
                                  _causas,
                                  _causa,
                                  (v) => setState(() => _causa = v),
                                ),
                                const SizedBox(height: 12),

                                // Subelemento: campo + lupa, abre buscador con scroll
                                TextFormField(
                                  controller: _subCtrl,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Subelemento',
                                    suffixIcon: Icon(Icons.search),
                                  ),
                                  onTap: _openSubelementoPicker,
                                  validator:
                                      (_) =>
                                          _subelemento == null
                                              ? 'Seleccione'
                                              : null,
                                ),

                                const SizedBox(height: 12),
                                _txt(
                                  'Comentarios',
                                  _comentarios,
                                  lines: 3,
                                  requiredField: false,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _txt(
                                        'Fecha\nConocimiento',
                                        _fCon,
                                        ro: true,
                                        onTap: () => _pickDate(_fCon),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _txt(
                                        'Hora\nConocimiento',
                                        _hCon,
                                        ro: true,
                                        onTap: () => _pickTime(_hCon),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _txt(
                                        'Fecha inicio\nActuación',
                                        _fIni,
                                        ro: true,
                                        onTap: () => _pickDate(_fIni),
                                        requiredField: false,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _txt(
                                        'Hora inicio\nActuación',
                                        _hIni,
                                        ro: true,
                                        onTap: () => _pickTime(_hIni),
                                        requiredField: false,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _txt(
                                  'Fecha fin\nreparación',
                                  _fFin,
                                  ro: true,
                                  onTap: () => _pickDate(_fFin),
                                  requiredField: false,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _lat == null
                                            ? 'Lat/Lon: --'
                                            : '$_lat , $_lon',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: OutlinedButton(
                                        onPressed: _coordsPk,
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Obtener coordenadas'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('PK: ${_pk ?? '--'}'),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: ElevatedButton(
                                        onPressed: _pickPhotos,
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Seleccionar fotos'),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _photos.isEmpty
                                            ? '0/2 seleccionadas'
                                            : '${_photos.length}/2 seleccionadas',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: seniorMode.value ? 160 : 120,
                                  child:
                                      _photos.isEmpty
                                          ? Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey[300],
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Center(
                                              child: Text(
                                                'Sin fotos seleccionadas',
                                              ),
                                            ),
                                          )
                                          : ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemBuilder:
                                                (_, i) => Stack(
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      child: Image.file(
                                                        _photos[i],
                                                        height:
                                                            seniorMode.value
                                                                ? 160
                                                                : 120,
                                                        width:
                                                            seniorMode.value
                                                                ? 200
                                                                : 160,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                    Positioned(
                                                      right: 0,
                                                      child: IconButton(
                                                        icon: const Icon(
                                                          Icons.close,
                                                          color: Colors.red,
                                                        ),
                                                        onPressed:
                                                            () => setState(
                                                              () => _photos
                                                                  .removeAt(i),
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            separatorBuilder:
                                                (_, _) =>
                                                    const SizedBox(width: 8),
                                            itemCount: _photos.length,
                                          ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Proyecto de demostración',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ValueListenableBuilder<bool>(
          valueListenable: seniorMode,
          builder:
              (_, isSenior, _) => SizedBox(
                height: isSenior ? 64 : 56,
                child: ElevatedButton(
                  onPressed: _sending ? null : _submit,
                  child:
                      _sending
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Enviar'),
                ),
              ),
        ),
      ),
    ),
  );
}
