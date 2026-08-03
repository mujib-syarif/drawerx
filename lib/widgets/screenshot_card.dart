import 'dart:typed_data';

import 'package:flutter/material.dart';

class ScreenshotCard extends StatelessWidget {
  final Uint8List? thumbnail;
  final VoidCallback? onTap;

  const ScreenshotCard({super.key, required this.thumbnail, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 220,
          child: thumbnail == null
              ? const Center(child: CircularProgressIndicator())
              : Image.memory(
                  thumbnail!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
        ),
      ),
    );
  }
}
