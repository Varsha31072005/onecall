import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/transaction_model.dart';

final userServiceProvider = Provider<UserService>((ref) => UserService());

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveUserProfile({
    required String uid,
    required String name,
    required String gender,
    required int age,
    required double height,
    required double weight,
  }) async {
    final docRef = _firestore.collection('users').doc(uid);
    final doc = await docRef.get();
    
    Map<String, dynamic> data = {
      'name': name,
      'gender': gender,
      'age': age,
      'height': height,
      'weight': weight,
      'profileCompleted': true,
    };

    // Initialize wallet balance if it doesn't exist
    if (!doc.exists || (doc.data() as Map<String, dynamic>?)?['walletBalance'] == null) {
      data['walletBalance'] = 110.0;
    }

    await docRef.set(data, SetOptions(merge: true));
  }

  Future<void> rechargeWallet(String uid, double amount) async {
    final docRef = _firestore.collection('users').doc(uid);
    await docRef.update({
      'walletBalance': FieldValue.increment(amount),
    });

    // Log Transaction
    final transactionRef = docRef.collection('transactions').doc();
    await transactionRef.set({
      'amount': amount,
      'type': 'credit',
      'date': FieldValue.serverTimestamp(),
      'description': 'Wallet Recharge',
    });
  }

  Future<void> initializeUserIfNeeded(String uid) async {
    final docRef = _firestore.collection('users').doc(uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'walletBalance': 110.0,
        'profileCompleted': false,
      });

    }
  }

  Stream<List<TransactionModel>> getUserTransactions(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TransactionModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<DocumentSnapshot> getUserProfile(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }

  Stream<DocumentSnapshot> watchUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }
}

final userProfileProvider = StreamProvider.family<DocumentSnapshot, String>((ref, uid) {
  return ref.watch(userServiceProvider).watchUserProfile(uid);
});
