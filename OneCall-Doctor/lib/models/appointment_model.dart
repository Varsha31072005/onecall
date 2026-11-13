import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String id;
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
  final double price;
  final String? prescription;
  final String? cancelledBy;
  final DateTime createdAt;
  final String? description;
  final List<String>? healthFiles;

  // AI-Assisted Clinical Triage & Specialty
  final String? triageUrgency;
  final double? triageConfidence;
  final String? clinicalAdvisory;
  final List<String>? detectedRedFlags;
  final String? predictedSpecialty;
  final String? patientQuery;

  Appointment({
    required this.id,
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
    required this.status,
    required this.price,
    this.prescription,
    this.cancelledBy,
    required this.createdAt,
    this.description,
    this.healthFiles,
    this.triageUrgency,
    this.triageConfidence,
    this.clinicalAdvisory,
    this.detectedRedFlags,
    this.predictedSpecialty,
    this.patientQuery,
  });

  factory Appointment.fromMap(Map<String, dynamic> data, String id) {
    return Appointment(
      id: id,
      patientId: data['patientId'] ?? '',
      concernId: data['concernId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      consultationType: data['consultationType'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      time: data['time'] ?? '',
      severity: (data['severity'] ?? 0.0).toDouble(),
      duration: data['duration'] ?? '',
      durationType: data['durationType'] ?? '',
      status: data['status'] ?? 'upcoming',
      userEmail: data['userEmail'] ?? '',
      doctorEmail: data['doctorEmail'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      prescription: data['prescription'],
      cancelledBy: data['cancelledBy'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['date'] as Timestamp).toDate(),
      description: data['description'],
      healthFiles: data['healthFiles'] != null
          ? List<String>.from(data['healthFiles'])
          : null,
      triageUrgency: data['triageUrgency'],
      triageConfidence: (data['triageConfidence'] as num?)?.toDouble(),
      clinicalAdvisory: data['clinicalAdvisory'],
      detectedRedFlags: data['detectedRedFlags'] != null
          ? List<String>.from(data['detectedRedFlags'])
          : null,
      predictedSpecialty: data['predictedSpecialty'],
      patientQuery: data['patientQuery'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'concernId': concernId,
      'doctorId': doctorId,
      'consultationType': consultationType,
      'date': Timestamp.fromDate(date),
      'time': time,
      'severity': severity,
      'duration': duration,
      'durationType': durationType,
      'status': status,
      'userEmail': userEmail,
      'doctorEmail': doctorEmail,
      'price': price,
      'prescription': prescription,
      'cancelledBy': cancelledBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'description': description,
      'healthFiles': healthFiles,
      'triageUrgency': triageUrgency,
      'triageConfidence': triageConfidence,
      'clinicalAdvisory': clinicalAdvisory,
      'detectedRedFlags': detectedRedFlags,
      'predictedSpecialty': predictedSpecialty,
      'patientQuery': patientQuery,
    };
  }
}
