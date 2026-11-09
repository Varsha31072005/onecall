class AppointmentModel {
  final String patientId;
  final String concernId;
  final String doctorId;
  final String consultationType;
  final DateTime date;
  final String time;
  final double severity;
  final String duration;
  final String durationType;
  final String status;
  final String userEmail;
  final String doctorEmail;
  final String? prescription;
  final String? description;
  final List<String>? healthFiles;
  final String? id;
  final bool isRated;
  final String? cancelledBy;

  // AI-Assisted Clinical Triage & Specialty Fields
  final String? triageUrgency;
  final double? triageConfidence;
  final String? clinicalAdvisory;
  final List<String>? detectedRedFlags;
  final String? predictedSpecialty;
  final String? patientQuery;

  const AppointmentModel({
    this.id,
    required this.patientId,
    required this.concernId,
    required this.doctorId,
    required this.consultationType,
    required this.date,
    required this.time,
    required this.severity,
    required this.duration,
    required this.durationType,
    required this.userEmail,
    required this.doctorEmail,
    this.status = 'upcoming',
    this.prescription,
    this.description,
    this.healthFiles,
    this.isRated = false,
    this.cancelledBy,
    this.triageUrgency,
    this.triageConfidence,
    this.clinicalAdvisory,
    this.detectedRedFlags,
    this.predictedSpecialty,
    this.patientQuery,
  });
}
