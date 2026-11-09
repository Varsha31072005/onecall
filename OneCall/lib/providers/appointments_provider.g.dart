// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointments_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userAppointmentsHash() => r'9f7c126ffa33fabe19be487af70b886ac3d3829b';

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

/// See also [userAppointments].
@ProviderFor(userAppointments)
const userAppointmentsProvider = UserAppointmentsFamily();

/// See also [userAppointments].
class UserAppointmentsFamily
    extends Family<AsyncValue<List<AppointmentModel>>> {
  /// See also [userAppointments].
  const UserAppointmentsFamily();

  /// See also [userAppointments].
  UserAppointmentsProvider call(String userId) {
    return UserAppointmentsProvider(userId);
  }

  @override
  UserAppointmentsProvider getProviderOverride(
    covariant UserAppointmentsProvider provider,
  ) {
    return call(provider.userId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'userAppointmentsProvider';
}

/// See also [userAppointments].
class UserAppointmentsProvider
    extends AutoDisposeStreamProvider<List<AppointmentModel>> {
  /// See also [userAppointments].
  UserAppointmentsProvider(String userId)
    : this._internal(
        (ref) => userAppointments(ref as UserAppointmentsRef, userId),
        from: userAppointmentsProvider,
        name: r'userAppointmentsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$userAppointmentsHash,
        dependencies: UserAppointmentsFamily._dependencies,
        allTransitiveDependencies:
            UserAppointmentsFamily._allTransitiveDependencies,
        userId: userId,
      );

  UserAppointmentsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    Stream<List<AppointmentModel>> Function(UserAppointmentsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserAppointmentsProvider._internal(
        (ref) => create(ref as UserAppointmentsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<AppointmentModel>> createElement() {
    return _UserAppointmentsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserAppointmentsProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserAppointmentsRef
    on AutoDisposeStreamProviderRef<List<AppointmentModel>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserAppointmentsProviderElement
    extends AutoDisposeStreamProviderElement<List<AppointmentModel>>
    with UserAppointmentsRef {
  _UserAppointmentsProviderElement(super.provider);

  @override
  String get userId => (origin as UserAppointmentsProvider).userId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
