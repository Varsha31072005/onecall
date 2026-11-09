import 'package:callone/data/models/appointment.dart';
import 'package:callone/services/booking_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'appointments_provider.g.dart';

@riverpod
Stream<List<AppointmentModel>> userAppointments(UserAppointmentsRef ref, String userId) {
  return BookingService().getAppointmentsStream(userId);
}
