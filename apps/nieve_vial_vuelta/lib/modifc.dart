import 'package:flutter/material.dart';

import 'main.dart' show ApiClient, Parte, Tramo;

class ModifcPage extends StatefulWidget {
  final ApiClient api;

  const ModifcPage({
    super.key,
    required this.api,
  });

  @override
  State<ModifcPage> createState() => _ModifcPageState();
}

class _ModifcPageState extends State<ModifcPage> {
  final _updatedByCtrl = TextEditingController(text: 'app2-modifc');

  final _objetivoMinaCtrl = TextEditingController(text: '0');
  final _objetivoMarinaCtrl = TextEditingController(text: '0');
  final _objetivoSalmueraCtrl = TextEditingController(text: '0');

  final List<_SiloRow> _silos = [];

  bool _loading = false;
  bool _modulacionActiva = false;
  String? _error;

  List<Parte> _partes = [];

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  @override
  void dispose() {
    _updatedByCtrl.dispose();
    _objetivoMinaCtrl.dispose();
    _objetivoMarinaCtrl.dispose();
    _objetivoSalmueraCtrl.dispose();

    for (final s in _silos) {
      s.dispose();
    }

    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final activa = await widget.api.getModulacionActiva();
      final objetivos = await widget.api.getModulacionObjetivos();
      final partes = await widget.api.listPartes();

      _objetivoMinaCtrl.text = '${objetivos['objetivo_mina'] ?? 0}';
      _objetivoMarinaCtrl.text = '${objetivos['objetivo_marina'] ?? 0}';
      _objetivoSalmueraCtrl.text = '${objetivos['objetivo_salmuera'] ?? 0}';

      for (final s in _silos) {
        s.dispose();
      }
      _silos.clear();

      final objetivosSilo = objetivos['objetivos_silo'];
      if (objetivosSilo is Map) {
        for (final e in objetivosSilo.entries) {
          final row = _SiloRow();
          row.idCtrl.text = '${e.key}';
          row.cantidadCtrl.text = '${e.value}';
          _silos.add(row);
        }
      }

      if (!mounted) return;

      setState(() {
        _modulacionActiva = activa;
        _partes = partes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  double _parseNum(String s) {
    return double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;
  }

  String _materialReal(Tramo t) {
    final mat = (t.materialSolido ?? t.material ?? '').trim();

    if (mat.isNotEmpty && mat != 'Sin fundente') return mat;
    if ((t.consumoSalmueraL ?? 0) > 0) return 'Salmuera';
    if ((t.consumoSalT ?? 0) > 0) return 'Sal de mina';

    return 'Sin fundente';
  }

  _ResumenActual _calcularResumenActual() {
    double mina = 0;
    double marina = 0;
    double salmuera = 0;
    final silos = <int, double>{};

    for (final parte in _partes) {
      for (final t in parte.tramos) {
        final mat = _materialReal(t);

        if (mat == 'Sal de mina') {
          mina += t.consumoSalT ?? 0;
        } else if (mat == 'Sal marina') {
          marina += t.consumoSalT ?? 0;
        } else if (mat == 'Salmuera') {
          salmuera += t.consumoSalmueraL ?? 0;
        } else if (mat == 'Sal de silo') {
          final sid = t.siloId;
          if (sid != null) {
            silos[sid] = (silos[sid] ?? 0) + (t.consumoSalT ?? 0);
          }
        }
      }
    }

    return _ResumenActual(
      mina: mina,
      marina: marina,
      salmuera: salmuera,
      silos: silos,
    );
  }

  String _updatedBy() {
    return _updatedByCtrl.text.trim().isEmpty
        ? 'app2-modifc'
        : _updatedByCtrl.text.trim();
  }

  Future<void> _cambiarEstado(bool value) async {
    final anterior = _modulacionActiva;

    setState(() {
      _modulacionActiva = value;
      _error = null;
    });

    try {
      await widget.api.setModulacionActiva(value);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _modulacionActiva = anterior;
        _error = '$e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cambiando modulación: $e')),
      );
    }
  }

  Future<void> _guardarCupos() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final objetivosSilo = <String, dynamic>{};

      for (final s in _silos) {
        final id = s.idCtrl.text.trim();
        if (id.isEmpty) continue;
        objetivosSilo[id] = _parseNum(s.cantidadCtrl.text);
      }

      await widget.api.setModulacionObjetivos(
        objetivoMina: _parseNum(_objetivoMinaCtrl.text),
        objetivoMarina: _parseNum(_objetivoMarinaCtrl.text),
        objetivoSalmuera: _parseNum(_objetivoSalmueraCtrl.text),
        objetivosSilo: objetivosSilo,
        updatedBy: _updatedBy(),
      );

      final result = await widget.api.recalcularModulacion();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cupos guardados. Cambios: ${result['result']?['cambios'] ?? 0}',
          ),
        ),
      );

      await _cargarTodo();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = '$e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando cupos: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _recalcularAhora() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.api.recalcularModulacion();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recalculado. Cambios: ${result['result']?['cambios'] ?? 0}',
          ),
        ),
      );

      await _cargarTodo();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = '$e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recalculando: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _abrirStock() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockActualPage(api: widget.api),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resumen = _calcularResumenActual();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cupos de modulación'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _cargarTodo,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Modulación activa'),
              subtitle: Text(
                _modulacionActiva
                    ? 'El backend recalcula automáticamente'
                    : 'El backend no aplicará ajustes robot',
              ),
              value: _modulacionActiva,
              onChanged: _cambiarEstado,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _updatedByCtrl,
              decoration: const InputDecoration(
                labelText: 'updated_by',
              ),
            ),
            const SizedBox(height: 20),
            _ResumenCard(resumen: resumen),
            const SizedBox(height: 24),
            Text(
              'Cupos objetivo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _objetivoMinaCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cupo sal de mina (t)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _objetivoMarinaCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cupo sal marina (t)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _objetivoSalmueraCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cupo salmuera (L)',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Cupos por silo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _silos.add(_SiloRow());
                    });
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (_silos.isEmpty)
              const Text('Sin cupos por silo')
            else
              ..._silos.map(
                    (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: s.idCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Silo ID',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: s.cantidadCtrl,
                          keyboardType:
                          const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Cupo silo (t)',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            s.dispose();
                            _silos.remove(s);
                          });
                        },
                        icon: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _guardarCupos,
                    child: const Text('Guardar cupos'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _recalcularAhora,
                    child: const Text('Recalcular ahora'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: OutlinedButton.icon(
                onPressed: _abrirStock,
                icon: const Icon(Icons.warehouse),
                label: const Text(
                  'Fijar stock actual',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class StockActualPage extends StatefulWidget {
  final ApiClient api;

  const StockActualPage({
    super.key,
    required this.api,
  });

  @override
  State<StockActualPage> createState() => _StockActualPageState();
}

class _StockActualPageState extends State<StockActualPage> {
  final _updatedByCtrl = TextEditingController(text: 'app2-modifc');

  final _stockMinaCtrl = TextEditingController(text: '0');
  final _stockMarinaCtrl = TextEditingController(text: '0');
  final _stockSalmueraCtrl = TextEditingController(text: '0');

  final List<_SiloRow> _silosStock = [];

  bool _loading = false;
  String? _error;

  List<Parte> _partes = [];
  List<Map<String, dynamic>> _stockBase = [];

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  @override
  void dispose() {
    _updatedByCtrl.dispose();
    _stockMinaCtrl.dispose();
    _stockMarinaCtrl.dispose();
    _stockSalmueraCtrl.dispose();

    for (final s in _silosStock) {
      s.dispose();
    }

    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final partes = await widget.api.listPartes();
      final stockBase = await widget.api.getStockBase();

      final resumen = _calcularResumenDesdePartes(partes);

      _stockMinaCtrl.text = resumen.mina.toStringAsFixed(3);
      _stockMarinaCtrl.text = resumen.marina.toStringAsFixed(3);
      _stockSalmueraCtrl.text = resumen.salmuera.toStringAsFixed(0);

      for (final s in _silosStock) {
        s.dispose();
      }
      _silosStock.clear();

      final silosOrdenados = resumen.silos.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      for (final e in silosOrdenados) {
        final row = _SiloRow();
        row.idCtrl.text = '${e.key}';
        row.cantidadCtrl.text = e.value.toStringAsFixed(3);
        _silosStock.add(row);
      }

      if (!mounted) return;

      setState(() {
        _partes = partes;
        _stockBase =
            ((stockBase['items'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  double _parseNum(String s) {
    return double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;
  }

  int? _parseIntOrNull(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  String _updatedBy() {
    return _updatedByCtrl.text.trim().isEmpty
        ? 'app2-modifc'
        : _updatedByCtrl.text.trim();
  }

  String _materialReal(Tramo t) {
    final mat = (t.materialSolido ?? t.material ?? '').trim();

    if (mat.isNotEmpty && mat != 'Sin fundente') return mat;
    if ((t.consumoSalmueraL ?? 0) > 0) return 'Salmuera';
    if ((t.consumoSalT ?? 0) > 0) return 'Sal de mina';

    return 'Sin fundente';
  }

  _ResumenActual _calcularResumenDesdePartes(List<Parte> partes) {
    double mina = 0;
    double marina = 0;
    double salmuera = 0;
    final silos = <int, double>{};

    for (final parte in partes) {
      for (final t in parte.tramos) {
        final mat = _materialReal(t);

        if (mat == 'Sal de mina') {
          mina += t.consumoSalT ?? 0;
        } else if (mat == 'Sal marina') {
          marina += t.consumoSalT ?? 0;
        } else if (mat == 'Salmuera') {
          salmuera += t.consumoSalmueraL ?? 0;
        } else if (mat == 'Sal de silo') {
          final sid = t.siloId;
          if (sid != null) {
            silos[sid] = (silos[sid] ?? 0) + (t.consumoSalT ?? 0);
          }
        }
      }
    }

    return _ResumenActual(
      mina: mina,
      marina: marina,
      salmuera: salmuera,
      silos: silos,
    );
  }

  _ResumenActual _calcularResumenActual() {
    return _calcularResumenDesdePartes(_partes);
  }

  Future<void> _fijarStockActual() async {
    final resumen = _calcularResumenActual();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.api.fijarStockActual(
        material: 'Sal de mina',
        siloId: null,
        stockActualT: resumen.mina,
        stockObjetivoT: _parseNum(_stockMinaCtrl.text),
        stockActualL: 0,
        stockObjetivoL: 0,
        updatedBy: _updatedBy(),
      );

      await widget.api.fijarStockActual(
        material: 'Sal marina',
        siloId: null,
        stockActualT: resumen.marina,
        stockObjetivoT: _parseNum(_stockMarinaCtrl.text),
        stockActualL: 0,
        stockObjetivoL: 0,
        updatedBy: _updatedBy(),
      );

      await widget.api.fijarStockActual(
        material: 'Salmuera',
        siloId: null,
        stockActualT: 0,
        stockObjetivoT: 0,
        stockActualL: resumen.salmuera,
        stockObjetivoL: _parseNum(_stockSalmueraCtrl.text),
        updatedBy: _updatedBy(),
      );

      for (final s in _silosStock) {
        final siloId = _parseIntOrNull(s.idCtrl.text);
        if (siloId == null) continue;

        final actual = resumen.silos[siloId] ?? 0;
        final objetivo = _parseNum(s.cantidadCtrl.text);

        await widget.api.fijarStockActual(
          material: 'Sal de silo',
          siloId: siloId,
          stockActualT: actual,
          stockObjetivoT: objetivo,
          stockActualL: 0,
          stockObjetivoL: 0,
          updatedBy: _updatedBy(),
        );
      }

      final result = await widget.api.recalcularModulacion();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock fijado. Cambios: ${result['result']?['cambios'] ?? 0}',
          ),
        ),
      );

      await _cargarTodo();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = '$e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fijando stock: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumen = _calcularResumenActual();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock actual'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _cargarTodo,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _updatedByCtrl,
              decoration: const InputDecoration(
                labelText: 'updated_by',
              ),
            ),
            const SizedBox(height: 20),
            _ResumenCard(resumen: resumen),
            const SizedBox(height: 24),
            Text(
              'Fijar stock actual',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _stockMinaCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                'Stock real sal de mina (t) · registrado ${resumen.mina.toStringAsFixed(3)} t',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _stockMarinaCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                'Stock real sal marina (t) · registrado ${resumen.marina.toStringAsFixed(3)} t',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _stockSalmueraCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                'Stock real salmuera (L) · registrado ${resumen.salmuera.toStringAsFixed(0)} L',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Stock real por silo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _silosStock.add(_SiloRow());
                    });
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (_silosStock.isEmpty)
              const Text('Sin stock por silo')
            else
              ..._silosStock.map(
                    (s) {
                  final sid = _parseIntOrNull(s.idCtrl.text);
                  final registrado =
                  sid == null ? 0 : (resumen.silos[sid] ?? 0);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: s.idCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Silo ID',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: s.cantidadCtrl,
                            keyboardType:
                            const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                              'Stock real (t) · reg. ${registrado.toStringAsFixed(3)}',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              s.dispose();
                              _silosStock.remove(s);
                            });
                          },
                          icon: const Icon(Icons.delete),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _fijarStockActual,
                icon: const Icon(Icons.save),
                label: const Text('Fijar stock actual'),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ajustes contables guardados',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_stockBase.isEmpty)
              const Text('Sin ajustes contables')
            else
              ..._stockBase.map(
                    (s) => Card(
                  child: ListTile(
                    title: Text(
                      '${s['material'] ?? '-'}'
                          '${s['silo_id'] != null ? ' · silo ${s['silo_id']}' : ''}',
                    ),
                    subtitle: Text(
                      'Ajuste: ${s['cantidad_t'] ?? '-'} t · ${s['cantidad_l'] ?? '-'} L\n'
                          '${s['motivo'] ?? ''}',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResumenCard extends StatelessWidget {
  final _ResumenActual resumen;

  const _ResumenCard({
    required this.resumen,
  });

  @override
  Widget build(BuildContext context) {
    final silos = resumen.silos.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registrado en partes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Sal de mina: ${resumen.mina.toStringAsFixed(3)} t'),
            Text('Sal marina: ${resumen.marina.toStringAsFixed(3)} t'),
            Text('Salmuera: ${resumen.salmuera.toStringAsFixed(0)} L'),
            const SizedBox(height: 8),
            if (silos.isEmpty)
              const Text('Sin sal por silo')
            else
              ...silos.map(
                    (e) => Text('Silo ${e.key}: ${e.value.toStringAsFixed(3)} t'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SiloRow {
  final TextEditingController idCtrl = TextEditingController();
  final TextEditingController cantidadCtrl = TextEditingController();

  void dispose() {
    idCtrl.dispose();
    cantidadCtrl.dispose();
  }
}

class _ResumenActual {
  final double mina;
  final double marina;
  final double salmuera;
  final Map<int, double> silos;

  _ResumenActual({
    required this.mina,
    required this.marina,
    required this.salmuera,
    required this.silos,
  });
}