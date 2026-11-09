import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/doctor.dart';

part 'selected_doctor_provider.g.dart';

@Riverpod(keepAlive: true)
class SelectedDoctor extends _$SelectedDoctor {
  @override
  Doctor? build() {
    return null;
  }

  void selectDoctor(Doctor doctor) {
    state = doctor;
  }
}
