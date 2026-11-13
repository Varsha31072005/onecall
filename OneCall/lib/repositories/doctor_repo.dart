import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/doctor.dart';

class DoctorsRepository {
  Future<List<Doctor>> getAllDoctors() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('doctors').get();
      return snapshot.docs.map((doc) => Doctor.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Failed to fetch doctors: $e');
    }
  }
}
