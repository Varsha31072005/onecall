import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecall_doctor/models/doctor_model.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._firebaseAuth, this._firestore);

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> registerDoctor({
    required String email,
    required String password,
    required String name,
    String phoneNumber = '',
  }) async {
    UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    User? user = userCredential.user;
    if (user != null) {
      // Create initial minimal doctor object
      final doctor = Doctor(
        id: user.uid,
        name: name,
        email: email,
        specialization: '',
        concernId: [],
        rating: 0.0,
        imageUrl: '',
        experience: 0,
        languages: [],
        about: '',
        videoConsultationPrice: 0.0,
        phoneConsultationPrice: 0.0,
        wallet: 0.0,
      );

      await _firestore.collection('doctors').doc(user.uid).set(doctor.toMap());
    }
  }

  Future<void> updateSchedule(Map<String, List<String>> availableSlots) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await _firestore.collection('doctors').doc(user.uid).update({
        'availableSlots': availableSlots,
      });
    }
  }

  Future<void> updateDoctorProfile({
    required String specialization,
    required int experience,
    required double videoConsultationPrice,
    required double phoneConsultationPrice,
    required List<String> languages,
    required List<String> concernId,
    required String about,
    String? imageUrl,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await _firestore.collection('doctors').doc(user.uid).update({
        'specialization': specialization,
        'experience': experience,
        'videoConsultationPrice': videoConsultationPrice,
        'phoneConsultationPrice': phoneConsultationPrice,
        'languages': languages,
        'concernId': concernId,
        'about': about,
        'imageUrl': imageUrl ?? '',
      });
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firebaseFirestoreProvider),
  );
});

final currentDoctorStreamProvider = StreamProvider<Doctor?>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value(null);
  
  return ref.watch(firebaseFirestoreProvider)
      .collection('doctors')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
        if (doc.exists && doc.data() != null) {
          return Doctor.fromMap(doc.data()!, doc.id);
        }
        return null;
      });
});
