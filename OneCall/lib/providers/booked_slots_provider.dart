import 'package:callone/providers/appointment_provider.dart';
import 'package:callone/providers/selected_doctor_provider.dart';
import 'package:callone/services/booking_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bookedSlotsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final appointment = ref.watch(appointmentProvider);
  final doctor = ref.watch(selectedDoctorProvider);

  if (appointment == null || doctor == null) {
    return Stream.value([]);
  }

  return BookingService().getBookedTimeSlots(doctor.id, appointment.date);
});
