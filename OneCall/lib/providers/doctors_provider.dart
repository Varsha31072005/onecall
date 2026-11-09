import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/doctor.dart';
import '../repositories/doctor_repo.dart';

part 'doctors_provider.g.dart';

@riverpod
Future<List<Doctor>> doctors(DoctorsRef ref) async {
  final repository = DoctorsRepository();
  return repository.getAllDoctors();
}

@riverpod
Stream<Doctor?> doctorStream(DoctorStreamRef ref, String id) {
  return FirebaseFirestore.instance
      .collection('doctors')
      .doc(id)
      .snapshots()
      .map((doc) {
    if (doc.exists && doc.data() != null) {
      return Doctor.fromMap(doc.data()!, doc.id);
    }
    return null;
  });
}
