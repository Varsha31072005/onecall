import 'package:callone/data/models/appointment.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'appointment_provider.g.dart';

@Riverpod(keepAlive: true)
class Appointment extends _$Appointment {
  @override
  AppointmentModel? build() {
    return null;
  }

  void updateAppointment({
    String? patientId,
    String? concernId,
    String? doctorId,
    String? consultationType,
    DateTime? date,
    String? time,
    double? severity,
    String? duration,
    String? durationType,
    String? userEmail,
    String? doctorEmail,
    String? triageUrgency,
    double? triageConfidence,
    String? clinicalAdvisory,
    List<String>? detectedRedFlags,
    String? predictedSpecialty,
    String? patientQuery,
    String? description,
    List<String>? healthFiles,
  }) {
    state = AppointmentModel(
      patientId: patientId ?? state?.patientId ?? '',
      concernId: concernId ?? state?.concernId ?? '',
      doctorId: doctorId ?? state?.doctorId ?? '',
      consultationType: consultationType ?? state?.consultationType ?? '',
      date: date ?? state?.date ?? DateTime.now(),
      time: time ?? state?.time ?? '',
      severity: severity ?? state?.severity ?? 0.0,
      duration: duration ?? state?.duration ?? '',
      durationType: durationType ?? state?.durationType ?? '',
      userEmail: userEmail ?? state?.userEmail ?? '',
      doctorEmail: doctorEmail ?? state?.doctorEmail ?? '',
      triageUrgency: triageUrgency ?? state?.triageUrgency,
      triageConfidence: triageConfidence ?? state?.triageConfidence,
      clinicalAdvisory: clinicalAdvisory ?? state?.clinicalAdvisory,
      detectedRedFlags: detectedRedFlags ?? state?.detectedRedFlags,
      predictedSpecialty: predictedSpecialty ?? state?.predictedSpecialty,
      patientQuery: patientQuery ?? state?.patientQuery,
      description: description ?? state?.description,
      healthFiles: healthFiles ?? state?.healthFiles,
    );
  }

  void reset() {
    state = null;
  }
}
