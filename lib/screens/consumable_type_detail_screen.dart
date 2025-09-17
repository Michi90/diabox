// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:diabox/database_helper.dart';
import 'package:diabox/models/consumable_type.dart';
import 'package:diabox/models/stock_item.dart';
import 'package:diabox/models/active_consumable.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter/cupertino.dart'; // Import for CupertinoPicker
import 'package:diabox/utils/formatters.dart'; // Import for formatOffsetDuration

class ConsumableTypeDetailScreen extends StatefulWidget {
  final ConsumableType consumableType;

  const ConsumableTypeDetailScreen({required this.consumableType, super.key});

  @override
  State<ConsumableTypeDetailScreen> createState() =>
      _ConsumableTypeDetailScreenState();
}

class _ConsumableTypeDetailScreenState
    extends State<ConsumableTypeDetailScreen> {
  late DatabaseHelper _dbHelper;
  late ConsumableType _currentConsumableType; // New mutable field
  int _currentStock = 0;
  List<ActiveConsumable> _usedConsumablesOfType = [];
  final TextEditingController _stockQuantityController =
      TextEditingController();
  final TextEditingController _notificationOffsetController =
      TextEditingController();
  List<int> _notificationOffsets = [];
  bool _managesStockGlobally = true; // New field for global setting
  bool _notificationsEnabledGlobally =
      true; // New field for global notification setting
  bool _showFullHistory = false; // New field for history display
  ActiveConsumable? _activeConsumable; // New field to store the active consumable

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper();
    _currentConsumableType = widget.consumableType; // Initialize from widget
    _notificationOffsets = List<int>.from(
      _currentConsumableType.notificationOffsetsInMinutes ?? [],
    ); // Use _currentConsumableType
    _loadData();
  }

  @override
  void dispose() {
    _stockQuantityController.dispose();
    _notificationOffsetController.dispose();
    super.dispose();
  }

  Future<void> _updateNotificationOffsetsInDb() async {
    _currentConsumableType = ConsumableType(
      // Update _currentConsumableType
      id: _currentConsumableType.id,
      name: _currentConsumableType.name,
      defaultLifespanDays: _currentConsumableType.defaultLifespanDays,
      isFixedLifespan: _currentConsumableType.isFixedLifespan,
      managesStock: _currentConsumableType.managesStock,
      notificationOffsetsInMinutes: _notificationOffsets.isEmpty
          ? null
          : _notificationOffsets,
    );
    await _dbHelper.updateConsumableType(
      _currentConsumableType,
    ); // Pass _currentConsumableType

    // After updating the ConsumableType, reschedule notifications for active consumables of this type
    if (_notificationsEnabledGlobally) {
      // Added _notificationsEnabledGlobally check
      final activeConsumablesOfType = await _dbHelper
          .getActiveConsumablesForType(_currentConsumableType.id!);

      for (var activeConsumable in activeConsumablesOfType) {
        // Cancel existing notifications for this active consumable
        // This will cancel the expiration notification and any reminder notifications that have the exact same unique name.
        // For reminders, the unique name includes the offset, so if an offset is removed, its old task will not be cancelled here.
        Workmanager().cancelByUniqueName(
          'expiration_notification_${activeConsumable.id}',
        );

        // Re-schedule expiration notification
        final expectedEndDate = activeConsumable.expectedEndDate;
        Workmanager().registerOneOffTask(
          'expiration_notification_${activeConsumable.id}',
          'consumableNotification',
          initialDelay: expectedEndDate.difference(DateTime.now()),
          inputData: <String, dynamic>{
            'consumableTypeId': _currentConsumableType.id,
            'activeConsumableId': activeConsumable.id,
            'notificationType': 'expiration',
          },
        );

        // Re-schedule reminder notifications based on new offsets
        if (_currentConsumableType.notificationOffsetsInMinutes != null) {
          for (int offset
              in _currentConsumableType.notificationOffsetsInMinutes!) {
            final scheduledTime = expectedEndDate.subtract(
              Duration(minutes: offset),
            );
            if (scheduledTime.isAfter(DateTime.now())) {
              Workmanager().registerOneOffTask(
                'reminder_notification_${activeConsumable.id}_$offset',
                'consumableNotification',
                initialDelay: scheduledTime.difference(DateTime.now()),
                inputData: <String, dynamic>{
                  'consumableTypeId': _currentConsumableType.id,
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

  Future<void> _loadData() async {
    final fetchedConsumableType = await _dbHelper.getConsumableTypeById(
      _currentConsumableType.id!,
    ); // Fetch latest
    if (fetchedConsumableType != null) {
      _currentConsumableType = fetchedConsumableType; // Update mutable field
      _notificationOffsets = List<int>.from(
        _currentConsumableType.notificationOffsetsInMinutes ?? [],
      ); // Refresh offsets
    }

    final managesStockSetting = await _dbHelper.getSetting(
      'manages_stock_globally',
    );
    final notificationsEnabledSetting = await _dbHelper.getSetting(
      'notifications_enabled_globally',
    );
    setState(() {
      _managesStockGlobally = managesStockSetting == 'true';
      _notificationsEnabledGlobally = notificationsEnabledSetting == 'true';
    });

    final stock = await _dbHelper.getTotalStockForConsumableType(
      _currentConsumableType.id!,
    );
    final active = await _dbHelper.getActiveConsumablesForType(
      _currentConsumableType.id!,
    );
    final used = await _dbHelper.getUsedConsumablesForType(
      _currentConsumableType.id!,
    ); // Get used consumables
    setState(() {
      _currentStock = stock;
      _activeConsumable = active.isNotEmpty ? active.first : null; // Store the active consumable
      _usedConsumablesOfType = used;
    });
  }

  Future<void> _activateNewConsumable() async {
    final existingActiveConsumables = await _dbHelper
        .getActiveConsumablesForType(_currentConsumableType.id!);

    String dialogContent =
        'Möchtest du einen neuen ${_currentConsumableType.name} aktivieren?';
    if (existingActiveConsumables.isNotEmpty) {
      dialogContent =
          'Es ist bereits ein ${_currentConsumableType.name} aktiv. Möchtest du diesen deaktivieren und einen neuen aktivieren?';
    } else if (_managesStockGlobally &&
        _currentConsumableType.managesStock &&
        _currentStock <= 0) {
      // Added _managesStockGlobally check
      dialogContent =
          'Es ist kein Lagerbestand für ${_currentConsumableType.name} vorhanden. Möchtest du trotzdem einen Artikel aktivieren?';
    }

    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Artikel aktivieren'),
              content: Text(dialogContent), // Use the dynamic content
              actions: <Widget>[
                TextButton(
                  child: const Text('Abbrechen'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                ElevatedButton(
                  child: const Text('Aktivieren'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirm) {
      return; // User cancelled the initial confirmation
    }

    // If user confirmed, and there were existing active consumables, deactivate them.
    if (existingActiveConsumables.isNotEmpty) {
      for (var active in existingActiveConsumables) {
        await _dbHelper.deactivateActiveConsumable(active.id!);
      }
    }

    bool stockWasDecremented = false;
    if (_managesStockGlobally &&
        _currentConsumableType.managesStock &&
        _currentStock > 0) {
      // Added _managesStockGlobally check
      stockWasDecremented = await _dbHelper.decrementStockItemQuantity(
        _currentConsumableType.id!,
      );
      if (!stockWasDecremented) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fehler beim Reduzieren des Lagerbestands.'),
          ),
        );
        return; // Stop if decrement failed unexpectedly
      }
    }

    // Create new active consumable
    final startDate = DateTime.now();
    final expectedEndDate = startDate.add(
      Duration(days: _currentConsumableType.defaultLifespanDays),
    );

    final newActiveConsumable = ActiveConsumable(
      consumableTypeId: _currentConsumableType.id!,
      startDate: startDate,
      expectedEndDate: expectedEndDate,
    );
    final newActiveConsumableId = await _dbHelper.insertActiveConsumable(
      newActiveConsumable,
    );

    // Schedule notifications
    if (_notificationsEnabledGlobally && newActiveConsumableId > 0) {
      // Added _notificationsEnabledGlobally check
      // Schedule expiration notification
      Workmanager().cancelByUniqueName(
        'expiration_notification_$newActiveConsumableId',
      );
      Workmanager().registerOneOffTask(
        'expiration_notification_$newActiveConsumableId',
        'consumableNotification',
        initialDelay: expectedEndDate.difference(DateTime.now()),
        inputData: <String, dynamic>{
          'consumableTypeId': _currentConsumableType.id,
          'activeConsumableId': newActiveConsumableId,
          'notificationType': 'expiration',
        },
      );

      // Schedule reminder notifications based on offsets
      if (_currentConsumableType.notificationOffsetsInMinutes != null) {
        for (int offset
            in _currentConsumableType.notificationOffsetsInMinutes!) {
          final scheduledTime = expectedEndDate.subtract(
            Duration(minutes: offset),
          );
          if (scheduledTime.isAfter(DateTime.now())) {
            Workmanager().cancelByUniqueName(
              'reminder_notification_${newActiveConsumableId}_$offset',
            );
            Workmanager().registerOneOffTask(
              'reminder_notification_${newActiveConsumableId}_$offset',
              'consumableNotification',
              initialDelay: scheduledTime.difference(DateTime.now()),
              inputData: <String, dynamic>{
                'consumableTypeId': _currentConsumableType.id,
                'activeConsumableId': newActiveConsumableId,
                'notificationType': 'reminder',
                'offset': offset,
              },
            );
          }
        }
      }
    }

    _loadData(); // Reload data
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_currentConsumableType.name} erfolgreich aktiviert!'),
      ),
    );
  }

  Future<void> _addStock(int quantity) async {
    if (quantity <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte eine gültige positive Zahl eingeben.'),
        ),
      );
      return;
    }

    final newStockItem = StockItem(
      consumableTypeId: _currentConsumableType.id!,
      quantity: quantity,
      addedDate: DateTime.now(),
    );
    await _dbHelper.insertStockItem(newStockItem);
    _loadData(); // Reload data
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$quantity ${_currentConsumableType.name} zum Lagerbestand hinzugefügt!',
        ),
      ),
    );
  }

  void _deactivateConsumable(int id) async {
    final activeConsumable = await _dbHelper.getActiveConsumableById(id);
    if (activeConsumable != null) {
      final consumableType = await _dbHelper.getConsumableTypeById(
        activeConsumable.consumableTypeId,
      );
      if (consumableType != null && _notificationsEnabledGlobally) {
        // Added _notificationsEnabledGlobally check
        // Cancel expiration notification
        Workmanager().cancelByUniqueName(
          'expiration_notification_${activeConsumable.id}',
        );

        // Cancel reminder notifications
        if (consumableType.notificationOffsetsInMinutes != null) {
          for (int offset in consumableType.notificationOffsetsInMinutes!) {
            Workmanager().cancelByUniqueName(
              'reminder_notification_${activeConsumable.id}_$offset',
            );
          }
        }
      }
    }
    await _dbHelper.deactivateActiveConsumable(id);
    if (!mounted) return;
    _loadData();
  }

  // Helper to convert total minutes to (days, hours, minutes)
  Map<String, int> _minutesToDaysHoursMinutes(int totalMinutes) {
    int days = totalMinutes ~/ (24 * 60);
    int remainingMinutes = totalMinutes % (24 * 60);
    int hours = remainingMinutes ~/ 60;
    int minutes = remainingMinutes % 60;
    return {'days': days, 'hours': hours, 'minutes': minutes};
  }

  // Helper to convert (days, hours, minutes) to total minutes
  int _daysHoursMinutesToMinutes(int days, int hours, int minutes) {
    return (days * 24 * 60) + (hours * 60) + minutes;
  }

  Future<void> _addNotificationOffset() async {
    final int? newOffset = await _showNotificationOffsetSelector(context);
    if (newOffset != null && newOffset > 0) {
      setState(() {
        _notificationOffsets.add(newOffset);
      });
      await _updateNotificationOffsetsInDb();
    }
  }

  Future<int?> _showNotificationOffsetSelector(
    BuildContext context, {
    int? initialOffset,
  }) async {
    int currentDays = 0;
    int currentHours = 0;
    int currentMinutes = 0;

    if (initialOffset != null) {
      final dhm = _minutesToDaysHoursMinutes(initialOffset);
      currentDays = dhm['days']!;
      currentHours = dhm['hours']!;
      currentMinutes = dhm['minutes']!;
    }

    int selectedDays = currentDays;
    int selectedHours = currentHours;
    int selectedMinutes = currentMinutes;

    final result = await showCupertinoModalPopup<int>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Days picker
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: selectedDays,
                        ),
                        itemExtent: 32.0,
                        onSelectedItemChanged: (int index) {
                          selectedDays = index;
                        },
                        children: List<Widget>.generate(366, (int index) {
                          // Up to 365 days
                          return Center(child: Text('$index Tage'));
                        }),
                      ),
                    ),
                    // Hours picker
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: selectedHours,
                        ),
                        itemExtent: 32.0,
                        onSelectedItemChanged: (int index) {
                          selectedHours = index;
                        },
                        children: List<Widget>.generate(24, (int index) {
                          return Center(child: Text('$index Stunden'));
                        }),
                      ),
                    ),
                    // Minutes picker
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: selectedMinutes,
                        ),
                        itemExtent: 32.0,
                        onSelectedItemChanged: (int index) {
                          selectedMinutes = index;
                        },
                        children: List<Widget>.generate(60, (int index) {
                          return Center(child: Text('$index Minuten'));
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CupertinoButton(
                    child: const Text('Abbrechen'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  CupertinoButton(
                    child: const Text('Bestätigen'),
                    onPressed: () {
                      Navigator.of(context).pop(
                        _daysHoursMinutesToMinutes(
                          selectedDays,
                          selectedHours,
                          selectedMinutes,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    return result;
  }

  Future<int?> _showQuantitySelector(
    BuildContext context, {
    int initialQuantity = 1,
  }) async {
    int selectedQuantity = initialQuantity;

    final result = await showCupertinoModalPopup<int>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: selectedQuantity - 1,
                  ), // Assuming quantities start from 1
                  itemExtent: 32.0,
                  onSelectedItemChanged: (int index) {
                    selectedQuantity = index + 1; // Adjust for 0-based index
                  },
                  children: List<Widget>.generate(100, (int index) {
                    // Quantities from 1 to 100
                    return Center(child: Text('${index + 1}'));
                  }),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CupertinoButton(
                    child: const Text('Abbrechen'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  CupertinoButton(
                    child: const Text('Bestätigen'),
                    onPressed: () {
                      Navigator.of(context).pop(selectedQuantity);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    return result;
  }

  Future<void> _addStockFromSelector() async {
    final int? quantity = await _showQuantitySelector(context);
    if (quantity != null && quantity > 0) {
      await _addStock(quantity);
    }
  }

  Future<void> _removeStockFromSelector() async {
    final int? quantity = await _showQuantitySelector(context);
    if (quantity != null && quantity > 0) {
      await _removeStock(quantity);
    }
  }

  Future<void> _removeStock(int quantity) async {
    if (quantity <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte eine gültige positive Zahl eingeben.'),
        ),
      );
      return;
    }

    if (quantity > _currentStock) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Es kann nicht mehr als der vorhandene Bestand ($_currentStock) entfernt werden.',
          ),
        ),
      );
      return;
    }

    await _dbHelper.removeStockForConsumableType(
      _currentConsumableType.id!,
      quantity,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$quantity ${_currentConsumableType.name} aus dem Lager entfernt!',
        ),
      ),
    );
    _loadData(); // Reload data to reflect changes
  }

  String _getRemainingTimeDisplay() {
    if (_activeConsumable == null) return '';

    final now = DateTime.now();
    final endDate = _activeConsumable!.expectedEndDate;

    if (_currentConsumableType.isFixedLifespan) {
      if (now.isAfter(endDate)) {
        return 'Abgelaufen!';
      } else {
        final remaining = endDate.difference(now);
        return '${formatDuration(remaining)} verbleibend';
      }
    } else {
      // Flexible lifespan
      if (now.isAfter(endDate)) {
        final overdue = now.difference(endDate);
        return 'Überfällig seit ${formatDuration(overdue)}';
      } else {
        final remaining = endDate.difference(now);
        return '${formatDuration(remaining)} bis zum Wechsel';
      }
    }
  }

  Color _getRemainingTimeColor() {
    if (_activeConsumable == null) return Colors.transparent;

    final now = DateTime.now();
    final endDate = _activeConsumable!.expectedEndDate;

    if (_currentConsumableType.isFixedLifespan) {
      if (now.isAfter(endDate)) {
        return Colors.red;
      } else if (endDate.difference(now).inDays <= 2) {
        return Colors.orange;
      } else {
        return Colors.green;
      }
    } else {
      // Flexible lifespan
      if (now.isAfter(endDate)) {
        return Colors.red;
      } else if (endDate.difference(now).inDays <= 1) {
        return Colors.orange;
      } else {
        return Colors.green;
      }
    }
  }

  Future<DateTime?> _showDateTimePicker(BuildContext context, DateTime initialDateTime) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate == null) return null;


    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
    );

    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _editStartDate(ActiveConsumable activeConsumable) async {
    final newStartDate = await _showDateTimePicker(context, activeConsumable.startDate);

    if (newStartDate != null) {
      // Calculate new expectedEndDate based on the newStartDate and defaultLifespanDays
      final newExpectedEndDate = newStartDate.add(
        Duration(days: _currentConsumableType.defaultLifespanDays),
      );

      final updatedActiveConsumable = ActiveConsumable(
        id: activeConsumable.id,
        consumableTypeId: activeConsumable.consumableTypeId,
        startDate: newStartDate,
        expectedEndDate: newExpectedEndDate,
        deactivationDate: activeConsumable.deactivationDate,
        isActive: activeConsumable.isActive,
      );

      await _dbHelper.updateActiveConsumable(updatedActiveConsumable);

      // Reschedule notifications for the updated active consumable
      if (_notificationsEnabledGlobally) {
        // Cancel existing notifications for this active consumable
        Workmanager().cancelByUniqueName(
          'expiration_notification_${activeConsumable.id}',
        );
        if (_currentConsumableType.notificationOffsetsInMinutes != null) {
          for (int offset in _currentConsumableType.notificationOffsetsInMinutes!) {
            Workmanager().cancelByUniqueName(
              'reminder_notification_${activeConsumable.id}_$offset',
            );
          }
        }

        // Schedule new expiration notification
        Workmanager().registerOneOffTask(
          'expiration_notification_${activeConsumable.id}',
          'consumableNotification',
          initialDelay: newExpectedEndDate.difference(DateTime.now()),
          inputData: <String, dynamic>{
            'consumableTypeId': _currentConsumableType.id,
            'activeConsumableId': activeConsumable.id,
            'notificationType': 'expiration',
          },
        );

        // Schedule new reminder notifications based on offsets
        if (_currentConsumableType.notificationOffsetsInMinutes != null) {
          for (int offset in _currentConsumableType.notificationOffsetsInMinutes!) {
            final scheduledTime = newExpectedEndDate.subtract(
              Duration(minutes: offset),
            );
            if (scheduledTime.isAfter(DateTime.now())) {
              Workmanager().registerOneOffTask(
                'reminder_notification_${activeConsumable.id}_$offset',
                'consumableNotification',
                initialDelay: scheduledTime.difference(DateTime.now()),
                inputData: <String, dynamic>{
                  'consumableTypeId': _currentConsumableType.id,
                  'activeConsumableId': activeConsumable.id,
                  'notificationType': 'reminder',
                  'offset': offset,
                },
              );
            }
          }
        }
      }

      _loadData(); // Reload data to reflect changes
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Startzeitpunkt erfolgreich aktualisiert!'),
        ),
      );
    }
  }

  Future<void> _confirmDeactivation(int consumableId) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Artikel beenden'),
              content: const Text('Möchtest du diesen Artikel wirklich beenden?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Abbrechen'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                ElevatedButton(
                  child: const Text('Beenden'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        ) ?? false;

    if (confirm) {
      _deactivateConsumable(consumableId);
    }
  }

  Future<void> _showEditConsumableTypeDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController(text: _currentConsumableType.name);
    final TextEditingController lifespanController = TextEditingController(text: _currentConsumableType.defaultLifespanDays.toString());
    bool isFixedLifespan = _currentConsumableType.isFixedLifespan;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Artikel bearbeiten'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: lifespanController,
                      decoration: const InputDecoration(labelText: 'Laufzeit (Tage)'),
                      keyboardType: TextInputType.number,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Feste Laufzeit'),
                        Switch(
                          value: isFixedLifespan,
                          onChanged: (bool value) {
                            setState(() {
                              isFixedLifespan = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Löschen'),
                  onPressed: () async {
                    Navigator.of(context).pop(); // Close edit dialog
                    await _confirmDeleteConsumableType(context, _currentConsumableType.id!); // Show confirmation dialog
                  },
                ),
                TextButton(
                  child: const Text('Abbrechen'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Speichern'),
                  onPressed: () async {
                    final String newName = nameController.text.trim();
                    final int? newLifespan = int.tryParse(lifespanController.text.trim());

                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Name darf nicht leer sein.')),
                      );
                      return;
                    }
                    if (newLifespan == null || newLifespan <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Laufzeit muss eine positive Zahl sein.')),
                      );
                      return;
                    }

                    final updatedConsumableType = ConsumableType(
                      id: _currentConsumableType.id,
                      name: newName,
                      defaultLifespanDays: newLifespan,
                      isFixedLifespan: isFixedLifespan,
                      managesStock: _currentConsumableType.managesStock,
                      notificationOffsetsInMinutes: _currentConsumableType.notificationOffsetsInMinutes,
                    );

                    await _dbHelper.updateConsumableType(updatedConsumableType);
                    await _loadData(); // Refresh the screen
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteConsumableType(BuildContext context, int id) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Artikel löschen'),
          content: const Text('Möchtest du diesen Artikel wirklich löschen? Alle zugehörigen Daten (Lagerbestand, Aktivierungen) werden ebenfalls gelöscht.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              child: const Text('Löschen'),
              onPressed: () async {
                await _dbHelper.deleteConsumableType(id);
                if (!mounted) return;
                // Pop all screens until the home page
                Navigator.of(context).popUntil((route) => route.isFirst);
                // Reload data on home page (assuming home page reloads on resume or has a listener)
                // For now, we rely on the home page's _loadData() being called when it becomes active again.
              },
            ),
          ],
        );
      },
    ) ?? false;

    if (confirm) {
      // Deletion logic is handled within the dialog's onPressed for ElevatedButton
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentConsumableType.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditConsumableTypeDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize:
              MainAxisSize.min, // Added to prevent unbounded height issues
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display remaining time for active consumable
            if (_activeConsumable != null)
              Column(
                children: [
                  // Verbleibende Zeit (bleibt wie sie ist)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Center(
                      child: Text(
                        _getRemainingTimeDisplay(),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: _getRemainingTimeColor(),
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                  // Startzeit und Endzeit in einer Reihe
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Startzeit mit Edit-Icon
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Start: ${formatDateTime(_activeConsumable!.startDate)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _editStartDate(_activeConsumable!),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        // Endzeit
                        Text(
                          'Ende: ${formatDateTime(_activeConsumable!.expectedEndDate)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            // Action Buttons Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _activateNewConsumable,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                      backgroundColor: Colors.green.shade200, // Grün für Start
                      foregroundColor: Colors.black, // Schwarze Schrift für Start
                    ),
                    child: const Text('Start'),
                  ),
                ),
                if (_activeConsumable != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmDeactivation(_activeConsumable!.id!),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: const TextStyle(fontSize: 18),
                        backgroundColor: Colors.red.shade200, // Pastellrot für Stopp
                        foregroundColor: Colors.black, // Schwarze Schrift für Stopp
                      ),
                      child: const Text('Stopp'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Stock Management Section
            if (_managesStockGlobally) // Conditional rendering
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment
                        .center, // Align items vertically in the middle
                    children: [
                      Text(
                        'Lager',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          // Wrap buttons in a Row
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: _removeStockFromSelector,
                            ),
                            const SizedBox(width: 8), // Spacing between buttons
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _addStockFromSelector,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Bestand: $_currentStock',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            if (_managesStockGlobally) // Only show divider if section is visible
              const SizedBox(height: 24),
            if (_managesStockGlobally) // Only show divider if section is visible
              const Divider(),
            if (_managesStockGlobally) // Only show divider if section is visible
              const SizedBox(height: 24),

            // Notification Settings Section (Inline)
            if (_notificationsEnabledGlobally) // Conditional rendering
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Benachrichtigungen',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _addNotificationOffset,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Aktiv: ${_notificationOffsets.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _notificationOffsets.length,
                    itemBuilder: (context, index) {
                      final offset = _notificationOffsets[index];
                      return ListTile(
                        title: Text(formatOffsetDuration(offset)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.settings),
                              onPressed: () async {
                                final int? editedOffset =
                                    await _showNotificationOffsetSelector(
                                      context,
                                      initialOffset: offset,
                                    );
                                if (editedOffset != null && editedOffset > 0) {
                                  setState(() {
                                    _notificationOffsets[index] = editedOffset;
                                  });
                                  await _updateNotificationOffsetsInDb();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                setState(() {
                                  _notificationOffsets.removeAt(index);
                                });
                                await _updateNotificationOffsetsInDb();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            if (_notificationsEnabledGlobally)
              const SizedBox(height: 24),
            if (_notificationsEnabledGlobally)
              const Divider(),
            if (_notificationsEnabledGlobally)
              const SizedBox(height: 24),

            // Activation History Section
            const Text(
              'Verlauf',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            _usedConsumablesOfType.isEmpty
                ? const Center(
                    child: Text('Noch keine Aktivierungen vorhanden.'),
                  )
                : Column(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _showFullHistory
                            ? _usedConsumablesOfType.length
                            : (_usedConsumablesOfType.length > 5
                                ? 5
                                : _usedConsumablesOfType.length),
                        itemBuilder: (context, index) {
                          final consumable = _usedConsumablesOfType[index];
                          // Berechne das tatsächliche Enddatum
                          final DateTime endDateToDisplay =
                              consumable.deactivationDate ?? DateTime.now();
                          final Duration durationToDisplay = endDateToDisplay
                              .difference(consumable.startDate);

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            child: ListTile(
                              title: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.play_arrow, size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      formatDateTime(consumable.startDate),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.stop, size: 20),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          formatDateTime(endDateToDisplay),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ),                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Dauer: ${formatDuration(durationToDisplay)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              trailing: consumable.isActive == 1
                                  ? IconButton(
                                      icon: const Icon(Icons.check_circle_outline),
                                      onPressed: () =>
                                          _deactivateConsumable(consumable.id!),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                      if (!_showFullHistory && _usedConsumablesOfType.length > 5)
                        Center(
                          child: IconButton(
                            icon: const Icon(Icons.expand_more),
                            onPressed: () {
                              setState(() {
                                _showFullHistory = true;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
