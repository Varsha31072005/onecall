import 'package:callone/app_styles/app_colors.dart';
import 'package:callone/providers/appointment_provider.dart';
import 'package:callone/providers/concern_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/concern.dart';
import 'concern_card.dart';

class SelectConcernSection extends ConsumerStatefulWidget {
  const SelectConcernSection({super.key});

  @override
  ConsumerState<SelectConcernSection> createState() => _SelectConcernSectionState();
}

class _SelectConcernSectionState extends ConsumerState<SelectConcernSection> {
  final TextEditingController _customConcernController = TextEditingController();
  bool _isCustomSelected = false;

  @override
  void dispose() {
    _customConcernController.dispose();
    super.dispose();
  }

  void _selectPredefinedConcern(String concernId) {
    setState(() {
      _isCustomSelected = false;
    });
    ref.read(concernProvider.notifier).selectConcern(concernId);
    ref.read(appointmentProvider.notifier).updateAppointment(
      concernId: concernId,
      patientQuery: concernId,
    );
  }

  void _applyCustomConcern() {
    final text = _customConcernController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please type your medical concern first"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _isCustomSelected = true;
    });
    ref.read(concernProvider.notifier).selectConcern(text);
    ref.read(appointmentProvider.notifier).updateAppointment(
      concernId: text,
      patientQuery: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedConcernId = ref.watch(concernProvider);
    final appColors = ref.watch(appColorsProvider);

    // Find display name for selected concern
    String selectedDisplay = '';
    if (_isCustomSelected && _customConcernController.text.trim().isNotEmpty) {
      selectedDisplay = _customConcernController.text.trim();
    } else if (selectedConcernId != null) {
      final match = concerns.where((c) => c.id == selectedConcernId);
      selectedDisplay = match.isNotEmpty ? match.first.title : selectedConcernId;
    }

    return CustomScrollView(
      slivers: [
        // Custom Concern Input Section
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appColors.background2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isCustomSelected
                    ? appColors.primary
                    : Colors.grey.withOpacity(0.2),
                width: _isCustomSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: appColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      "Type Custom Medical Concern",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: appColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Can't find your concern in the list below? Type it directly here:",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customConcernController,
                        onChanged: (val) {
                          if (val.trim().isNotEmpty) {
                            setState(() {
                              _isCustomSelected = true;
                            });
                            ref.read(concernProvider.notifier).selectConcern(val.trim());
                            ref.read(appointmentProvider.notifier).updateAppointment(
                              concernId: val.trim(),
                              patientQuery: val.trim(),
                            );
                          }
                        },
                        decoration: InputDecoration(
                          hintText: "e.g. Chest pain, Acidity, Skin rash, Ear infection...",
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: appColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _isCustomSelected ? appColors.primary : Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: appColors.primary, width: 2),
                          ),
                          suffixIcon: _customConcernController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _customConcernController.clear();
                                    setState(() {
                                      _isCustomSelected = false;
                                    });
                                  },
                                )
                              : null,
                        ),
                        style: TextStyle(fontSize: 14, color: appColors.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _applyCustomConcern,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Use", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
                if (_isCustomSelected && _customConcernController.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: appColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Custom concern selected: \"${_customConcernController.text.trim()}\"",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: appColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Top Concerns Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Or Choose from Common Concerns",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: appColors.text),
                  ),
                ),
                if (!_isCustomSelected && selectedDisplay.isNotEmpty)
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: appColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Selected: $selectedDisplay",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: appColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Grid of Predefined Concerns
        SliverPadding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 90),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final concern = concerns[index];
                final isSelected = !_isCustomSelected && concern.id == selectedConcernId;
                return ConcernCard(
                  concern: concern,
                  isSelected: isSelected,
                  onTap: () => _selectPredefinedConcern(concern.id),
                );
              },
              childCount: concerns.length,
            ),
          ),
        ),
      ],
    );
  }
}
