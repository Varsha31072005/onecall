import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:onecall_doctor/providers/auth_provider.dart';
import 'package:onecall_doctor/widgets/app_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, List<String>> _schedule = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize schedule from current doctor data
    final doctor = ref.read(currentDoctorStreamProvider).value;
    if (doctor != null) {
      _schedule = Map.from(doctor.availableSlots);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // Default slot definitions
  final List<String> _morningSlots = ['09:00 AM', '09:35 AM', '10:05 AM', '11:00 AM'];
  final List<String> _afternoonSlots = ['12:00 PM', '12:35 PM', '01:05 PM', '01:45 PM', '03:00 PM'];
  final List<String> _eveningSlots = ['06:00 PM', '07:00 PM', '08:05 PM', '09:00 PM'];

  // Cache to store globally blocked slots for this session (or ideally persist in doctor model)
  // For now, "option to turn off... in all that 15 days dynamically" implies an action.
  
  List<String> _generateDefaultSlots(DateTime date) {
    if (date.weekday == DateTime.sunday) return []; 
    // Combine all lists
    return [..._morningSlots, ..._afternoonSlots, ..._eveningSlots];
  }

  List<String> _getSlotsForSelectedDate() {
    final dateKey = _formatDate(_selectedDate);
    if (_schedule.containsKey(dateKey)) {
      return _schedule[dateKey]!;
    }
    return _generateDefaultSlots(_selectedDate);
  }

  void _addSlot(TimeOfDay time) {
    final dateKey = _formatDate(_selectedDate);
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final formattedTime = DateFormat('hh:mm a').format(dt);

    if (!_schedule.containsKey(dateKey)) {
      _schedule[dateKey] = _generateDefaultSlots(_selectedDate);
    }

    if (!_schedule[dateKey]!.contains(formattedTime)) {
      setState(() {
        _schedule[dateKey]!.add(formattedTime);
        _schedule[dateKey]!.sort((a, b) {
           DateTime timeA = DateFormat('hh:mm a').parse(a);
           DateTime timeB = DateFormat('hh:mm a').parse(b);
           return timeA.compareTo(timeB);
        });
      });
    }
  }

  void _removeSlot(String slot) {
    // Show dialog to ask if remove for today or all days
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Slot"),
        content: Text("Do you want to remove $slot for just this day, or for all upcoming days?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _performRemoveSlot(slot, removeGlobally: false);
            },
            child: const Text("Just Today"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _performRemoveSlot(slot, removeGlobally: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3A643B),
              foregroundColor: Colors.white,
            ),
            child: const Text("All 15 Days"),
          ),
        ],
      ),
    );
  }

  void _performRemoveSlot(String slot, {required bool removeGlobally}) {
    setState(() {
      if (removeGlobally) {
        // Iterate through all 15 days
        for (int i = 0; i < 15; i++) {
          final date = DateTime.now().add(Duration(days: i));
          final key = _formatDate(date);
          
          // If day doesn't exist in map yet, we MUST materialize it to modify it
          // OR we can leave it be if we had a "global blocked list".
          // Since we are using a simple map approach: materialize all 15 days if they match defaults.
          
          if (!_schedule.containsKey(key)) {
             _schedule[key] = _generateDefaultSlots(date);
          }
          
          _schedule[key]?.remove(slot);
        }
      } else {
        // Just today
        final dateKey = _formatDate(_selectedDate);
         if (!_schedule.containsKey(dateKey)) {
          _schedule[dateKey] = _generateDefaultSlots(_selectedDate);
         }
        _schedule[dateKey]?.remove(slot);
      }
    });

    if (removeGlobally) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Removed $slot from all 15 days")),
      );
    }
  }

  Future<void> _saveSchedule() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authRepositoryProvider).updateSchedule(_schedule);
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.success(message: "Schedule updated successfully!"),
        );
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          CustomSnackBar.error(message: "Failed to update schedule: $e"),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep internal state in sync with provider if it updates from outside (optional but good practice)
    // ref.listen(currentDoctorStreamProvider, (prev, next) {
    //   next.whenData((doctor) {
    // if (doctor != null) {
    //  // Decide if we want to overwrite local changes or not. 
    //  // Usually better not to overwrite while editing.
    // }
    //   });
    // });

    return Scaffold(
      appBar: AppAppBar(
        name: "MANAGE SCHEDULE",
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          const Divider(),
          Expanded(
            child: _buildSlotsList(),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff3A643B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Save Changes",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final TimeOfDay? time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );
          if (time != null) {
            _addSlot(time);
          }
        },
        backgroundColor: const Color(0xff3A643B),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 15, // Next 15 days
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = _formatDate(date) == _formatDate(_selectedDate);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
            },
            child: Container(
              width: 70,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xff3A643B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.grey.shade300,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xff3A643B).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotsList() {
    final slots = _getSlotsForSelectedDate();

    if (slots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "No slots available for\n${DateFormat('MMMM d, yyyy').format(_selectedDate)}",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              "Tap + to add a time slot",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Available Slots (${slots.length})",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xff3A643B),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: slots.map((slot) {
              return Chip(
                label: Text(
                  slot,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                deleteIcon: const Icon(Icons.close, size: 18, color: Colors.red),
                onDeleted: () => _removeSlot(slot),
                padding: const EdgeInsets.all(8),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
