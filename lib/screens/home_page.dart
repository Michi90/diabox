import 'package:flutter/material.dart';
import 'package:diabox/database_helper.dart';
import 'package:diabox/models/consumable_type.dart';
import 'package:diabox/models/active_consumable.dart';
import 'package:diabox/screens/consumable_type_detail_screen.dart';
import 'package:diabox/utils/extensions.dart';
import 'package:diabox/utils/formatters.dart'; // Import the new formatters file
import 'package:diabox/screens/settings_page.dart'; // Import the new settings page

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late DatabaseHelper _dbHelper;
  List<Map<String, dynamic>> _displayItems = [];

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper();
    _loadData();
  }

  Future<void> _loadData() async {
    final consumableTypes = await _dbHelper.getConsumableTypes();
    final activeConsumables = await _dbHelper.getActiveConsumables();

    List<Map<String, dynamic>> items = [];

    for (var type in consumableTypes) {
      final activeInstance = activeConsumables.firstWhereOrNull(
          (active) => active.consumableTypeId == type.id);

      items.add({
        'type': type,
        'activeInstance': activeInstance,
      });
    }

    // Sort: active items first, then by name
    items.sort((a, b) {
      final bool aIsActive = a['activeInstance'] != null;
      final bool bIsActive = b['activeInstance'] != null;

      if (aIsActive && !bIsActive) return -1;
      if (!aIsActive && bIsActive) return 1;

      return (a['type'] as ConsumableType).name.compareTo((b['type'] as ConsumableType).name);
    });

    setState(() {
      _displayItems = items;
    });
  }

  String _getRemainingTime(ActiveConsumable consumable, ConsumableType type) {
    final now = DateTime.now();
    final endDate = consumable.expectedEndDate;

    if (type.isFixedLifespan) {
      if (now.isAfter(endDate)) {
        return 'Abgelaufen!';
      } else {
        final remaining = endDate.difference(now);
        return '${formatDuration(remaining)} verbleibend';
      }
    } else { // Flexible lifespan
      if (now.isAfter(endDate)) {
        final overdue = now.difference(endDate);
        return 'Überfällig seit ${formatDuration(overdue)}';
      } else {
        final remaining = endDate.difference(now);
        return '${formatDuration(remaining)} bis zum Wechsel';
      }
    }
  }

  Color _getStatusColor(ActiveConsumable consumable, ConsumableType type) {
    final now = DateTime.now();
    final endDate = consumable.expectedEndDate;

    if (type.isFixedLifespan) {
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

  Future<void> _addConsumableType() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final lifespanController = TextEditingController();
    bool isFixedLifespan = true;
    

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Verbrauchsmaterial-Typ hinzufügen'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Bitte Namen eingeben';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: lifespanController,
                      decoration: const InputDecoration(labelText: 'Standard-Laufzeit (Tage)'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Bitte Laufzeit eingeben';
                        }
                        if (int.tryParse(value) == null || int.parse(value) <= 0) {
                          return 'Bitte eine gültige Anzahl von Tagen eingeben';
                        }
                        return null;
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Feste Laufzeit'),
                      value: isFixedLifespan,
                      onChanged: (bool value) {
                        setState(() {
                          isFixedLifespan = value;
                        });
                      },
                    ),
                    
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Abbrechen'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Hinzufügen'),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final navigator = Navigator.of(context); // Store navigator before async gap
                                            final newType = ConsumableType(
                        name: nameController.text,
                        defaultLifespanDays: int.parse(lifespanController.text),
                        isFixedLifespan: isFixedLifespan,
                        managesStock: true, // Always true now
                      );
                      final newTypeId = await _dbHelper.insertConsumableType(newType);
                      if (!mounted) return;
                      await _loadData(); // Changed from _loadConsumableTypes()
                      
                      // Navigate to the detail screen of the newly created item
                      final createdConsumableType = await _dbHelper.getConsumableTypeById(newTypeId);
                      if (createdConsumableType != null) {
                        navigator.pop(); // Close the dialog first
                        navigator.push(
                          MaterialPageRoute(
                            builder: (context) => ConsumableTypeDetailScreen(consumableType: createdConsumableType),
                          ),
                        ).then((_) => _loadData()); // Reload data when returning from detail screen
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diabox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              ).then((_) => _loadData()); // Reload data when returning from settings
            },
          ),
        ],
      ),
      body: _displayItems.isEmpty
          ? const Center(
              child: Text('Noch keine Verbrauchsmaterial-Typen hinzugefügt.'),
            )
          : ListView.builder(
              itemCount: _displayItems.length,
              itemBuilder: (context, index) {
                final item = _displayItems[index];
                final type = item['type'] as ConsumableType;
                final activeInstance = item['activeInstance'] as ActiveConsumable?;

                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ConsumableTypeDetailScreen(consumableType: type),
                        ),
                      ).then((_) => _loadData());
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                type.name,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              if (activeInstance != null) // Only show start date if active
                                Row(
                                  children: [
                                    const Icon(Icons.play_arrow, size: 18), // Play icon
                                    const SizedBox(width: 4),
                                    Text(
                                      formatDateTime(activeInstance.startDate),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 8), // Spacing between rows
                          if (activeInstance != null) // Only show remaining time and end date if active
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _getRemainingTime(activeInstance, type),
                                  style: TextStyle(color: _getStatusColor(activeInstance, type)),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.stop, size: 18), // Stop icon
                                    const SizedBox(width: 4),
                                    Text(
                                      formatDateTime(activeInstance.expectedEndDate),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else // If not active, show lifespan info
                            Text(
                              type.isFixedLifespan
                                  ? 'Laufzeit: ${type.defaultLifespanDays} Tage (Fix)'
                                  : 'Laufzeit: ${type.defaultLifespanDays} Tage (Flexibel)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addConsumableType,
        child: const Icon(Icons.add),
      ),
    );
  }
}