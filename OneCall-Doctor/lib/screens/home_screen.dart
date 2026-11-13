import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecall_doctor/app_styles/app_colors.dart';
import 'package:onecall_doctor/models/appointment_model.dart';
import 'package:onecall_doctor/models/doctor_model.dart';
import 'package:onecall_doctor/providers/appointment_provider.dart';
import 'package:onecall_doctor/providers/auth_provider.dart';
import 'package:onecall_doctor/widgets/app_bar.dart';
import 'package:onecall_doctor/services/notification_service.dart';

enum AnalyticsOption {
  today,
  week,
  month,
  total,
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  AnalyticsOption _selectedOption = AnalyticsOption.today;

  @override
  Widget build(BuildContext context) {
    final doctorAsyncValue = ref.watch(currentDoctorStreamProvider);
    final appointmentsAsyncValue = ref.watch(appointmentsStreamProvider);
    
    // Listen for cancellations
    ref.listen<AsyncValue<List<Appointment>>>(appointmentsStreamProvider, (previous, next) {
      next.whenData((newAppointments) {
        previous?.whenData((oldAppointments) {
           for (var newApp in newAppointments) {
              final oldApp = oldAppointments.firstWhere((a) => a.id == newApp.id, orElse: () => newApp);
              
              if (oldApp.status != 'cancelled' && newApp.status == 'cancelled' && newApp.cancelledBy == 'patient') {
                  NotificationService().showNotification(
                      id: newApp.id.hashCode,
                      title: 'Appointment Cancelled',
                      body: 'Patient has cancelled the appointment on ${newApp.date.toString().split(' ')[0]} at ${newApp.time}',
                  );
              }
           }
        });
      });
    });

    return Scaffold(
      appBar: AppAppBar(
        name: "HOME",
      ),
      body: doctorAsyncValue.when(
        data: (doctor) {
          if (doctor == null) {
            return const Center(child: Text("Doctor data not found."));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDoctorHeader(doctor),
                const SizedBox(height: 24),
                // Analytics Section
                const Text(
                  "Analytics",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                appointmentsAsyncValue.when(
                  data: (appointments) => _buildAnalyticsSection(appointments),
                  loading: () => const Center(
                      child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  )),
                  error: (e, s) => Text("Error loading analytics: $e",
                      style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildAnalyticsSection(List<Appointment> appointments) {
    final colors = ref.watch(appColorsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Helper to check if a date is in the current week
    bool isCurrentWeek(DateTime date) {
      final startOfWeek = today.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek
          .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      return date.isAfter(startOfWeek.subtract(const Duration(milliseconds: 1))) &&
          date.isBefore(endOfWeek.add(const Duration(milliseconds: 1)));
    }

    // Basic stats for the cards (using "This Week" as per previous design or potentially updated?)
    // The prompt asks for Selector and Charts "below to the overview card".
    // But the existing code had "Overview" BELOW the interactive cards.
    // I will preserve the Interactive Cards (Weekly stats) as they were.
    
    final weeklyAppointments =
        appointments.where((a) => isCurrentWeek(a.createdAt)).toList();

    final weeklyEarnings = weeklyAppointments
        .fold(0.0, (sum, a) {
          if (a.status == 'completed' || a.status == 'upcoming' || a.status == 'accepted' || a.status == 'pending') return sum + a.price;
          if (a.status == 'cancelled' && a.cancelledBy == 'patient') return sum + (a.price * 0.5);
          return sum; // cancelled by doctor
        });

    // Existing chart data for Overview
    int total = appointments.length;
    int completed = appointments.where((a) => a.status == 'completed').length;
    int cancelled = appointments.where((a) => a.status == 'cancelled').length; // Added
    int pending = appointments
        .where((a) =>
            a.status == 'upcoming' ||
            a.status == 'accepted' ||
            a.status == 'pending')
        .length;

    return Column(
      children: [
        // Interactive Analytics Cards
        Row(
          children: [
            Expanded(
              child: _buildInteractiveCard(
                title: "Earnings",
                value: "${weeklyEarnings.toStringAsFixed(0)}",
                subtitle: "This Week",
                icon: Icons.account_balance_wallet,
                color: Colors.green,
                onTap: () {},
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInteractiveCard(
                title: "Appointments",
                value: "${weeklyAppointments.length}",
                subtitle: "This Week",
                icon: Icons.calendar_month,
                color: Colors.blue,
                onTap: () {},
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Text(
          "Overview",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Overview Card (Circular Chart)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Circular Chart
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: AppointmentChartPainter(
                    completed: completed,
                    pending: pending,
                    cancelled: cancelled, // Added
                    total: total,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "$total",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Text(
                          "Total",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(
                      color: const Color(0xFF4CAF50), // Green for Completed
                      label: "Completed",
                      count: completed,
                    ),
                    const SizedBox(height: 12),
                    _buildLegendItem(
                      color: const Color(0xFFFF9800), // Orange for Pending
                      label: "Pending",
                      count: pending,
                    ),
                    const SizedBox(height: 12),
                    _buildLegendItem(
                      color: Colors.red, // Red for Cancelled
                      label: "Cancelled",
                      count: cancelled,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
        
        // --- NEW ANALYTICS SECTION ---
        _buildOptionSelector(colors),
        const SizedBox(height: 24),
        
        _buildBarGraphs(appointments, colors),
      ],
    );
  }

  Widget _buildOptionSelector(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: AnalyticsOption.values.map((option) {
              final isSelected = _selectedOption == option;
              final width = constraints.maxWidth / 4;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedOption = option;
                  });
                },
                child: Container(
                  width: width,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? colors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _getOptionTitle(option),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }
      ),
    );
  }

  String _getOptionTitle(AnalyticsOption option) {
    switch (option) {
      case AnalyticsOption.total:
        return 'Total';
      case AnalyticsOption.month:
        return 'Month';
      case AnalyticsOption.week:
        return 'Week';
      case AnalyticsOption.today:
        return 'Today';
    }
  }

  Widget _buildBarGraphs(List<Appointment> appointments, AppColors colors) {
    // Process Data
    final data = _processChartData(appointments);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Appointments Covered",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          width: double.infinity,
          child: _buildLineChart(
            data: data.appointmentCounts,
            labels: data.labels,
            color: colors.primary,
          ),
        ),
        
        const SizedBox(height: 32),
        
        const Text(
          "Money Earned",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          width: double.infinity,
          child: _buildLineChart(
             data: data.earnings,
            labels: data.labels,
             color: Colors.blue, 
          ),
        ),
      ],
    );
  }


  // Custom Class to hold chart data
  _ChartData _processChartData(List<Appointment> appointments) {
    final now = DateTime.now();
    List<double> appointmentCounts = [];
    List<double> earnings = [];
    List<String> labels = [];

    if (_selectedOption == AnalyticsOption.today) {
      // 0-23 Hours, grouped by 4 hours blocks for simpler view or just hours
      // Let's do 4-hour blocks: 0-4, 4-8, 8-12, 12-16, 16-20, 20-24 => 6 bars
      // Or just All hours? 24 bars is too dense.
      // Let's do 6 blocks of 4 hours.
      List<int> blocks = List.filled(6, 0); // appointments
      List<double> earnBlocks = List.filled(6, 0.0);
      
      final todayAppts = appointments.where((a) => 
        a.createdAt.year == now.year && 
        a.createdAt.month == now.month && 
        a.createdAt.day == now.day
      );
      
      for (var a in todayAppts) {
        int hour = a.createdAt.hour;
        int blockIndex = hour ~/ 4; // 0..5
        if(blockIndex < 6) {
          blocks[blockIndex]++;
          
          double amount = 0.0;
          if (a.status == 'completed' || a.status == 'upcoming' || a.status == 'accepted' || a.status == 'pending') amount = a.price;
          else if (a.status == 'cancelled' && a.cancelledBy == 'patient') amount = a.price * 0.5;
          
          earnBlocks[blockIndex] += amount;
        }
      }
      
      appointmentCounts = blocks.map((e) => e.toDouble()).toList();
      earnings = earnBlocks;
      labels = ["0-4", "4-8", "8-12", "12-16", "16-20", "20-24"];
      
    } else if (_selectedOption == AnalyticsOption.week) {
      // Current Week (Mon-Sun)
      List<int> days = List.filled(7, 0);
      List<double> earnDays = List.filled(7, 0.0);
      
      // Calculate start of week (Monday)
      // 1 = Mon, 7 = Sun
      int currentWeekday = now.weekday; 
      DateTime startOfWeek = now.subtract(Duration(days: currentWeekday - 1));
      startOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day); // midnight

      // Filter for this week
      final weekAppts = appointments.where((a) {
         return a.createdAt.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
                a.createdAt.isBefore(startOfWeek.add(const Duration(days: 7)));
      });

      for (var a in weekAppts) {
        // Find difference in days from startOfWeek
        int dayIndex = a.createdAt.difference(startOfWeek).inDays;
        if (dayIndex >= 0 && dayIndex < 7) {
          days[dayIndex]++;
          
          double amount = 0.0;
          if (a.status == 'completed' || a.status == 'upcoming' || a.status == 'accepted' || a.status == 'pending') amount = a.price;
          else if (a.status == 'cancelled' && a.cancelledBy == 'patient') amount = a.price * 0.5;
          
          earnDays[dayIndex] += amount;
        }
      }
      
      appointmentCounts = days.map((e) => e.toDouble()).toList();
      earnings = earnDays;
      labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

    } else if (_selectedOption == AnalyticsOption.month) {
      // ... (Month Logic)
       List<int> weeks = List.filled(4, 0);
       List<double> earnWeeks = List.filled(4, 0.0);
       
       final monthAppts = appointments.where((a) => 
        a.createdAt.year == now.year && 
        a.createdAt.month == now.month
       );

       for (var a in monthAppts) {
         int day = a.createdAt.day;
         int weekIndex = (day - 1) ~/ 7; // 0..4
         if (weekIndex > 3) weekIndex = 3; // grouping rest into 4th bar
         
         weeks[weekIndex]++;
         
          double amount = 0.0;
          if (a.status == 'completed' || a.status == 'upcoming' || a.status == 'accepted' || a.status == 'pending') amount = a.price;
          else if (a.status == 'cancelled' && a.cancelledBy == 'patient') amount = a.price * 0.5;

          earnWeeks[weekIndex] += amount;
       }
       
       appointmentCounts = weeks.map((e) => e.toDouble()).toList();
       earnings = earnWeeks;
       labels = ["W1", "W2", "W3", "W4+"];

    } else {
      // Total (Yearly)
      List<int> months = List.filled(12, 0);
      List<double> earnMonths = List.filled(12, 0.0);
      
      final totalAppts = appointments.where((a) => a.createdAt.year == now.year); // Current Year
      
      for (var a in totalAppts) {
         int monthIndex = a.createdAt.month - 1; // 0..11
         months[monthIndex]++;
         
          double amount = 0.0;
          if (a.status == 'completed' || a.status == 'upcoming' || a.status == 'accepted' || a.status == 'pending') amount = a.price;
          else if (a.status == 'cancelled' && a.cancelledBy == 'patient') amount = a.price * 0.5;

          earnMonths[monthIndex] += amount;
      }
      
      appointmentCounts = months.map((e) => e.toDouble()).toList();
      earnings = earnMonths;
      labels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    }

    return _ChartData(appointmentCounts, earnings, labels);
  }

  Widget _buildLineChart({
    required List<double> data,
    required List<String> labels,
    required Color color,
  }) {
    // Find max Y for scaling
    double maxY = data.isEmpty ? 10 : data.reduce(max);
    if (maxY == 0) maxY = 10;
    maxY = maxY * 1.2; // padding

    // Prepare Spots
    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i]));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
             getTooltipColor: (_) => Colors.blueGrey,
             getTooltipItems: (touchedSpots) {
               return touchedSpots.map((spot) {
                 return LineTooltipItem(
                   spot.y.toInt().toString(),
                   const TextStyle(
                     color: Colors.white,
                     fontWeight: FontWeight.bold,
                   ),
                 );
               }).toList();
             },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index < 0 || index >= labels.length) return const SizedBox();
                // For Total view with 12 items, skip some labels if tight
                if (labels.length > 7 && index % 2 != 0) return const SizedBox(); 
                
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    labels[index],
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                 // return compact values
                 if (value == 0) return const Text('0', style: TextStyle(color: Colors.grey, fontSize: 10));
                 if (value > 1000) return Text('${(value/1000).toStringAsFixed(1)}k', style: const TextStyle(color: Colors.grey, fontSize: 10));
                 return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5, // ~5 grid lines
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: false,
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3, // Slim line
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: color,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1), // Gradient fill effect or solid light
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.grey.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(
      {required Color color, required String label, required int count}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        Text(
          "$count",
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorHeader(Doctor doctor) {
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage: doctor.imageUrl.isNotEmpty
              ? NetworkImage(doctor.imageUrl)
              : null,
          child: doctor.imageUrl.isEmpty
              ? const Icon(Icons.person, size: 40)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      "Dr. ${doctor.name}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber.shade800),
                        const SizedBox(width: 4),
                        Text(
                          doctor.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800, 
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                doctor.specialization,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AppointmentChartPainter extends CustomPainter {
  final int completed;
  final int pending;
  final int cancelled; // Added
  final int total;

  AppointmentChartPainter({
    required this.completed,
    required this.pending,
    required this.cancelled, // Added
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final strokeWidth = 12.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw background circle (if total is 0 or just as a track)
    paint.color = Colors.grey.shade200;
    canvas.drawCircle(center, radius - strokeWidth / 2, paint);

    if (total == 0) return;

    double startAngle = -pi / 2; // Start from top

    // Draw Pending Arc
    if (pending > 0) {
      final sweepAngle = (pending / total) * 2 * pi;
      paint.color = const Color(0xFFFF9800); // Orange
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    // Draw Cancelled Arc
    if (cancelled > 0) {
      final sweepAngle = (cancelled / total) * 2 * pi;
      paint.color = Colors.red; // Red
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    // Draw Completed Arc
    if (completed > 0) {
      final sweepAngle = (completed / total) * 2 * pi;
      paint.color = const Color(0xFF4CAF50); // Green
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant AppointmentChartPainter oldDelegate) {
    return oldDelegate.completed != completed ||
        oldDelegate.pending != pending ||
        oldDelegate.cancelled != cancelled ||
        oldDelegate.total != total;
  }
}

class _ChartData {
  final List<double> appointmentCounts;
  final List<double> earnings;
  final List<String> labels;

  _ChartData(this.appointmentCounts, this.earnings, this.labels);
}
