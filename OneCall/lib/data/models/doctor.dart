class Doctor {
  final String id;
  final String name;
  final String specialization;
  final List<String> concernId;
  final double rating;
  final String email;
  final String imageUrl;
  final int experience;
  final List<String> languages;
  final double phoneConsultationPrice;
  final double videoConsultationPrice;
  final Map<String, List<String>> availableSlots;

  Doctor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.concernId,
    required this.rating,
    required this.email,
    required this.imageUrl,
    required this.experience,
    required this.languages,
    required this.phoneConsultationPrice,
    required this.videoConsultationPrice,
    this.availableSlots = const {},
  });

  factory Doctor.fromMap(Map<String, dynamic> data, String id) {
    // Fallback logic: if new prices aren't set, use old 'price' or default to 0.0
    double oldPrice = (data['price'] ?? 0.0).toDouble();
    return Doctor(
      id: id,
      name: data['name'] ?? '',
      specialization: data['specialization'] ?? '',
      concernId: List<String>.from(data['concernId'] ?? []),
      rating: (data['rating'] ?? 0.0).toDouble(),
      email: data['email'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      experience: data['experience'] ?? 0,
      languages: List<String>.from(data['languages'] ?? []),
      phoneConsultationPrice: (data['phoneConsultationPrice'] ?? oldPrice).toDouble(),
      videoConsultationPrice: (data['videoConsultationPrice'] ?? oldPrice + 200).toDouble(), // Default video to be higher if not set
      availableSlots: Map<String, List<String>>.from(
        (data['availableSlots'] ?? {}).map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'specialization': specialization,
      'concernId': concernId,
      'rating': rating,
      'email': email,
      'imageUrl': imageUrl,
      'experience': experience,
      'languages': languages,
      'phoneConsultationPrice': phoneConsultationPrice,
      'videoConsultationPrice': videoConsultationPrice,
      'availableSlots': availableSlots,
    };
  }
}
