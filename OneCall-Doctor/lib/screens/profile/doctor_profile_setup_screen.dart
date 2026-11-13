import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecall_doctor/providers/auth_provider.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../../widget_tree.dart';
import 'package:onecall_doctor/models/concern.dart';
import 'package:onecall_doctor/models/doctor_model.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DoctorProfileSetupScreen extends ConsumerStatefulWidget {
  final Doctor? doctor;
  const DoctorProfileSetupScreen({super.key, this.doctor});

  @override
  ConsumerState<DoctorProfileSetupScreen> createState() => _DoctorProfileSetupScreenState();
}

class _DoctorProfileSetupScreenState extends ConsumerState<DoctorProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _specializationController;
  late TextEditingController _experienceController;
  late TextEditingController _videoPriceController;
  late TextEditingController _phonePriceController;
  late TextEditingController _languagesController;
  late TextEditingController _aboutController;
  
  List<String> _selectedConcernIds = [];
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final doctor = widget.doctor;
    _specializationController = TextEditingController(text: doctor?.specialization ?? '');
    _experienceController = TextEditingController(text: doctor?.experience.toString() == '0' ? '' : doctor?.experience.toString());
    _videoPriceController = TextEditingController(text: doctor?.videoConsultationPrice.toString() == '0.0' ? '' : doctor?.videoConsultationPrice.toString());
    _phonePriceController = TextEditingController(text: doctor?.phoneConsultationPrice.toString() == '0.0' ? '' : doctor?.phoneConsultationPrice.toString());
    _languagesController = TextEditingController(text: doctor?.languages.join(', ') ?? '');
    _aboutController = TextEditingController(text: doctor?.about ?? '');
    _selectedConcernIds = doctor?.concernId ?? [];
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    setState(() {
                      _imageFile = File(image.path);
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await ImagePicker().pickImage(source: ImageSource.camera);
                  if (image != null) {
                    setState(() {
                      _imageFile = File(image.path);
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _uploadImage(String userId) async {
    if (_imageFile == null) return widget.doctor?.imageUrl;
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('doctor_profile_images')
          .child('$userId.jpg');
      await storageRef.putFile(_imageFile!);
      return await storageRef.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading image: $e");
      return widget.doctor?.imageUrl;
    }
  }

  @override
  void dispose() {
    _specializationController.dispose();
    _experienceController.dispose();
    _videoPriceController.dispose();
    _phonePriceController.dispose();
    _languagesController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  void _showMultiSelectConcerns() async {
    final List<String> tempSelectedConcerns = List.from(_selectedConcernIds);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Select Concerns"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: concerns.length,
                  itemBuilder: (context, index) {
                    final concern = concerns[index];
                    final isSelected = tempSelectedConcerns.contains(concern.id);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Row(
                        children: [
                          Icon(concern.icon, size: 20, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(concern.title),
                        ],
                      ),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            tempSelectedConcerns.add(concern.id);
                          } else {
                            tempSelectedConcerns.remove(concern.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    this.setState(() {
                      _selectedConcernIds = List.from(tempSelectedConcerns);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Confirm"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedConcernIds.isEmpty) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.error(
            message: "Please select at least one area of concern",
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final user = ref.read(firebaseAuthProvider).currentUser;
        String? imageUrl;
        if (user != null) {
          imageUrl = await _uploadImage(user.uid);
        }

        final languages = _languagesController.text.split(',').map((e) => e.trim()).toList();

        await ref.read(authRepositoryProvider).updateDoctorProfile(
          specialization: _specializationController.text.trim(),
          experience: int.tryParse(_experienceController.text.trim()) ?? 0,
          videoConsultationPrice: double.tryParse(_videoPriceController.text.trim()) ?? 0.0,
          phoneConsultationPrice: double.tryParse(_phonePriceController.text.trim()) ?? 0.0,
          languages: languages,
          concernId: _selectedConcernIds,
          about: _aboutController.text.trim(),
          imageUrl: imageUrl, 
        );

        if (mounted) {
           Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const WidgetTree()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          showTopSnackBar(
            Overlay.of(context),
            CustomSnackBar.error(
              message: "Failed to update profile: ${e.toString()}",
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageFile != null || (widget.doctor?.imageUrl != null && widget.doctor!.imageUrl.isNotEmpty);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doctor == null ? "Complete Your Profile" : "Edit Profile"),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Professional Details",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Please fill in your professional details to get verified.",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _imageFile != null 
                              ? FileImage(_imageFile!) 
                              : (widget.doctor?.imageUrl != null && widget.doctor!.imageUrl.isNotEmpty
                                  ? NetworkImage(widget.doctor!.imageUrl) as ImageProvider
                                  : null),
                          child: !hasImage
                              ? const Icon(Icons.person, size: 50, color: Colors.grey)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xff3A643B),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Specialization
                TextFormField(
                  controller: _specializationController,
                  decoration: InputDecoration(
                    labelText: "Specialization",
                    hintText: "e.g. Cardiologist, Dentist",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) => value == null || value.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),

                // Experience
                TextFormField(
                  controller: _experienceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Years of Experience",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) => value == null || value.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),

                // Video Price
                TextFormField(
                  controller: _videoPriceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Video Consultation Price (₹)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) => value == null || value.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),

                // Phone Price
                TextFormField(
                  controller: _phonePriceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Phone Consultation Price (₹)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) => value == null || value.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),

                // Languages
                TextFormField(
                  controller: _languagesController,
                  decoration: InputDecoration(
                    labelText: "Languages (comma separated)",
                    hintText: "English, Hindi, Telugu",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) => value == null || value.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),

                // About
                TextFormField(
                  controller: _aboutController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: "About",
                    hintText: "Tell us about yourself...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) => value == null || value.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),
                
                // Concerns Selection
                InkWell(
                  onTap: _showMultiSelectConcerns,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: "Areas of Concern",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _selectedConcernIds.isEmpty
                        ? const Text("Select concerns", style: TextStyle(color: Colors.grey))
                        : Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: _selectedConcernIds.map((id) {
                              final concern = concerns.firstWhere(
                                (c) => c.id == id,
                                orElse: () => Concern(id: id, title: id, icon: Icons.help),
                              );
                              return Chip(
                                label: Text(concern.title),
                                avatar: Icon(concern.icon, size: 16),
                                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                onDeleted: () {
                                  setState(() {
                                    _selectedConcernIds.remove(id);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff3A643B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(widget.doctor == null ? "Complete Setup" : "Save Changes"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
