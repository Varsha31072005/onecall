import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'navigation_provider.g.dart';

@riverpod
class Navigation extends _$Navigation {
  @override
  int build() {
    return 0;
  }

  void onchange(int index){
    state = index;
  }

}