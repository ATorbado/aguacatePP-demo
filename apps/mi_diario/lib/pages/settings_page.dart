import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _authEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await AuthService.instance.isAuthEnabled();
    if (!mounted) return;
    setState(() {
      _authEnabled = enabled;
      _loading = false;
    });
  }

  Future<void> _setAuth(bool value) async {
    await AuthService.instance.setAuthEnabled(value);
    setState(() => _authEnabled = value);
  }

  Future<void> _rescheduleNotifications() async {
    await NotificationService.instance.scheduleDailyReminders();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recordatorios configurados')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                SwitchListTile(
                  title: const Text('Proteger con huella o PIN'),
                  subtitle: const Text('Activo por defecto'),
                  value: _authEnabled,
                  onChanged: _setAuth,
                ),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.notifications),
                  title: Text('Recordatorio 11:00'),
                  subtitle: Text('Recuerda revisar tu diario'),
                ),
                const ListTile(
                  leading: Icon(Icons.notifications),
                  title: Text('Recordatorio 20:00'),
                  subtitle: Text('¿Quieres escribir cómo ha ido tu día?'),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _rescheduleNotifications,
                  icon: const Icon(Icons.refresh),
                  label: const Text('RECONFIGURAR RECORDATORIOS'),
                ),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.backup),
                  title: Text('Copia automática'),
                  subtitle: Text('Domingo a las 21:00. Se guardan las 5 últimas.'),
                ),
              ],
            ),
    );
  }
}
