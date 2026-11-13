import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:callone/data/models/appointment.dart';
import 'package:callone/services/email_service.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> bookAppointment(AppointmentModel appointment, double price) async {
    final userRef = _firestore.collection('users').doc(appointment.patientId);
    final appointmentRef = _firestore.collection('appointments').doc();
    final doctorRef = _firestore.collection('doctors').doc(appointment.doctorId);

    try {
      await _firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        final doctorSnapshot = await transaction.get(doctorRef); // Get doctor snapshot

        if (!userSnapshot.exists) {
          throw Exception("User does not exist");
        }
        
        // Update: Though we don't strictly need to check if doctor exists for FieldValue.increment to work (it creates the field if missing), 
        // it is good practice to ensure we are paying a valid doctor.
        if (!doctorSnapshot.exists) {
           throw Exception("Doctor does not exist");
        }

        final userData = userSnapshot.data() as Map<String, dynamic>;
        final double currentBalance = (userData['walletBalance'] ?? 0).toDouble();

        if (currentBalance < price) {
          throw Exception("Insufficient wallet balance");
        }

        final double newBalance = currentBalance - price;

        // Deduct balance
        transaction.update(userRef, {'walletBalance': newBalance});

        // Credit doctor wallet
        transaction.update(doctorRef, {'wallet': FieldValue.increment(price)});

        // Log transaction for User (Debit)
        final transactionRef = userRef.collection('transactions').doc();
        transaction.set(transactionRef, {
          'amount': price,
          'type': 'debit',
          'date': FieldValue.serverTimestamp(),
          'description': 'Consultation Booking', // Could be more specific like "Consultation with Dr. X"
        });

        // Create appointment
        transaction.set(appointmentRef, {
          'patientId': appointment.patientId,
          'concernId': appointment.concernId,
          'doctorId': appointment.doctorId,
          'consultationType': appointment.consultationType,
          'date': Timestamp.fromDate(appointment.date),
          'time': appointment.time,
          'severity': appointment.severity,
          'duration': appointment.duration,
          'durationType': appointment.durationType,
          'description': appointment.description, // Added description
          'healthFiles': appointment.healthFiles, // Added health files
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'upcoming',
          'price': price,
          'userEmail': appointment.userEmail,
          'doctorEmail': appointment.doctorEmail,
          'triageUrgency': appointment.triageUrgency,
          'triageConfidence': appointment.triageConfidence,
          'clinicalAdvisory': appointment.clinicalAdvisory,
          'detectedRedFlags': appointment.detectedRedFlags,
          'predictedSpecialty': appointment.predictedSpecialty,
          'patientQuery': appointment.patientQuery,
        });
      });

      // Send email notifications
      try {
        print("Attempting to send email to Doctor: ${appointment.doctorEmail} and User: ${appointment.userEmail}");
        await EmailService().sendAppointmentConfirmation(
          doctorEmail: appointment.doctorEmail,
          userEmail: appointment.userEmail,
          appointmentId: appointmentRef.id,
          date: "${appointment.date.day}/${appointment.date.month}/${appointment.date.year}",
          time: appointment.time,
          doctorName: "Doctor", // ideally fetch doctor name
        );
      } catch (e) {
        print("Failed to send email: $e");
        // Don't rethrow, as booking was successful
      }
    } catch (e) {
      print('Error booking appointment: $e');
      rethrow;
    }
  }

  Future<List<AppointmentModel>> getUserAppointments(String userId) async {
    print("Fetching appointments for user: $userId");
    try {
      final snapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();

      print("Found ${snapshot.docs.length} appointments");

      return snapshot.docs.map((doc) {
        final data = doc.data();
        print("Appointment data: $data");
        return AppointmentModel(
          patientId: data['patientId'] ?? '',
          concernId: data['concernId'] ?? '',
          doctorId: data['doctorId'] ?? '',
          consultationType: data['consultationType'] ?? '',
          date: (data['date'] as Timestamp).toDate(),
          time: data['time'] ?? '',
          severity: (data['severity'] ?? 0.0).toDouble(),
          duration: data['duration'] ?? '',
          durationType: data['durationType'] ?? '',
          description: data['description'], // Map description
          healthFiles: data['healthFiles'] != null ? List<String>.from(data['healthFiles']) : null, // Map health files
          userEmail: data['userEmail'] ?? '',
          doctorEmail: data['doctorEmail'] ?? '',
          id: doc.id,
          prescription: data['prescription'],
          isRated: data['isRated'] ?? false,
          cancelledBy: data['cancelledBy'],
          triageUrgency: data['triageUrgency'],
          triageConfidence: (data['triageConfidence'] as num?)?.toDouble(),
          clinicalAdvisory: data['clinicalAdvisory'],
          detectedRedFlags: data['detectedRedFlags'] != null
              ? List<String>.from(data['detectedRedFlags'])
              : null,
          predictedSpecialty: data['predictedSpecialty'],
          patientQuery: data['patientQuery'],
        );
      }).toList();
    } catch (e) {
      print('Error fetching appointments: $e');
      // If index is missing, this error will tell us
      return [];
    }
  }
  Stream<List<AppointmentModel>> getAppointmentsStream(String userId) {
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return AppointmentModel(
              patientId: data['patientId'] ?? '',
              concernId: data['concernId'] ?? '',
              doctorId: data['doctorId'] ?? '',
              consultationType: data['consultationType'] ?? '',
              date: (data['date'] as Timestamp).toDate(),
              time: data['time'] ?? '',
              severity: (data['severity'] ?? 0.0).toDouble(),
              duration: data['duration'] ?? '',
              durationType: data['durationType'] ?? '',
              description: data['description'], // Map description
              healthFiles: data['healthFiles'] != null ? List<String>.from(data['healthFiles']) : null, // Map health files
              status: data['status'] ?? 'upcoming',
              userEmail: data['userEmail'] ?? '',
              doctorEmail: data['doctorEmail'] ?? '',
              id: doc.id,
              prescription: data['prescription'],
              isRated: data['isRated'] ?? false,
              cancelledBy: data['cancelledBy'],
              triageUrgency: data['triageUrgency'],
              triageConfidence: (data['triageConfidence'] as num?)?.toDouble(),
              clinicalAdvisory: data['clinicalAdvisory'],
              detectedRedFlags: data['detectedRedFlags'] != null
                  ? List<String>.from(data['detectedRedFlags'])
                  : null,
              predictedSpecialty: data['predictedSpecialty'],
              patientQuery: data['patientQuery'],
            );
          }).toList();
        });
  }
  Stream<List<String>> getBookedTimeSlots(String doctorId, DateTime date) {
    // Create start and end of the selected day
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()['time'] as String).toList();
    });
  }

  Future<void> rateDoctor(String appointmentId, String doctorId, double rating, String review) async {
    final appointmentRef = _firestore.collection('appointments').doc(appointmentId);
    final doctorRef = _firestore.collection('doctors').doc(doctorId);

    // 1. Mark appointment as rated within a transaction to prevent double-rating
    await _firestore.runTransaction((transaction) async {
      final appointmentSnapshot = await transaction.get(appointmentRef);

      if (!appointmentSnapshot.exists) {
        throw Exception("Appointment does not exist");
      }

      final appointmentData = appointmentSnapshot.data() as Map<String, dynamic>;
      if (appointmentData['isRated'] == true) {
        throw Exception("You have already rated this appointment");
      }

      transaction.update(appointmentRef, {
        'isRated': true,
        'ratingGiven': rating,
        'review': review,
      });
    });

    // 2. Calculate new average rating using Manual Query (fallback for aggregation issues)
    try {
      final snapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('isRated', isEqualTo: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        double totalRating = 0;
        int count = 0;
        
        for (var doc in snapshot.docs) {
          final data = doc.data();
          if (data['ratingGiven'] != null) {
            totalRating += (data['ratingGiven'] as num).toDouble();
            count++;
          }
        }

        if (count > 0) {
           final double newAverageRating = totalRating / count;
           // 3. Update the doctor's average rating
           await doctorRef.update({'rating': newAverageRating});
        }
      }
    } catch (e) {
      print("Error updating doctor rating: $e");
      // Optionally handle error
    }
  }

  Stream<List<Map<String, dynamic>>> getDoctorReviews(String doctorId) {
    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('isRated', isEqualTo: true)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'rating': data['ratingGiven'],
          'review': data['review'],
          'date': (data['date'] as Timestamp).toDate(),
        };
      }).toList();
    });
  }

  Future<void> cancelAppointment(
      String appointmentId, 
      String doctorId, 
      String patientId, 
      double price, 
      bool isPatient,
      String doctorEmail,
      String patientName,
      DateTime date
  ) async {
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

        // Logic for Patient Cancellation
        if (isPatient) {
          final refundAmount = price / 2;

          // 1. Refund 50% to User
           transaction.update(userRef, {
            'walletBalance': FieldValue.increment(refundAmount)
          });

          // Log Transaction for User
          final userTxnRef = userRef.collection('transactions').doc();
          transaction.set(userTxnRef, {
            'amount': refundAmount,
            'type': 'credit',
            'date': FieldValue.serverTimestamp(),
            'description': 'Refund: Cancellation (50%)',
          });

          // 2. Deduct 50% from Doctor
           transaction.update(doctorRef, {
            'wallet': FieldValue.increment(-refundAmount) // Deduct half
          });
          
          // Note: Doctor model might not have transactions collection setup in same way, 
          // or we can add it if needed. For now just updating wallet.

          // 3. Update Status
          transaction.update(appointmentRef, {'status': 'cancelled', 'cancelledBy': 'patient'});

          // Send Email to Doctor
          await EmailService().sendCancellationEmail(
            doctorEmail: doctorEmail,
            appointmentId: appointmentId,
            patientName: patientName,
            date: date.toString().split(' ')[0],
          );
        } else {
           // Logic for Doctor Cancellation (Full Refund) - Placeholder for now if needed here, 
           // but will be implemented in doctor app service primarily. 
           // However, if we share this service or logic:
           // refundAmount = price;
        }
      });
    } catch (e) {
      print("Error cancelling appointment: $e");
      rethrow;
    }
  }
}
