import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/diary_entry.dart';
import '../services/database_service.dart';
import '../widgets/big_button.dart';
import 'backups_page.dart';
import 'edit_entry_page.dart';
import 'entries_page.dart';
import 'reminders_page.dart';
import 'search_page.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _openEntryForSelectedDate(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Selecciona el día del diario',
      cancelText: 'CANCELAR',
      confirmText: 'ACEPTAR',
    );

    if (selected == null) return;

    final date = DateFormat('yyyy-MM-dd').format(selected);
    final existing = await DatabaseService.instance.getEntryByDate(date);
    final entry = existing ?? DiaryEntry.newEmpty(date);

    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditEntryPage(entry: entry)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7700);
    const blue = Color(0xFF1976D2);
    const green = Color(0xFF2E7D32);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Diario')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Text(
                '¿Qué quieres hacer?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              BigButton(
                text: 'ESCRIBIR DÍA',
                icon: Icons.edit_calendar,
                color: orange,
                onPressed: () => _openEntryForSelectedDate(context),
              ),
              const SizedBox(height: 14),
              BigButton(
                text: 'VER DIARIO',
                icon: Icons.menu_book,
                color: blue,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EntriesPage()),
                ),
              ),
              const SizedBox(height: 14),
              BigButton(
                text: 'BUSCAR',
                icon: Icons.search,
                color: blue,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchPage()),
                ),
              ),
              const SizedBox(height: 14),
              BigButton(
                text: 'RECORDATORIOS',
                icon: Icons.notifications,
                color: green,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RemindersPage()),
                ),
              ),
              const SizedBox(height: 14),
              BigButton(
                text: 'COPIAS',
                icon: Icons.backup,
                color: green,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BackupsPage()),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
                icon: const Icon(Icons.settings),
                label: const Text('Ajustes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
