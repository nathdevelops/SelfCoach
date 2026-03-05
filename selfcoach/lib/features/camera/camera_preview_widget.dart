import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

/// Full-screen live camera preview widget (PRD §2.6).
///
/// Reads the [CameraControllerService] from Riverpod and renders the
/// [CameraPreview] widget, scaled to fill the screen while maintaining the
/// camera's aspect ratio.
class CameraPreviewWidget extends ConsumerWidget {
  const CameraPreviewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraService = ref.watch(cameraServiceProvider);
    final controller = cameraService.controller;

    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white30),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;
        final previewRatio = 1 / controller.value.aspectRatio;

        double previewW;
        double previewH;

        // Fill screen, crop if necessary (cover behaviour)
        if (screenH / screenW > previewRatio) {
          previewH = screenH;
          previewW = previewH / previewRatio;
        } else {
          previewW = screenW;
          previewH = previewW * previewRatio;
        }

        return SizedBox(
          width: screenW,
          height: screenH,
          child: OverflowBox(
            maxWidth: previewW,
            maxHeight: previewH,
            child: CameraPreview(controller),
          ),
        );
      },
    );
  }
}
