import 'package:callone/app_styles/app_colors.dart';
import 'package:callone/services/auth_service.dart';
import 'package:callone/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../widgets/app_bar.dart';
import 'wallet_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String _selectedGender = 'Male';
  bool _isLoading = false;
  bool _isInitialized = false;
  double _walletBalance = 0.0;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _loadExistingData(Map<String, dynamic>? data) {
    if (data != null) {
      if (!_isInitialized) {
        _nameController.text = data['name']?.toString() ?? '';
        _ageController.text = data['age']?.toString() ?? '';
        _heightController.text = data['height']?.toString() ?? '';
        _weightController.text = data['weight']?.toString() ?? '';
        _selectedGender = data['gender']?.toString() ?? 'Male';
        _isInitialized = true;
      }
      _walletBalance = (data['walletBalance'] ?? 0.0).toDouble();
    }
  }

  void _showAddMoneySheet(BuildContext context, String uid, AppColors appColors) {
    final TextEditingController amountController = TextEditingController();
    final List<int> presets = [500, 1000, 1200, 1500];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Add Money",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: appColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Amount must be between ₹500 and ₹10,000",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    setModalState(() {});
                  },
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: "Enter Amount",
                    prefixText: "₹ ",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: presets.map((amount) {
                    final bool isSelected = amountController.text == amount.toString();
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              amountController.text = amount.toString();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? appColors.primary.withOpacity(0.1) : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? appColors.primary : appColors.primary.withOpacity(0.3),
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "₹$amount",
                                style: TextStyle(
                                  color: appColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amountStr = amountController.text.trim();
                      if (amountStr.isEmpty) {
                        showTopSnackBar(
                          Overlay.of(context),
                          const CustomSnackBar.error(message: "Please enter an amount"),
                        );
                        return;
                      }
                      
                      final amount = double.tryParse(amountStr);
                      if (amount == null) {
                        showTopSnackBar(
                          Overlay.of(context),
                          const CustomSnackBar.error(message: "Please enter a valid amount"),
                        );
                        return;
                      }

                      if (amount < 500) {
                        showTopSnackBar(
                          Overlay.of(context),
                          const CustomSnackBar.error(message: "Minimum recharge amount is ₹500"),
                        );
                        return;
                      }

                      if (amount > 10000) {
                        showTopSnackBar(
                          Overlay.of(context),
                          const CustomSnackBar.error(message: "Maximum recharge amount is ₹10,000"),
                        );
                        return;
                      }

                      try {
                        await ref.read(userServiceProvider).rechargeWallet(uid, amount);
                        if (context.mounted) {
                          Navigator.pop(context);
                          showTopSnackBar(
                            Overlay.of(context),
                            CustomSnackBar.success(message: "₹$amount added to your wallet!"),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showTopSnackBar(
                            Overlay.of(context),
                            CustomSnackBar.error(message: "Failed to add money: $e"),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Proceed to Pay",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _saveProfile() async {
    if (_nameController.text.isEmpty ||
        _ageController.text.isEmpty ||
        _heightController.text.isEmpty ||
        _weightController.text.isEmpty) {
      showTopSnackBar(
        Overlay.of(context),
        const CustomSnackBar.error(message: "Please fill all details"),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user != null) {
        await ref.read(userServiceProvider).saveUserProfile(
          uid: user.uid,
          name: _nameController.text.trim(),
          gender: _selectedGender,
          age: int.parse(_ageController.text.trim()),
          height: double.parse(_heightController.text.trim()),
          weight: double.parse(_weightController.text.trim()),
        );
        if (mounted) {
           showTopSnackBar(
            Overlay.of(context),
            const CustomSnackBar.success(message: "Profile updated successfully"),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          CustomSnackBar.error(message: e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = ref.watch(appColorsProvider);
    final user = ref.watch(authServiceProvider).currentUser;
    
    if (user != null) {
      final profileState = ref.watch(userProfileProvider(user.uid));
      profileState.whenData((snapshot) {
        final data = snapshot.data() as Map<String, dynamic>?;
        _loadExistingData(data);
      });
    }

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppAppBar(name: 'PROFILE',),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Wallet Card
                  Card(
                    elevation: 0,
                    color: appColors.primary.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(45),
                      side: BorderSide(color: appColors.primary.withOpacity(0.2)),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const WalletScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(45),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: FittedBox(
                          child: Row(
                            children: [
                            CircleAvatar(
                              backgroundColor: appColors.primary,
                              child: const Icon(Icons.account_balance_wallet, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Wallet Balance",
                                  style: TextStyle(
                                    color: appColors.text.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      "₹${_walletBalance.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        color: appColors.text,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () {
                                        if (user != null) {
                                          _showAddMoneySheet(context, user.uid, appColors);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: appColors.primary.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          color: appColors.primary,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Name",
                      prefixIcon: Icon(Icons.person_outline, color: appColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    style: TextStyle(color: appColors.text),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: InputDecoration(
                      labelText: "Gender",
                      prefixIcon: Icon(Icons.people_outline, color: appColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    style: TextStyle(color: appColors.text),
                    items: ['Male', 'Female', 'Others']
                        .map((label) => DropdownMenuItem(
                              value: label,
                              child: Text(label, style: TextStyle(color: appColors.text),),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Age",
                      prefixIcon: Icon(Icons.calendar_today_outlined, color: appColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    style: TextStyle(color: appColors.text),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Height (cm)",
                            prefixIcon: Icon(Icons.height, color: appColors.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          style: TextStyle(color: appColors.text),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Weight (kg)",
                            prefixIcon: Icon(Icons.monitor_weight_outlined, color: appColors.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          style: TextStyle(color: appColors.text),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Save Changes", style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => ref.read(authServiceProvider).signOut(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: const Text("Logout", style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
