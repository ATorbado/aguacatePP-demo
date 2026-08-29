import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/diary_entry.dart';
import '../services/database_service.dart';
import 'edit_entry_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchCtrl = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  List<DiaryEntry> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    final results = await DatabaseService.instance.searchEntries(
      text: _searchCtrl.text,
      from: _from,
      to: _to,
    );
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _to = picked);
  }

  Future<void> _open(DiaryEntry entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditEntryPage(entry: entry)),
    );
    await _search();
  }

  String _dateLabel(DateTime? d, String empty) {
    if (d == null) return empty;
    return DateFormat('dd/MM/yyyy').format(d);
  }

  void _clearDates() {
    setState(() {
      _from = null;
      _to = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar')),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Buscar en el diario',
                hintText: 'Ejemplo: sobras a domingo',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickFrom,
                    child: Text(_dateLabel(_from, 'Desde')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickTo,
                    child: Text(_dateLabel(_to, 'Hasta')),
                  ),
                ),
                IconButton(
                  onPressed: _clearDates,
                  icon: const Icon(Icons.close),
                  tooltip: 'Quitar fechas',
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: const Text('BUSCAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_loading) const LinearProgressIndicator(),
            if (!_loading)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('${_results.length} resultado(s)'),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final e = _results[index];
                  final date = DateFormat('EEEE, d MMMM y', 'es_ES')
                      .format(DateTime.parse(e.entryDate));
                  final preview = e.body.isNotEmpty ? e.body : e.reminder;

                  return Card(
                    child: ListTile(
                      title: Text(
                        date,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        preview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _open(e),
                    ),
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
