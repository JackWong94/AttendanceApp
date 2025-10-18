import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'scan_beam.dart';

class FaceRecognitionWidget extends StatelessWidget {
  const FaceRecognitionWidget({
    super.key,
    required this.controller,
    this.showScanBeam = false,
    this.topPadding = 120,
    this.bottomPadding = 340,
    this.beamDuration = const Duration(seconds: 2),
    this.borderRadius = 12.0,
    this.circleRatio = 0.60,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final diameter = constraints.maxWidth * circleRatio;

          return SizedBox(
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
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

                const Positioned(
                  bottom: 12,
                  child: Text(
                    "Align your face within the circle",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),

                // Optional: Scan beam
                if (showScanBeam)
                  Positioned(
                    top: topPadding,
                    bottom: bottomPadding,
                    left: 0,
                    right: 0,
                    child: ScanBeam(
                      active: true,
                      topPadding: topPadding,
                      bottomPadding: bottomPadding,
                      duration: beamDuration,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
