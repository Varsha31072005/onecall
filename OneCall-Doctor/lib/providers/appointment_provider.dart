import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecall_doctor/models/appointment_model.dart';
import 'package:onecall_doctor/providers/auth_provider.dart';
import 'dart:developer' as dev;

final completeAppointmentProvider = FutureProvider.autoDispose.family<void, Appointment>((ref, appointment) async {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final appointmentRef = firestore.collection('appointments').doc(appointment.id);
  final doctorRef = firestore.collection('doctors').doc(appointment.doctorId);

  await firestore.runTransaction((transaction) async {
    final doctorSnapshot = await transaction.get(doctorRef);
    if (!doctorSnapshot.exists) throw Exception("Doctor not found!");
    transaction.update(appointmentRef, {'status': 'completed'});
    transaction.update(doctorRef, {'wallet': FieldValue.increment(appointment.price)});
  });
});

final appointmentsStreamProvider = StreamProvider.autoDispose<List<Appointment>>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  final firestore = ref.watch(firebaseFirestoreProvider);
  
  if (user == null) return Stream.value([]);

  return firestore
      .collection('appointments')
      .where('doctorId', isEqualTo: user.uid)
      .snapshots()
      .asyncMap((snapshot) async {
    
    final List<Appointment> appointments = [];

    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = Map<String, dynamic>.from(doc.data());
      final String appointmentId = doc.id;
      final String? concernId = data['concernId'];

      // Log raw keys for this specific appointment to see if description/healthFiles appeared
      dev.log("Appointment $appointmentId keys: ${data.keys.toList()}");

      // 1. Check if they exist in the appointment document itself (priority)
      bool hasDetails = data['description'] != null || data['healthFiles'] != null;

      // 2. If not found, try 'concerns' collection
      if (!hasDetails && concernId != null && concernId.isNotEmpty) {
        try {
          final concernDoc = await firestore.collection('concerns').doc(concernId).get();
          if (concernDoc.exists) {
            final cData = concernDoc.data();
            data['description'] = cData?['description'];
            data['healthFiles'] = cData?['healthFiles'];
            dev.log("Found details in 'concerns/$concernId' for $appointmentId");
          } else {
            dev.log("No document found in 'concerns/$concernId'");
          }
        } catch (e) {
          dev.log("Error fetching from concerns collection: $e");
        }
      }

      appointments.add(Appointment.fromMap(data, appointmentId));
    }
    return appointments;
  });
});
