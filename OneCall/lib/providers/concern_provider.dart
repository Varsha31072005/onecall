import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'concern_provider.g.dart';

@riverpod
class Concern extends _$Concern {
  @override
  String? build() {
    return null;
  }

  void selectConcern(String concernId){
    state = concernId;
  }

}