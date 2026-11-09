import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onecall_doctor/services/email_service.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> cancelAppointment(
      String appointmentId,
      String doctorId,
      String patientId,
      double price,
      String userEmail,
      String doctorName,
      DateTime date) async {
    final appointmentRef = _firestore.collection('appointments').doc(appointmentId);
    final userRef = _firestore.collection('users').doc(patientId);
    final doctorRef = _firestore.collection('doctors').doc(doctorId);

    try {
      await _firestore.runTransaction((transaction) async {
        final appointmentSnapshot = await transaction.get(appointmentRef);
        if (!appointmentSnapshot.exists) throw Exception("Appointment not found");

        final status = appointmentSnapshot.data()?['status'];
        if (status == 'cancelled') throw Exception("Appointment already cancelled");
        if (status == 'completed') throw Exception("Cannot cancel completed appointment");

        // Logic for Doctor Cancellation: Full Refund
        
        // 1. Refund 100% to User
        transaction.update(userRef, {
          'walletBalance': FieldValue.increment(price)
        });

        // Log Transaction for User
        final userTxnRef = userRef.collection('transactions').doc();
        transaction.set(userTxnRef, {
            'amount': price,
            'type': 'credit',
            'date': FieldValue.serverTimestamp(),
            'description': 'Refund: Doctor Cancellation (100%)',
        });

        // 2. Deduct 100% from Doctor
        transaction.update(doctorRef, {
          'wallet': FieldValue.increment(-price)
        });

        // 3. Update Status
        transaction.update(appointmentRef, {'status': 'cancelled', 'cancelledBy': 'doctor'});
      });

      // Send Email
      await EmailService().sendCancellationEmail(
        userEmail: userEmail,
        appointmentId: appointmentId,
        doctorName: doctorName,
        date: date.toString().split(' ')[0],
      );
    } catch (e) {
      print("Error cancelling appointment: $e");
      rethrow;
    }
  }
}
