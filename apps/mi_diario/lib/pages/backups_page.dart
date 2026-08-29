import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../services/backup_service.dart';

class BackupsPage extends StatefulWidget {
  const BackupsPage({super.key});

  @override
  State<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends State<BackupsPage> {
  late Future<List<File>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = BackupService.instance.listBackups();

  Future<void> _manualBackup() async {
    setState(() => _busy = true);
    await BackupService.instance.shareManualBackup();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _load();
    });
  }

  Future<void> _importBackup() async {
    setState(() => _busy = true);
    final count = await BackupService.instance.importBackupFromFile();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _load();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Entradas importadas: $count')),
    );
  }

  Future<void> _share(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Copia de seguridad de Mi Diario',
        files: [XFile(file.path)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Copias')),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _manualBackup,
                icon: const Icon(Icons.share),
                label: const Text('HACER Y COMPARTIR COPIA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _importBackup,
                icon: const Icon(Icons.file_open),
                label: const Text('RECUPERAR COPIA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_busy) const LinearProgressIndicator(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Últimas copias guardadas en el móvil'),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<File>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final files = snapshot.data!;
                  if (files.isEmpty) {
                    return const Center(child: Text('Todavía no hay copias.'));
                  }
                  return ListView.separated(
                    itemCount: files.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final file = files[index];
                      final modified = file.lastModifiedSync();
                      return Card(
                        child: ListTile(
                          title: Text(p.basename(file.path)),
                          subtitle: Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(modified),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () => _share(file),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
