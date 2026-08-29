import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/diary_entry.dart';
import '../services/database_service.dart';
import 'edit_entry_page.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  late Future<List<DiaryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = DatabaseService.instance.getEntriesWithReminders();
  }

  Future<void> _open(DiaryEntry entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditEntryPage(entry: entry)),
    );

    if (!mounted) return;
    setState(_load);
  }

  Future<void> _completeReminder(DiaryEntry entry) async {
    if (entry.id == null) return;

    await DatabaseService.instance.completeReminder(entry.id!);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recordatorio completado')),
    );

    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recordatorios')),
      body: FutureBuilder<List<DiaryEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const Center(child: Text('No hay recordatorios pendientes.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final e = entries[index];
              final date = DateFormat('dd/MM/yyyy').format(DateTime.parse(e.entryDate));

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications),
                  title: Text(date),
                  subtitle: Text(e.reminder),
                  trailing: IconButton(
                    icon: const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                    tooltip: 'Marcar como completo',
                    onPressed: () => _completeReminder(e),
                  ),
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
