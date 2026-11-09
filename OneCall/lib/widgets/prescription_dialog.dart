import 'package:callone/app_styles/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrescriptionDialog extends ConsumerStatefulWidget {
  final String? initialPrescription;
  final bool isReadOnly;
  final Function(String) onSave;

  const PrescriptionDialog({
    super.key,
    this.initialPrescription,
    required this.isReadOnly,
    required this.onSave,
  });

  @override
  ConsumerState<PrescriptionDialog> createState() => _PrescriptionDialogState();
}

class _PrescriptionDialogState extends ConsumerState<PrescriptionDialog> {
  late TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPrescription);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isSaving = true);
    
    // Simulate a bit of delay or just call the function
    try {
       await widget.onSave(_controller.text.trim());
       if (mounted) Navigator.of(context).pop(); 
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving: $e")));
      }
    } finally {
       if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = ref.watch(appColorsProvider);
    final isViewMode = widget.isReadOnly;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(
                   isViewMode ? "Prescription" : "Write Prescription",
                   style: TextStyle(
                     fontSize: 20,
                     fontWeight: FontWeight.bold,
                     color: appColors.primary,
                   ),
                 ),
                 IconButton(
                   icon: const Icon(Icons.close),
                   onPressed: () => Navigator.of(context).pop(),
                 )
               ],
             ),
             const SizedBox(height: 16),
             Expanded(
               child: isViewMode
                   ? SingleChildScrollView(
                       child: Container(
                         width: double.infinity,
                         padding: const EdgeInsets.all(16),
                         decoration: BoxDecoration(
                           color: Colors.grey[100],
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(color: Colors.grey[300]!),
                         ),
                         child: Text(
                           widget.initialPrescription != null && widget.initialPrescription!.isNotEmpty
                               ? widget.initialPrescription!
                               : "No prescription available yet.",
                           style: const TextStyle(fontSize: 16, height: 1.5),
                         ),
                       ),
                     )
                   : TextField(
                       controller: _controller,
                       maxLines: null,
                       expands: true,
                       decoration: InputDecoration(
                         hintText: "Enter prescription details here...",
                         border: OutlineInputBorder(
                           borderRadius: BorderRadius.circular(8),
                         ),
                         alignLabelWithHint: true,
                       ),
                     ),
             ),
             if (!isViewMode) ...[
               const SizedBox(height: 16),
               SizedBox(
                 width: double.infinity,
                 child: ElevatedButton(
                   onPressed: _isSaving ? null : _handleSave,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: appColors.primary,
                     foregroundColor: Colors.white,
                     padding: const EdgeInsets.symmetric(vertical: 16),
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(8),
                     ),
                   ),
                   child: _isSaving
                       ? const SizedBox(
                           height: 20,
                           width: 20,
                           child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                         )
                       : const Text("Save Prescription"),
                 ),
               ),
             ]
          ],
        ),
      ),
    );
  }
}
