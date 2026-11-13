// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'doctors_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$doctorsHash() => r'cb241588e39ea2ece6545b54bcb1f8dc06070850';

/// See also [doctors].
@ProviderFor(doctors)
final doctorsProvider = AutoDisposeFutureProvider<List<Doctor>>.internal(
  doctors,
  name: r'doctorsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$doctorsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DoctorsRef = AutoDisposeFutureProviderRef<List<Doctor>>;
String _$doctorStreamHash() => r'053548d7cbdbe1f028dc311d3104aab178c36c30';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [doctorStream].
@ProviderFor(doctorStream)
const doctorStreamProvider = DoctorStreamFamily();

/// See also [doctorStream].
class DoctorStreamFamily extends Family<AsyncValue<Doctor?>> {
  /// See also [doctorStream].
  const DoctorStreamFamily();

  /// See also [doctorStream].
  DoctorStreamProvider call(String id) {
    return DoctorStreamProvider(id);
  }

  @override
  DoctorStreamProvider getProviderOverride(
    covariant DoctorStreamProvider provider,
  ) {
    return call(provider.id);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'doctorStreamProvider';
}

/// See also [doctorStream].
class DoctorStreamProvider extends AutoDisposeStreamProvider<Doctor?> {
  /// See also [doctorStream].
  DoctorStreamProvider(String id)
    : this._internal(
        (ref) => doctorStream(ref as DoctorStreamRef, id),
        from: doctorStreamProvider,
        name: r'doctorStreamProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$doctorStreamHash,
        dependencies: DoctorStreamFamily._dependencies,
        allTransitiveDependencies:
            DoctorStreamFamily._allTransitiveDependencies,
        id: id,
      );

  DoctorStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    Stream<Doctor?> Function(DoctorStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DoctorStreamProvider._internal(
        (ref) => create(ref as DoctorStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<Doctor?> createElement() {
    return _DoctorStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DoctorStreamProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DoctorStreamRef on AutoDisposeStreamProviderRef<Doctor?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _DoctorStreamProviderElement
    extends AutoDisposeStreamProviderElement<Doctor?>
    with DoctorStreamRef {
  _DoctorStreamProviderElement(super.provider);

  @override
  String get id => (origin as DoctorStreamProvider).id;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
