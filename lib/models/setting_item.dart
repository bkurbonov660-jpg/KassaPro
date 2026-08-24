enum PermissionType {
  camera,
  microphone,
  contacts,
  storage,
  notifications,
  location,
  wifi,
  bluetooth,
}

class PermissionItem {
  final PermissionType type;
  final String title;
  final String description;
  bool granted;

  PermissionItem({
    required this.type,
    required this.title,
    required this.description,
    this.granted = false,
  });
}
