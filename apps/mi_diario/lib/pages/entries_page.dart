import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/diary_entry.dart';
import '../services/database_service.dart';
import 'edit_entry_page.dart';

class EntriesPage extends StatefulWidget {
  const EntriesPage({super.key});

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {
  late Future<List<DiaryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = DatabaseService.instance.getAllEntries();
  }

  Future<void> _open(DiaryEntry entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditEntryPage(entry: entry)),
    );
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ver diario')),
      body: FutureBuilder<List<DiaryEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const Center(child: Text('Todavía no hay entradas.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final e = entries[index];
              final date = DateFormat('EEEE, d MMMM y', 'es_ES')
                  .format(DateTime.parse(e.entryDate));
              final preview = e.body.isEmpty ? 'Sin texto' : e.body;

              return Card(
                child: ListTile(
                  title: Text(
                    date,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(e),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
