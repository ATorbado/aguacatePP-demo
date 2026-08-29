import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'backup_service.dart';
import 'database_service.dart';

const weeklyBackupTask = 'weekly_backup_task';

@pragma('vm:entry-point')
void weeklyBackupCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task == weeklyBackupTask) {
      await DatabaseService.instance.init();
      await BackupService.instance.createBackup(automatic: true);
    }
    return true;
  });
}

class WeeklyBackupWorker {
  static Future<void> scheduleWeeklyBackup() async {
    await Workmanager().registerPeriodicTask(
      'mi_diario_weekly_backup',
      weeklyBackupTask,
      frequency: const Duration(days: 7),
      initialDelay: _delayUntilNextSundayAt21(),
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Duration _delayUntilNextSundayAt21() {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, 21);
    while (target.weekday != DateTime.sunday || !target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target.difference(now);
  }
}
