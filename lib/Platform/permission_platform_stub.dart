// Stub for permission_handler on web
class Permission {
  static final sms = Permission._();
  const Permission._();
  Future<PermissionStatus> get status async => PermissionStatus.granted;
  Future<PermissionStatus> request() async => PermissionStatus.granted;
}

class PermissionStatus {
  static final granted = PermissionStatus._();
  static final denied = PermissionStatus._();
  static final permanentlyDenied = PermissionStatus._();
  const PermissionStatus._();
  bool get isGranted => this == granted;
  bool get isDenied => this == denied;
  bool get isPermanentlyDenied => this == permanentlyDenied;
}

Future<bool> openAppSettings() async => true;
