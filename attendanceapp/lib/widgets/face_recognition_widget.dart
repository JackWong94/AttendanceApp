import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'scan_beam.dart';

class FaceRecognitionWidget extends StatelessWidget {
  const FaceRecognitionWidget({
    super.key,
    required this.controller,
    this.showScanBeam = false,
    this.topPadding = 20,
    this.bottomPadding = 20,
    this.beamDuration = const Duration(seconds: 2),
    this.borderRadius = 12.0,
    this.circleRatio = 0.6,
  });

  final CameraController controller;
  final bool showScanBeam;
  final double topPadding;
  final double bottomPadding;
  final Duration beamDuration;
  final double circleRatio;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: 300,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final diameter = constraints.maxWidth * circleRatio;

            return Stack(
              alignment: Alignment.center,
              children: [
                // Camera preview
                if (controller.value.isInitialized)
                  CameraPreview(controller)
                else
                  const Center(child: CircularProgressIndicator()),

                // Circle overlay
                IgnorePointer(
                  child: Container(
                    width: diameter,
                    height: diameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 2),
                    ),
                  ),
                ),

                // Instruction text
                const Positioned(
                  bottom: 12,
                  child: Text(
                    "Align your face within the circle",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),

                // Scan beam overlay
                if (showScanBeam)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ScanBeam(
                        active: true,
                        topPadding: topPadding,
                        bottomPadding: bottomPadding,
                        duration: beamDuration,
                        parentHeight: constraints.maxHeight, // pass parent height
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
