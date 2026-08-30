import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart' show
ApiClient,
Parte,
Tramo,
TramoAgrupado,
agruparTramosConsecutivos,
calcRangoTurno,
matriculaFromId;

class PartesHome extends StatefulWidget {
  final ApiClient api;

  const PartesHome({
    super.key,
    required this.api,
  });

  @override
  State<PartesHome> createState() => _PartesHomeState();
}

class _PartesHomeState extends State<PartesHome> {
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final rango = calcRangoTurno(now);
    _from = rango.start;
    _to = rango.end;
  }

  void _abrirLista() {
    if (_from == null || _to == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PartesListPage(
          api: widget.api,
          from: _from!,
          to: _to!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = _from;
    final t = _to;
    String rango = '';
    if (f != null && t != null) {
      rango = '${f.toLocal()} → ${t.toLocal()}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partes de nieve Supervisor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Rango de turnos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(rango),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _abrirLista,
                child: const Text('Recoger info'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PartesListPage extends StatefulWidget {
  final ApiClient api;
  final DateTime from;
  final DateTime to;

  const PartesListPage({
    super.key,
    required this.api,
    required this.from,
    required this.to,
  });

  @override
  State<PartesListPage> createState() => _PartesListPageState();
}

class _PartesListPageState extends State<PartesListPage> {
  late Future<List<Parte>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.listPartes(from: widget.from, to: widget.to);
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.api.listPartes(from: widget.from, to: widget.to);
    });
  }

  bool _esParteEditable(Parte p) {
    final status = (p.status ?? '').trim().toLowerCase();
    return status != 'confirmed' && status != 'closededt';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partes encontrados'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Parte>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar: ${snapshot.error}'),
            );
          }

          final allPartes = snapshot.data ?? [];
          final partes = allPartes.where(_esParteEditable).toList();

          if (partes.isEmpty) {
            return const Center(child: Text('No hay partes pendientes'));
          }

          return ListView.separated(
            itemCount: partes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final p = partes[index];
              return ListTile(
                title: Text(
                  'Parte #${p.id} - Mat ${p.matriculaId ?? '-'} - ${p.operario ?? '-'}',
                ),
                subtitle: Text(
                  'Fecha: ${p.fecha ?? ''} • Estado: ${p.status ?? 'pending'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final refreshed = await Navigator.of(context).push<Parte?>(
                    MaterialPageRoute(
                      builder: (_) => ParteDetailPage(
                        api: widget.api,
                        parteId: p.id,
                      ),
                    ),
                  );

                  if (refreshed != null) {
                    await _reload();
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ParteDetailPage extends StatefulWidget {
  final ApiClient api;
  final int parteId;

  const ParteDetailPage({
    super.key,
    required this.api,
    required this.parteId,
  });

  @override
  State<ParteDetailPage> createState() => _ParteDetailPageState();
}

class _ParteDetailPageState extends State<ParteDetailPage> {
  Parte? _parte;
  bool _loading = true;
  String? _error;

  final TextEditingController _updatedBy =
  TextEditingController(text: 'app2-device');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _updatedBy.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final p = await widget.api.getParte(widget.parteId);
      setState(() {
        _parte = p;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String? _validaHorasTramos(Parte p) {
    for (final t in p.tramos) {
      final hIni = t.hora?.trim() ?? '';
      final hFin = t.horaFin?.trim() ?? '';
      if (hIni.isEmpty || hFin.isEmpty) {
        return 'Todos los tramos deben tener hora inicio y hora fin';
      }
    }
    return null;
  }

  Future<void> _guardarTramos() async {
    final p = _parte;
    if (p == null) return;

    final errHoras = _validaHorasTramos(p);
    if (errHoras != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errHoras)),
      );
      return;
    }

    try {
      final upd = _updatedBy.text.trim().isEmpty
          ? 'app2-device'
          : _updatedBy.text.trim();

      await widget.api.patchTramos(
        parteId: p.id,
        tramos: p.tramos,
        updatedBy: upd,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tramos guardados')),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  Future<void> _confirmar() async {
    final p = _parte;
    if (p == null) return;

    final upd = _updatedBy.text.trim().isEmpty
        ? 'app2-device'
        : _updatedBy.text.trim();

    try {
      await widget.api.confirmarParte(
        parteId: p.id,
        updatedBy: upd,
      );

      final r = await widget.api.exportPdfConfirmado(
        parteId: p.id,
        updatedBy: upd,
      );

      final savedPath = r['saved_path']?.toString() ?? '-';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Parte confirmado. PDF guardado en: $savedPath')),
      );

      Navigator.of(context).pop(p);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _parte;

    return Scaffold(
      appBar: AppBar(
        title: Text('Parte #${widget.parteId}'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(p),
      bottomNavigationBar: p == null
          ? null
          : Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _guardarTramos,
                child: const Text('Guardar tramos'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _confirmar,
                child: const Text('Confirmar parte'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Parte? p) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (p == null) {
      return const Center(child: Text('Parte no encontrado'));
    }

    final agrupados = agruparTramosConsecutivos(
      p.tramos
          .where((t) => t.actividad == 'DEMO-01' || t.actividad == 'DEMO-02')
          .toList(),
    );

    String fmtFecha(DateTime? dt) {
      if (dt == null) return '-';
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();
      return '$dd/$mm/$yyyy';
    }

    String fmtFechaCampo(String? raw) {
      if (raw == null || raw.isEmpty) return '-';
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw;
      final l = dt.toLocal();
      final dd = l.day.toString().padLeft(2, '0');
      final mm = l.month.toString().padLeft(2, '0');
      final yyyy = l.year.toString();
      return '$dd/$mm/$yyyy';
    }

    late final String fechaParteStr;
    if (p.fechaHoraInicioParte != null || p.fechaHoraFinParte != null) {
      fechaParteStr =
      '${fmtFecha(p.fechaHoraInicioParte)} → ${fmtFecha(p.fechaHoraFinParte)}';
    } else {
      fechaParteStr = fmtFechaCampo(p.fecha);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Camion',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('Fecha parte: $fechaParteStr'),
          Text('Operario: ${p.operario ?? '-'}'),
          Text('Matricula: ${matriculaFromId(p.matriculaId)}'),
          Text('KM: ${p.kmInicio ?? '-'} → ${p.kmFin ?? '-'}'),
          Text('Horas contador: ${p.horasInicio ?? '-'} → ${p.horasFin ?? '-'}'),
          const SizedBox(height: 16),
          Text(
            'Tramos agrupados',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: agrupados.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final t = agrupados[index];
              return _TramoAgrupadoTile(t: t);
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Tramos editables',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: p.tramos.length,
            itemBuilder: (context, index) {
              final t = p.tramos[index];
              return _TramoEditCard(tramo: t);
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _TramoAgrupadoTile extends StatelessWidget {
  final TramoAgrupado t;

  const _TramoAgrupadoTile({
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final pkIniStr = t.pkIni == null ? '-' : '${t.pkIni},${t.mIni ?? 0}';
    final pkFinStr = t.pkFin == null ? '-' : '${t.pkFin},${t.mFin ?? 0}';
    final horasStr = '${t.horaIni ?? '-'} → ${t.horaFin ?? '-'}';

    return ListTile(
      title: Text(
        '${t.actividad ?? '-'} - tramo ${t.tramo ?? '-'} - ${t.ctra ?? ''}',
      ),
      subtitle: Text(
        'PK $pkIniStr → $pkFinStr\n'
            'Horas tramo: $horasStr\n'
            'Sal solida: ${t.totalSalT.toStringAsFixed(2)} t\n'
            'Salmuera: ${t.totalSalmueraL.toStringAsFixed(0)} L\n'
            'CLCA: ${t.totalClcaKg.toStringAsFixed(0)} kg\n'
            'Tramos originales: ${t.origen.length}',
      ),
    );
  }
}

class _TramoEditCard extends StatefulWidget {
  final Tramo tramo;

  const _TramoEditCard({
    required this.tramo,
  });

  @override
  State<_TramoEditCard> createState() => _TramoEditCardState();
}

class _TramoEditCardState extends State<_TramoEditCard> {
  late final TextEditingController _ctraCtrl;
  late final TextEditingController _pkIniCtrl;
  late final TextEditingController _mIniCtrl;
  late final TextEditingController _pkFinCtrl;
  late final TextEditingController _mFinCtrl;
  late final TextEditingController _horaIniCtrl;
  late final TextEditingController _horaFinCtrl;
  late final TextEditingController _salTCtrl;
  late final TextEditingController _salmueraCtrl;
  late final TextEditingController _clcaCtrl;

  @override
  void initState() {
    super.initState();
    final t = widget.tramo;

    _ctraCtrl = TextEditingController(text: t.ctra ?? '');
    _pkIniCtrl = TextEditingController(text: t.pkIni?.toString() ?? '');
    _mIniCtrl = TextEditingController(text: t.mIni?.toString() ?? '');
    _pkFinCtrl = TextEditingController(text: t.pkFin?.toString() ?? '');
    _mFinCtrl = TextEditingController(text: t.mFin?.toString() ?? '');
    _horaIniCtrl = TextEditingController(text: t.hora ?? '');
    _horaFinCtrl = TextEditingController(text: t.horaFin ?? '');
    _salTCtrl = TextEditingController(
      text: (t.consumoSalTRobot ?? t.consumoSalT)?.toString() ?? '',
    );
    _salmueraCtrl = TextEditingController(
      text: (t.consumoSalmueraLRobot ?? t.consumoSalmueraL)?.toString() ?? '',
    );
    _clcaCtrl = TextEditingController(text: t.clcaKg?.toString() ?? '');

    _ctraCtrl.addListener(() => t.ctra = _ctraCtrl.text.trim());
    _pkIniCtrl.addListener(() => t.pkIni = int.tryParse(_pkIniCtrl.text.trim()));
    _mIniCtrl.addListener(() => t.mIni = int.tryParse(_mIniCtrl.text.trim()));
    _pkFinCtrl.addListener(() => t.pkFin = int.tryParse(_pkFinCtrl.text.trim()));
    _mFinCtrl.addListener(() => t.mFin = int.tryParse(_mFinCtrl.text.trim()));
    _horaIniCtrl.addListener(() => t.hora = _horaIniCtrl.text.trim());
    _horaFinCtrl.addListener(() {
      t.horaFin = _horaFinCtrl.text.trim().isEmpty
          ? null
          : _horaFinCtrl.text.trim();
    });

    _salTCtrl.addListener(() {
      t.consumoSalT = _parseDouble(_salTCtrl.text);
    });
    _salmueraCtrl.addListener(() {
      t.consumoSalmueraL = _parseDouble(_salmueraCtrl.text);
    });
    _clcaCtrl.addListener(() {
      t.clcaKg = _parseDouble(_clcaCtrl.text);
    });
  }

  double? _parseDouble(String s) {
    if (s.trim().isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  @override
  void dispose() {
    _ctraCtrl.dispose();
    _pkIniCtrl.dispose();
    _mIniCtrl.dispose();
    _pkFinCtrl.dispose();
    _mFinCtrl.dispose();
    _horaIniCtrl.dispose();
    _horaFinCtrl.dispose();
    _salTCtrl.dispose();
    _salmueraCtrl.dispose();
    _clcaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tramo;

    final materialVisible =
        t.materialRobot ?? t.materialSolido ?? t.material ?? 'tipo no indicado';

    final hayRobot = t.materialRobot != null ||
        t.consumoSalTRobot != null ||
        t.consumoSalmueraLRobot != null;


    final titulo =
        '${t.actividad ?? '-'} - Tramo ${t.numero ?? '-'} (id ${t.id ?? '-'})';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (hayRobot) ...[
              const SizedBox(height: 6),
              Text(
                'Modulado: ${t.materialRobot ?? materialVisible}'
                    '${t.consumoSalTRobot != null ? ' · ${t.consumoSalTRobot} t' : ''}'
                    '${t.consumoSalmueraLRobot != null ? ' · ${t.consumoSalmueraLRobot} L' : ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _ctraCtrl,
              decoration: const InputDecoration(
                labelText: 'Carretera (ctra)',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pkIniCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'PK inicio',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _mIniCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'm inicio',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pkFinCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'PK fin',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _mFinCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'm fin',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _horaIniCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Hora inicio tramo (HH:mm)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _horaFinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Hora fin tramo (HH:mm)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _salTCtrl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Sal sólida tramo ($materialVisible)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _salmueraCtrl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Salmuera tramo (L)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _clcaCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'CLCA tramo (kg)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
