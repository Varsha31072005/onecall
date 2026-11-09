import 'package:flutter/material.dart';

class Concern {
  final String id;
  final String title;
  final IconData icon;

  const Concern({
    required this.id,
    required this.title,
    required this.icon,
  });
}

final List<Concern> concerns = [
  Concern(id: 'fever', title: 'Fever', icon: Icons.thermostat),
  Concern(id: 'back_pain', title: 'Back Pain', icon: Icons.personal_injury),
  Concern(id: 'depression', title: 'Depression', icon: Icons.psychology),
  Concern(id: 'obesity', title: 'Obesity', icon: Icons.accessibility_new),
  Concern(id: 'allergies', title: 'Allergies', icon: Icons.grain),
  Concern(id: 'migraine', title: 'Migraine', icon: Icons.healing),
  Concern(id: 'asthma', title: 'Asthma', icon: Icons.air),
  Concern(id: 'anxiety', title: 'Anxiety', icon: Icons.chat_bubble_outline),
  Concern(id: 'diabetes', title: 'Diabetes', icon: Icons.monitor_heart),
  Concern(id: 'hypertension', title: 'Hypertension', icon: Icons.trending_up),
  Concern(id: 'rubella', title: 'Rubella', icon: Icons.sick),
  Concern(id: 'hypothermia', title: 'Hypothermia', icon: Icons.ac_unit),
  Concern(id: 'frostbite', title: 'Frostbite', icon: Icons.ac_unit_outlined),
  Concern(id: 'insomnia', title: 'Insomnia', icon: Icons.nightlight_round),
  Concern(id: 'arthritis', title: 'Arthritis', icon: Icons.accessibility),
];
