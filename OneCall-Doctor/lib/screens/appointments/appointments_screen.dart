import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecall_doctor/models/appointment_model.dart';
import 'package:onecall_doctor/widgets/appointment_card.dart';
import 'package:onecall_doctor/providers/auth_provider.dart';
import 'package:onecall_doctor/services/email_service.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:onecall_doctor/providers/appointment_provider.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(appointmentsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Appointments"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xff3A643B),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xff3A643B),
          tabs: const [
            Tab(text: "Upcoming"),
            Tab(text: "Completed"),
            Tab(text: "Cancelled"),
          ],
        ),
      ),
      body: appointmentsAsync.when(
        data: (appointments) {
          final upcoming = appointments
              .where((a) => a.status == 'upcoming' || a.status == 'accepted')
              .toList();
          final completed =
              appointments.where((a) => a.status == 'completed').toList();
          final cancelled =
              appointments.where((a) => a.status == 'cancelled').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(upcoming, isUpcoming: true),
              _buildList(completed, isUpcoming: false),
              _buildList(cancelled, isUpcoming: false),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildList(List<Appointment> list, {required bool isUpcoming}) {
    if (list.isEmpty) {
      return const Center(
        child: Text(
          "No appointments found",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final appointment = list[index];
        return AppointmentCard(
          appointment: appointment,
          onCheckPrescription: !isUpcoming
              ? () {
                  _showPrescriptionDialog(context, appointment);
                }
              : null,
        );
      },
    );
  }

  void _showPrescriptionDialog(BuildContext context, Appointment appointment) {
    showDialog(
      context: context,
      builder: (context) {
        final bool hasPrescription = appointment.prescription != null &&
            appointment.prescription!.isNotEmpty;

        return StatefulBuilder(
          builder: (context, setState) {
            bool isEditing = !hasPrescription;

            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(hasPrescription && !isEditing
                      ? "Prescription"
                      : "Write Prescription"),
                  if (hasPrescription && !isEditing)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        setState(() {
                          isEditing = true;
                        });
                      },
                    ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: !isEditing
                    ? SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            appointment.prescription!,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      )
                    : PrescriptionForm(
                        initialPrescription: appointment.prescription,
                        onSave: (prescription) async {
                          Navigator.pop(context);
                          try {
                            await ref
                                .read(firebaseFirestoreProvider)
                                .collection('appointments')
                                .doc(appointment.id)
                                .update({'prescription': prescription});

                            final user = ref.read(firebaseAuthProvider).currentUser;
                            final doctorName = user?.displayName ?? "Doctor";

                            await EmailService().sendPrescriptionEmail(
                              userEmail: appointment.userEmail,
                              appointmentId: appointment.id,
                              doctorName: doctorName,
                              prescription: prescription,
                              date: appointment.date.toString().split(' ')[0],
                            );

                            if (context.mounted) {
                              showTopSnackBar(
                                Overlay.of(context),
                                const CustomSnackBar.success(
                                    message: "Prescription sent successfully"),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showTopSnackBar(
                                Overlay.of(context),
                                CustomSnackBar.error(
                                    message: "Failed to send: $e"),
                              );
                            }
                          }
                        },
                      ),
              ),
              actions: [
                if (!isEditing)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class PrescriptionForm extends StatefulWidget {
  final String? initialPrescription;
  final Function(String) onSave;

  const PrescriptionForm({super.key, this.initialPrescription, required this.onSave});

  @override
  State<PrescriptionForm> createState() => _PrescriptionFormState();
}

class _PrescriptionFormState extends State<PrescriptionForm> {
  final List<MedicineEntry> _medicines = [];

  @override
  void initState() {
    super.initState();
    _addMedicine();
  }

  void _addMedicine() {
    setState(() {
      _medicines.add(MedicineEntry());
    });
  }

  void _removeMedicine(int index) {
    if (_medicines.length > 1) {
      setState(() {
        _medicines.removeAt(index);
      });
    }
  }

  String _generatePrescriptionString() {
    return _medicines
        .where((m) => m.nameController.text.trim().isNotEmpty)
        .map((m) {
      final name = m.nameController.text.trim();
      List<String> timings = [];
      if (m.morning) timings.add("Morning");
      if (m.afternoon) timings.add("Afternoon");
      if (m.evening) timings.add("Evening");
      if (m.night) timings.add("Night");

      final timingStr = timings.isEmpty ? "As needed" : timings.join("-");
      return "$name ($timingStr) - ${m.food}";
    }).join("\n");
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _medicines.length,
            itemBuilder: (context, index) {
              final medicine = _medicines[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: medicine.nameController,
                              decoration: const InputDecoration(
                                labelText: "Medicine Name",
                                hintText: "Paracetamol, etc.",
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () => _removeMedicine(index),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTimingToggle("M", medicine.morning, (val) => setState(() => medicine.morning = val)),
                          _buildTimingToggle("A", medicine.afternoon, (val) => setState(() => medicine.afternoon = val)),
                          _buildTimingToggle("E", medicine.evening, (val) => setState(() => medicine.evening = val)),
                          _buildTimingToggle("N", medicine.night, (val) => setState(() => medicine.night = val)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: medicine.food,
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                        items: ["Before Food", "After Food"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) => setState(() => medicine.food = val!),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              onPressed: _addMedicine,
              icon: const Icon(Icons.add),
              label: const Text("Add"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff3A643B), foregroundColor: Colors.white),
            ),
            ElevatedButton(
              onPressed: () {
                final result = _generatePrescriptionString();
                if (result.isNotEmpty) {
                  widget.onSave(result);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add at least one medicine")));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: const Text("Submit"),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildTimingToggle(String label, bool value, Function(bool) onChanged) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Checkbox(
          value: value,
          onChanged: (val) => onChanged(val ?? false),
          activeColor: const Color(0xff3A643B),
        ),
      ],
    );
  }
}

class MedicineEntry {
  final TextEditingController nameController = TextEditingController();
  bool morning = false;
  bool afternoon = false;
  bool evening = false;
  bool night = false;
  String food = "After Food";
}
