import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class InspeccionSeguridadPage extends StatefulWidget {
  final String nombreObra;
  final String responsable;
  final String fechaInspeccion;
  final String lugarTrabajo;

  const InspeccionSeguridadPage({
    super.key,
    required this.nombreObra,
    required this.responsable,
    required this.fechaInspeccion,
    required this.lugarTrabajo,
  });

  @override
  State<InspeccionSeguridadPage> createState() =>
      _InspeccionSeguridadPageState();
}

class _InspeccionSeguridadPageState extends State<InspeccionSeguridadPage> {
  final ImagePicker _picker = ImagePicker();

  final _preguntas = const [
    'Las zonas de trabajo y acopios se encuentran limpias y ordenadas.',
    'Se han delimitado y diferenciado zonas de paso de peatones y de vehículos.',
    'Aseos, vestuarios, comedor, oficinas adecuados y en buenas condiciones de orden y limpieza',
    'Todos los huecos perimetrales y horizontales se encuentran protegidos y/o delimitados.',
    'Obra y acopios se encuentra correctamente delimitados, balizados y señalizados.',
    'Andamios en buen estado y con todos sus elementos (plataforma, barandillas, rodapié, acceso, certificado montaje, …)',
    'Señalización de carreteras según 8.3 IC, existencia señalistas',
    'Protecciones de ferralla (setas, delimitado, …)',
    'Los trabajadores utilizan correctamente los EPI\'s mínimos (ropa alta visibilidad, calzado de seguridad y en caso necesario guantes, protección de la cabeza, mascarilla y protección auditiva)',
    'Los EPI\'s se encuentran en buen estado.',
    'Se han registrado las entregas de los EPI\'s a los trabajadores.',
    'Líneas de vida, arneses y cabos efectivos y en buen estado',
    'Se disponen medios auxiliares (andamio, escalera, plataforma de trabajo, …) acordes al trabajo a desempeñar y se emplean correctamente',
    'Se dispone de suficiente iluminación en la obra.',
    'Instalación eléctrica en buen estado (cierre, señalización, puesta a tierra, diferenciales…)',
    'Útiles de elevación en buen estado (cadenas, ganchos, eslingas, …)',
    'Disponen las máquinas de interruptores u otros sistemas de paro de emergencia.',
    'Las protecciones de los equipos están operativas.',
    'Protección eléctrica: Disponen de toma de tierra e IP adecuada (Mínimo IP 45)',
    'La maquinaria dispone de rotativo, acústico de marcha atrás, retrovisores, antivuelco, extintor…',
    'Se respetan las medidas preventivas en los izados de cargas',
    'Se dispone en cada caso de la herramienta adecuada y en buen estado',
    'Cuando no se utilizan, están bien guardadas en su sitio y ordenadas.',
    'Si son eléctricas, tienen doble aislamiento y su cableado no presenta deterioro',
    'Se toman medidas ante fenómenos atmosféricos adversos (olas de calor/frío, viento, tormenta eléctrica, …)',
    'Si ha habido accidentes se dispone del informe de investigación de accidentes laborales/incidentes.',
    'Conocen los trabajadores a quien acudir y cómo actuar en caso de emergencia.',
    'Se dispone de medios de extinción suficientes, señalizados, en buen estado y revisados.',
    'Se dispone de botiquín con el contenido adecuado sin caducar.',
    'Se dispone de las Fichas de Datos de Seguridad de los productos químicos',
    'Se encuentran los productos químicos almacenados y manipulados en obra correctamente etiquetados.',
  ];

  late final List<RespuestaPregunta> _respuestas;

  int _current = 0;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _respuestas = List.generate(
      _preguntas.length,
      (i) => RespuestaPregunta()..pregunta = _preguntas[i],
    );
  }

  Future<void> _pickTwoImages(RespuestaPregunta resp) async {
    final files = await _picker.pickMultiImage();

    if (files.length != 2) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona exactamente 2 imágenes.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      resp.evidenciaNoConformidad = File(files[0].path);
      resp.evidenciaCorreccion = File(files[1].path);
    });
  }

  Future<void> _next() async {
    final resp = _respuestas[_current];

    if (resp.estado == null) {
      return;
    }

    if (_current < _preguntas.length - 1) {
      setState(() {
        _current++;
      });
    } else {
      await _enviarResultados();
    }
  }

  void _prev() {
    if (_current > 0) {
      setState(() {
        _current--;
      });
    }
  }

  void _marcarTodasOk() {
    setState(() {
      for (final r in _respuestas) {
        r.limpiarExtras();
        r.estado = 'OK';
      }

      _current = _preguntas.length - 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Todas las respuestas marcadas como OK')),
    );
  }

  Future<void> _enviarResultados() async {
    if (_enviando) return;

    setState(() {
      _enviando = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _enviando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Envío simulado. No se contactó con ningún servidor.'),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    for (final respuesta in _respuestas) {
      respuesta.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resp = _respuestas[_current];
    final requiere = resp.estado == 'NOK';

    final okFotos =
        !requiere ||
        (resp.evidenciaNoConformidad != null &&
            resp.evidenciaCorreccion != null);

    final base = Theme.of(context).textTheme.bodyMedium?.fontSize ?? 16;
    final itemStyle = TextStyle(fontSize: base + 2, color: Colors.black);
    final headingStyle = itemStyle.copyWith(fontWeight: FontWeight.w600);

    return Scaffold(
      appBar: AppBar(title: Text('Obra: ${widget.nombreObra}')),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/fondoINS.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.105)),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_current + 1}/${_preguntas.length}: ${_preguntas[_current]}',
                  style: headingStyle,
                ),

                const SizedBox(height: 20),

                Text('Estado', style: headingStyle),

                for (var e in ['OK', 'NOK', 'N/A'])
                  CheckboxListTile(
                    title: Text(e, style: itemStyle),
                    value: resp.estado == e,
                    onChanged: (_) {
                      setState(() {
                        if (resp.estado != e) {
                          resp.limpiarExtras();
                          resp.estado = e;
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding: EdgeInsets.zero,
                  ),

                if (requiere) ...[
                  const SizedBox(height: 20),

                  Text('Gravedad', style: headingStyle),

                  for (var g in ['LEVE', 'MODERADO', 'GRAVE'])
                    CheckboxListTile(
                      title: Text(g, style: itemStyle),
                      value: resp.gravedad == g,
                      onChanged: (_) {
                        setState(() {
                          resp.gravedad = g;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: EdgeInsets.zero,
                    ),

                  const SizedBox(height: 10),

                  Text('Resuelta', style: headingStyle),

                  for (var r in ['SI', 'NO'])
                    CheckboxListTile(
                      title: Text(r, style: itemStyle),
                      value: resp.resuelta == r,
                      onChanged: (_) {
                        setState(() {
                          resp.resuelta = r;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: EdgeInsets.zero,
                    ),

                  const SizedBox(height: 10),

                  TextFormField(
                    controller: resp.observaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones',
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.grey[200],
                          child: InkWell(
                            onTap: () => _pickTwoImages(resp),
                            child: SizedBox(
                              height: 100,
                              width: double.infinity,
                              child:
                                  resp.evidenciaNoConformidad != null
                                      ? Image.file(
                                        resp.evidenciaNoConformidad!,
                                        fit: BoxFit.cover,
                                      )
                                      : const Icon(Icons.photo_library),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: Material(
                          color: Colors.grey[200],
                          child: InkWell(
                            onTap: () => _pickTwoImages(resp),
                            child: SizedBox(
                              height: 100,
                              width: double.infinity,
                              child:
                                  resp.evidenciaCorreccion != null
                                      ? Image.file(
                                        resp.evidenciaCorreccion!,
                                        fit: BoxFit.cover,
                                      )
                                      : const Icon(Icons.photo_library),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                Row(
                  children: [
                    if (_current > 0)
                      ElevatedButton(
                        onPressed: _enviando ? null : _prev,
                        child: Text('Anterior', style: itemStyle),
                      ),

                    const SizedBox(width: 8),

                    ElevatedButton(
                      onPressed: _enviando ? null : _marcarTodasOk,
                      child: Text('Todas OK', style: itemStyle),
                    ),

                    const Spacer(),

                    ElevatedButton(
                      onPressed:
                          resp.estado != null && okFotos && !_enviando
                              ? _next
                              : null,
                      child: Text(
                        _current < _preguntas.length - 1
                            ? 'Siguiente'
                            : (_enviando ? 'Enviando…' : 'Enviar'),
                        style: itemStyle,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),

          if (_enviando)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Enviando inspección...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RespuestaPregunta {
  String? pregunta;
  String? estado;
  String? gravedad;
  String? resuelta;

  final medidaCtrl = TextEditingController();
  final observaCtrl = TextEditingController();

  File? evidenciaNoConformidad;
  File? evidenciaCorreccion;

  void limpiarExtras() {
    gravedad = null;
    resuelta = null;
    medidaCtrl.clear();
    observaCtrl.clear();
    evidenciaNoConformidad = null;
    evidenciaCorreccion = null;
  }

  void dispose() {
    medidaCtrl.dispose();
    observaCtrl.dispose();
  }
}
