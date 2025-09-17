import 'package:flutter/material.dart';
import 'package:diabox/database_helper.dart';
import 'package:diabox/models/active_consumable.dart';
import 'package:diabox/screens/barcode_scanner_screen.dart';
import 'package:diabox/utils/gs1_parser.dart';

class EditNoteDialog extends StatefulWidget {
  final ActiveConsumable consumable;
  final DatabaseHelper dbHelper;
  final Function onNoteUpdated; // Callback to refresh the parent screen

  const EditNoteDialog({
    required this.consumable,
    required this.dbHelper,
    required this.onNoteUpdated,
    super.key,
  });

  @override
  State<EditNoteDialog> createState() => _EditNoteDialogState();
}

class _EditNoteDialogState extends State<EditNoteDialog> {
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.consumable.notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async { // Renamed from _updateNote
    final updatedConsumable = ActiveConsumable(
      id: widget.consumable.id,
      consumableTypeId: widget.consumable.consumableTypeId,
      startDate: widget.consumable.startDate,
      expectedEndDate: widget.consumable.expectedEndDate,
      deactivationDate: widget.consumable.deactivationDate,
      isActive: widget.consumable.isActive,
      notes: _notesController.text,
    );
    await widget.dbHelper.updateActiveConsumable(updatedConsumable);
    widget.onNoteUpdated(); // Call the callback to refresh parent
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Notiz bearbeiten'),
      content: TextField(
        controller: _notesController,
        maxLines: null,
        decoration: const InputDecoration(
          hintText: 'Notiz hier eingeben...',
        ),
      ),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: () async {
            final scannedBarcode = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
            );
            if (scannedBarcode != null && scannedBarcode is String) {
              final lotNumber = Gs1Parser.extractLotNumber(scannedBarcode);
              if (lotNumber != null) {
                setState(() {
                  _notesController.text = lotNumber;
                });
              } else {
                // If no lot number found, maybe put the whole barcode or a message
                setState(() {
                  _notesController.text = scannedBarcode; // Fallback to full barcode
                });
              }
            }
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
            final navigator = Navigator.of(context); // Capture navigator before async gap
            await _saveNote(); // Changed from _updateNote
            if (mounted) { // Fix for use_build_context_synchronously
              navigator.pop();
            }
          },
        ),
      ],
    );
  }
}
