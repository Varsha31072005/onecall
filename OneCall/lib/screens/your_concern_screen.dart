import 'package:callone/app_styles/app_colors.dart';
import 'package:callone/providers/appointment_provider.dart';
import 'package:callone/data/models/concern.dart';
import 'package:callone/providers/concern_provider.dart' hide Concern;
import 'package:callone/widgets/hero_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class YourConcernScreen extends ConsumerStatefulWidget {
  const YourConcernScreen({super.key});

  @override
  ConsumerState<YourConcernScreen> createState() => _YourConcernScreenState();
}

class _YourConcernScreenState extends ConsumerState<YourConcernScreen> {
  // 0: Mild, 1: Moderate, 2: Severe
  double _severity = 1.0;
  final TextEditingController _durationController = TextEditingController(text: '3');
  final TextEditingController _symptomsController = TextEditingController();
  String _durationUnit = 'Days';
  final List<PlatformFile> _selectedFiles = [];
  final List<String> _durationUnits = const ['Days', 'Weeks', 'Months', 'Years'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appt = ref.read(appointmentProvider);
      if (appt?.patientQuery != null && appt!.patientQuery!.isNotEmpty) {
        _symptomsController.text = appt.patientQuery!;
      } else if (appt?.description != null && appt!.description!.isNotEmpty) {
        _symptomsController.text = appt.description!;
      }
      if (appt?.duration != null && appt!.duration.isNotEmpty) {
        // Extract number if already formatted
        final parts = appt.duration.split(' ');
        if (parts.isNotEmpty) {
          _durationController.text = parts[0];
        }
      }
      if (appt?.durationType != null && appt!.durationType.isNotEmpty) {
        final matching = _durationUnits.where(
          (u) => u.toLowerCase() == appt.durationType.toLowerCase(),
        );
        if (matching.isNotEmpty) {
          setState(() {
            _durationUnit = matching.first;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _durationController.dispose();
    _symptomsController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          CustomSnackBar.error(message: "Error picking files: $e"),
        );
      }
    }
  }

  /// Parses duration into the exact string format expected by Model 1 and Model 2:
  /// Examples: "3 days", "2 weeks", "1 month", "2 years"
  String _parseDurationForModel(String rawNumber, String unit) {
    final num = int.tryParse(rawNumber.trim()) ?? 1;
    final lowerUnit = unit.toLowerCase();
    // Normalize singular/plural (e.g. 1 day vs 2 days, 1 month vs 2 months)
    if (num == 1) {
      if (lowerUnit == 'days') return '1 day';
      if (lowerUnit == 'weeks') return '1 week';
      if (lowerUnit == 'months') return '1 month';
      if (lowerUnit == 'years') return '1 year';
    } else {
      if (lowerUnit == 'day' || lowerUnit == 'days') return '$num days';
      if (lowerUnit == 'week' || lowerUnit == 'weeks') return '$num weeks';
      if (lowerUnit == 'month' || lowerUnit == 'months') return '$num months';
      if (lowerUnit == 'year' || lowerUnit == 'years') return '$num years';
    }
    return '$num $lowerUnit';
  }

  String _severityLabel(double val) {
    if (val <= 0.5) return 'Mild';
    if (val <= 1.5) return 'Moderate';
    return 'Severe';
  }

  void _handleProceed(String concernDisplay) {
    final symptomsText = _symptomsController.text.trim();
    if (symptomsText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please describe your symptoms to continue"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final durationValue = _durationController.text.trim();
    if (durationValue.isEmpty || int.tryParse(durationValue) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid duration number (e.g. 3)"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Parse duration according to ML model requirements:
    final parsedModelDuration = _parseDurationForModel(durationValue, _durationUnit);

    // Save to Appointment provider
    ref.read(appointmentProvider.notifier).updateAppointment(
      severity: _severity,
      duration: parsedModelDuration,
      durationType: _durationUnit,
      concernId: concernDisplay,
      patientQuery: symptomsText,
      description: symptomsText,
      healthFiles: _selectedFiles.map((f) => f.path ?? '').where((p) => p.isNotEmpty).toList(),
    );

    // Redirect to Basic Info Confirmation Page:
    Navigator.pushNamed(context, '/basic_info_confirmation');
  }

  @override
  Widget build(BuildContext context) {
    final appColors = ref.watch(appColorsProvider);
    final selectedConcernId = ref.watch(concernProvider);
    final appointment = ref.watch(appointmentProvider);

    // Determine concern title: custom or predefined
    String concernTitle = appointment?.concernId ?? selectedConcernId ?? 'General Concern';
    final match = concerns.where((c) => c.id == concernTitle || c.id == selectedConcernId);
    if (match.isNotEmpty) {
      concernTitle = match.first.title;
    }

    return Scaffold(
      backgroundColor: appColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HeroWidget(title: "Concern Details", showBackButton: true),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: appColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_outlined, size: 16, color: appColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          "Step 1 of 3: Clinical Intake",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: appColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selected / Custom Concern Badge Card
                  Text(
                    "Selected Medical Concern",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: appColors.background2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: appColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: appColors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.healing_rounded, color: appColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                concernTitle,
                                style: TextStyle(
                                  color: appColors.text,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Chief complaint topic for clinical triage",
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Symptoms Description Field
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Describe your symptoms",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: appColors.text),
                      ),
                      Text(
                        "*Required",
                        style: TextStyle(fontSize: 12, color: appColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Provide specific sensations, location, triggers (e.g. chest tightness, fever with chills, persistent dry cough)",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _symptomsController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Describe your symptoms in detail here...",
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      contentPadding: const EdgeInsets.all(16),
                      filled: true,
                      fillColor: appColors.background2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: appColors.primary, width: 2),
                      ),
                    ),
                    style: TextStyle(color: appColors.text, fontSize: 14),
                  ),
                  const SizedBox(height: 26),

                  // Severity Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Severity of your symptoms",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: appColors.text),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _severity == 0
                              ? Colors.green.withOpacity(0.15)
                              : (_severity == 1
                                  ? Colors.amber.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _severityLabel(_severity),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _severity == 0
                                ? Colors.green[800]
                                : (_severity == 1 ? Colors.amber[900] : Colors.red[800]),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: _severity == 0
                          ? Colors.green
                          : (_severity == 1 ? Colors.amber[700] : Colors.redAccent),
                      inactiveTrackColor: Colors.grey[300],
                      thumbColor: _severity == 0
                          ? Colors.green
                          : (_severity == 1 ? Colors.amber[700] : Colors.redAccent),
                      trackHeight: 6.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11.0),
                    ),
                    child: Slider(
                      value: _severity,
                      min: 0,
                      max: 2,
                      divisions: 2,
                      onChanged: (value) {
                        setState(() {
                          _severity = value;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSeverityOption("Mild", 0, appColors),
                        _buildSeverityOption("Moderate", 1, appColors),
                        _buildSeverityOption("Severe", 2, appColors),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Duration Input & Model Parsing
                  Text(
                    "How long have you been facing this? (Duration)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: appColors.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Parsed for AI clinical triage (days, weeks, months, or years)",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      // Numeric Duration input
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            filled: true,
                            fillColor: appColors.background2,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appColors.primary, width: 2),
                            ),
                          ),
                          style: TextStyle(color: appColors.text, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Duration Unit Dropdown
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: appColors.background2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _durationUnit,
                              isExpanded: true,
                              icon: Icon(Icons.arrow_drop_down, color: appColors.primary),
                              style: TextStyle(
                                color: appColors.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              items: _durationUnits.map((String unit) {
                                return DropdownMenuItem<String>(
                                  value: unit,
                                  child: Text(unit),
                                );
                              }).toList(),
                              onChanged: (String? newUnit) {
                                if (newUnit != null) {
                                  setState(() {
                                    _durationUnit = newUnit;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Parsed Duration Preview for the Model
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.precision_manufacturing_outlined, size: 18, color: appColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Parsed Model Input: \"${_parseDurationForModel(_durationController.text, _durationUnit)}\"",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: appColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Upload Option (Optional health records)
                  Text(
                    "Upload health records (Optional)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: appColors.text),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickFiles,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.cloud_upload_outlined, color: appColors.primary, size: 32),
                          const SizedBox(height: 8),
                          Text("Tap to upload files", style: TextStyle(color: appColors.primary, fontWeight: FontWeight.w500)),
                          Text("PDF, Image (Max 5MB)", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                  ),

                  if (_selectedFiles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ..._selectedFiles.map((file) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file, color: appColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              file.name,
                              style: TextStyle(color: appColors.text, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFiles.remove(file);
                              });
                            },
                            child: const Icon(Icons.close, size: 18, color: Colors.red),
                          ),
                        ],
                      ),
                    )),
                  ],

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),

          // Bottom Proceed Button -> Basic Info Page
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _handleProceed(concernTitle),
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Continue to Basic Info",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityOption(String label, int val, AppColors appColors) {
    final isSelected = _severity.round() == val;
    return GestureDetector(
      onTap: () {
        setState(() {
          _severity = val.toDouble();
        });
      },
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? appColors.primary : Colors.grey[600],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}
