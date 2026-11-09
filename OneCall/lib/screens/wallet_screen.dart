import 'package:callone/app_styles/app_colors.dart';
import 'package:callone/data/models/transaction_model.dart';
import 'package:callone/services/auth_service.dart';
import 'package:callone/services/user_service.dart';
import 'package:callone/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  void _showAddMoneySheet(BuildContext context, WidgetRef ref, String uid, AppColors appColors) {
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
                    // Update state to refresh preset selection highlights
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
                                  color: isSelected ? appColors.primary : Colors.grey[600],
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appColors = ref.watch(appColorsProvider);
    final user = ref.watch(authServiceProvider).currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: appColors.background,
        appBar: const AppAppBar(name: "Wallet History"),
        body: const Center(child: Text("Please login to view wallet")),
      );
    }

    final transactionsStream = ref.watch(userServiceProvider).getUserTransactions(user.uid);
    // Fetch wallet balance from profile stream
    final userProfileAsync = ref.watch(userProfileProvider(user.uid));

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: const AppAppBar(name: "Wallet History"),
      body: Column(
        children: [
          // Balance Card
          Container(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              color: appColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Available Balance",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        userProfileAsync.when(
                          data: (snapshot) {
                            final data = snapshot.data() as Map<String, dynamic>?;
                            final balance = (data?['walletBalance'] ?? 0.0).toDouble();
                            return Row(
                              children: [
                                Text(
                                  "₹${balance.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Plus symbol beside wallet balance
                                GestureDetector(
                                  onTap: () => _showAddMoneySheet(context, ref, user.uid, appColors),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                          loading: () => const Text("...", style: TextStyle(color: Colors.white, fontSize: 32)),
                          error: (_, __) => const Text("Error", style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showAddMoneySheet(context, ref, user.uid, appColors),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text("Add Money"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: appColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 0,
                          ),
                        )
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: Container(
               decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  )
                ]
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: StreamBuilder<List<TransactionModel>>(
                  stream: transactionsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                
                    final transactions = snapshot.data ?? [];
                
                    if (transactions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text("No transactions yet", style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      );
                    }
                
                    return ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: transactions.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final txn = transactions[index];
                        final isCredit = txn.type == TransactionType.credit;
                
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isCredit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            child: Icon(
                              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isCredit ? Colors.green : Colors.red,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            txn.description,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: appColors.text,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat('dd MMM yyyy, hh:mm a').format(txn.date),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            "${isCredit ? '+' : '-'} ₹${txn.amount.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCredit ? Colors.green : Colors.red,
                              fontSize: 16,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
