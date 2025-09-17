import 'package:flutter/material.dart';
import 'package:diabox/database_helper.dart'; // Import DatabaseHelper
import 'package:workmanager/workmanager.dart'; // Import Workmanager
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'dart:io'; // For File operations
import 'dart:convert'; // For JSON encoding/decoding

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _managesStockGlobally = true; // Default value
  bool _notificationsEnabledGlobally = true; // New: Default value for notifications
  late DatabaseHelper _dbHelper;

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final managesStock = await _dbHelper.getSetting('manages_stock_globally');
    final notificationsEnabled = await _dbHelper.getSetting('notifications_enabled_globally'); // New: Load notifications setting
    setState(() {
      _managesStockGlobally = managesStock == 'true';
      _notificationsEnabledGlobally = notificationsEnabled == 'true'; // New: Update state
    });
  }

  Future<void> _updateManagesStockGlobally(bool newValue) async {
    setState(() {
      _managesStockGlobally = newValue;
    });
    await _dbHelper.updateSetting('manages_stock_globally', newValue.toString());
  }

  Future<void> _updateNotificationsEnabledGlobally(bool newValue) async {
    setState(() {
      _notificationsEnabledGlobally = newValue;
    });
    await _dbHelper.updateSetting('notifications_enabled_globally', newValue.toString());

    if (!newValue) {
      // If notifications are disabled, cancel all scheduled tasks
      await Workmanager().cancelAll();
    } else {
      // If notifications are enabled, reschedule for all active consumables
      final consumableTypes = await _dbHelper.getConsumableTypes();
      for (var type in consumableTypes) {
        final activeConsumablesOfType = await _dbHelper.getActiveConsumablesForType(type.id!); 
        for (var activeConsumable in activeConsumablesOfType) {
          // Reschedule expiration notification
          final expectedEndDate = activeConsumable.expectedEndDate;
          Workmanager().registerOneOffTask(
            'expiration_notification_${activeConsumable.id}',
            'consumableNotification',
            initialDelay: expectedEndDate.difference(DateTime.now()),
            inputData: <String, dynamic>{
              'consumableTypeId': type.id,
              'activeConsumableId': activeConsumable.id,
              'notificationType': 'expiration',
            },
          );

          // Reschedule reminder notifications based on offsets
          if (type.notificationOffsetsInMinutes != null) {
            for (int offset in type.notificationOffsetsInMinutes!) {
              final scheduledTime = expectedEndDate.subtract(Duration(minutes: offset));
              if (scheduledTime.isAfter(DateTime.now())) {
                Workmanager().registerOneOffTask(
                  'reminder_notification_${activeConsumable.id}_$offset',
                  'consumableNotification',
                  initialDelay: scheduledTime.difference(DateTime.now()),
                  inputData: <String, dynamic>{
                    'consumableTypeId': type.id,
                    'activeConsumableId': activeConsumable.id,
                    'notificationType': 'reminder',
                    'offset': offset,
                  },
                );
              }
            }
          }
        }
      }
    }
  }

  Future<void> _exportData() async {
    try {
      final data = await _dbHelper.getAllDataAsMap();
      final jsonString = jsonEncode(data);

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Daten exportieren',
        fileName: 'diabox_data_${DateTime.now().toIso8601String().substring(0, 10)}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: utf8.encode(jsonString), // Pass bytes directly
      );

      if (!mounted) return;
      if (outputFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Daten erfolgreich exportiert nach $outputFile')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export abgebrochen.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Exportieren der Daten: $e')),
      );
    }
  }

  Future<void> _importData() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Daten importieren'),
          content: const Text(
              'Möchtest du wirklich Daten importieren? Dies wird alle vorhandenen Daten überschreiben.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              child: const Text('Importieren'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirm) {
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(jsonString);

        await _dbHelper.clearAllData();
        await _dbHelper.insertAllDataFromMap(data);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daten erfolgreich importiert!')),
        );
        // Optionally, navigate to home or reload data globally
        Navigator.of(context).popUntil((route) => route.isFirst); // Go back to home
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Importieren der Daten: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: ListView( // Changed to ListView for settings options
        children: [
          SwitchListTile(
            title: const Text('Lagerverwaltung aktivieren'),
            subtitle: const Text('Globale Einstellung zur Aktivierung der Lagerverwaltung.'),
            value: _managesStockGlobally,
            onChanged: _updateManagesStockGlobally,
          ),
          SwitchListTile(
            title: const Text('Benachrichtigungen aktivieren'),
            subtitle: const Text('Globale Einstellung zur Aktivierung von Benachrichtigungen.'),
            value: _notificationsEnabledGlobally,
            onChanged: _updateNotificationsEnabledGlobally,
          ),
          const Divider(),
          ListTile(
            title: const Text('Daten exportieren'),
            subtitle: const Text('Exportiert alle App-Daten in eine JSON-Datei.'),
            onTap: _exportData,
          ),
          ListTile(
            title: const Text('Daten importieren'),
            subtitle: const Text('Importiert Daten aus einer JSON-Datei (überschreibt bestehende Daten).'),
            onTap: _importData,
          ),
        ],
      ),
    );
  }
}