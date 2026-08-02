class AppVersion {
  /// App version passed via --dart-define=APP_VERSION=... (defaults to 'v0.0.0-dev')
  static const String current = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'v0.0.0-dev',
  );

  /// Git commit hash passed via --dart-define=GIT_HASH=... (defaults to 'local')
  static const String gitHash = String.fromEnvironment(
    'GIT_HASH',
    defaultValue: 'local',
  );

  /// Human-readable version string display (e.g. "v0.5.10 (d87599f)" or "v0.0.0-dev")
  static String get display {
    if (gitHash == 'local' || gitHash.isEmpty) {
      return current;
    }
    final shortHash = gitHash.length > 7 ? gitHash.substring(0, 7) : gitHash;
    return '$current ($shortHash)';
  }
}
