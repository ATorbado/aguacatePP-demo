import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/diary_entry.dart';
import '../services/database_service.dart';

class EditEntryPage extends StatefulWidget {
  final DiaryEntry entry;

  const EditEntryPage({super.key, required this.entry});

  @override
  State<EditEntryPage> createState() => _EditEntryPageState();
}

class _EditEntryPageState extends State<EditEntryPage> {
  late DiaryEntry _entry;
  late TextEditingController _bodyCtrl;
  late TextEditingController _reminderCtrl;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _bodyCtrl = TextEditingController(text: _entry.body);
    _reminderCtrl = TextEditingController(text: _entry.reminder);
    _selectedDate = DateTime.parse(_entry.entryDate);
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _reminderCtrl.dispose();
    super.dispose();
  }

  String get _entryDate => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    final saved = _entry.copyWith(
      entryDate: _entryDate,
      body: _bodyCtrl.text.trim(),
      reminder: _reminderCtrl.text.trim(),
    );

    await DatabaseService.instance.saveEntry(saved);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guardado correctamente')),
    );
    Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    if (_entry.id == null) {
      Navigator.pop(context);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar entrada'),
        content: const Text('¿Seguro que quieres borrar este día?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await DatabaseService.instance.deleteEntry(_entry.id!);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final shownDate = DateFormat('EEEE, d MMMM y', 'es_ES').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Escribir diario')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(shownDate, style: const TextStyle(fontSize: 17)),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: TextField(
                  controller: _bodyCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: '¿Qué tal ha ido el día?',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _reminderCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Recordatorio',
                  hintText: 'Ejemplo: comprar pan, llamar al médico...',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('GUARDAR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
