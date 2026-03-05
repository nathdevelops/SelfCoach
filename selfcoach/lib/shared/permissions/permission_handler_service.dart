import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

// Convenient aliases
typedef Permission = ph.Permission;
typedef PermissionStatus = ph.PermissionStatus;

/// Result returned after requesting the set of permissions SelfCoach needs.
enum PermissionResult {
  granted,
  denied,
  permanentlyDenied,
}

/// Thin wrapper around `permission_handler` that requests all permissions
/// required by SelfCoach and surfaces a clear error state when denied (PRD §2.4).
class PermissionHandlerService {
  /// Requests camera, microphone, and storage permissions appropriate for
  /// the current platform. Returns the combined result.
  Future<PermissionResult> requestAll() async {
    final permissions = _requiredPermissions();
    final statuses = await permissions.request();
    return _evaluate(statuses);
  }

  /// Re-checks whether all permissions are currently granted without
  /// triggering the system dialog again.
  Future<PermissionResult> checkAll() async {
    final permissions = _requiredPermissions();
    bool allGranted = true;
    bool anyPermanentlyDenied = false;
    for (final p in permissions) {
      final status = await p.status;
      if (status.isPermanentlyDenied) {
        anyPermanentlyDenied = true;
        allGranted = false;
      } else if (!status.isGranted) {
        allGranted = false;
      }
    }
    if (allGranted) return PermissionResult.granted;
    if (anyPermanentlyDenied) return PermissionResult.permanentlyDenied;
    return PermissionResult.denied;
  }

  /// Opens the device app-settings page so the user can manually grant
  /// permissions that were permanently denied.
  Future<void> openDeviceAppSettings() => ph.openAppSettings();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  List<Permission> _requiredPermissions() {
    final perms = <Permission>[Permission.camera, Permission.microphone];
    if (Platform.isAndroid) {
      // API ≥ 33 uses READ_MEDIA_VIDEO; lower uses READ/WRITE_EXTERNAL_STORAGE.
      perms.add(Permission.videos);
      perms.add(Permission.storage);
    } else if (Platform.isIOS) {
      perms.add(Permission.photos);
    }
    return perms;
  }

  PermissionResult _evaluate(Map<Permission, PermissionStatus> statuses) {
    if (statuses.values.every((s) => s.isGranted || s.isLimited)) {
      return PermissionResult.granted;
    }
    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      return PermissionResult.permanentlyDenied;
    }
    return PermissionResult.denied;
  }
}

// ---------------------------------------------------------------------------
// Widget: shown when permissions are denied (PRD §2.4 / Example E)
// ---------------------------------------------------------------------------

/// Shown when the user has denied a required permission.
class PermissionDeniedScreen extends StatelessWidget {
  final PermissionResult result;

  const PermissionDeniedScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isPermanent = result == PermissionResult.permanentlyDenied;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 72, color: Colors.amber),
              const SizedBox(height: 24),
              Text(
                isPermanent
                    ? 'Camera access is required to monitor movement.\nPlease enable it in Settings.'
                    : 'Camera access is required to monitor movement.',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: Text(isPermanent ? 'Open Settings' : 'Grant Permissions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: isPermanent
                    ? () => ph.openAppSettings()
                    : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
