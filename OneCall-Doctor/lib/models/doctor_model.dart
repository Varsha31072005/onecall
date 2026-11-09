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
  final String about;
  final double videoConsultationPrice;
  final double phoneConsultationPrice;
  final double wallet;
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
    required this.about,
    required this.videoConsultationPrice,
    required this.phoneConsultationPrice,
    required this.wallet,
    this.availableSlots = const {},
  });

  factory Doctor.fromMap(Map<String, dynamic> data, String id) {
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
      about: data['about'] ?? '',
      videoConsultationPrice: (data['videoConsultationPrice'] ?? data['price'] ?? 0.0).toDouble(),
      phoneConsultationPrice: (data['phoneConsultationPrice'] ?? data['price'] ?? 0.0).toDouble(),
      wallet: (data['wallet'] ?? 0.0).toDouble(),
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
      'about': about,
      'videoConsultationPrice': videoConsultationPrice,
      'phoneConsultationPrice': phoneConsultationPrice,
      'wallet': wallet,
      'availableSlots': availableSlots,
    };
  }
}
