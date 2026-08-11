import 'package:flutter/material.dart';

/// Centralized official ASF application logo widget — renders the high-res
/// official ASF logo (`assets/images/asf_logo.png`) with proper scaling,
/// rounded corners, and shadow options.
class AsfLogo extends StatelessWidget {
  const AsfLogo({
    super.key,
    this.size = 84.0,
    this.borderRadius = 20.0,
    this.showShadow = true,
    this.showBorder = true,
  });

  final double size;
  final double borderRadius;
  final bool showShadow;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
        border: showBorder
            ? Border.all(color: Colors.white, width: 2)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - (showBorder ? 2 : 0)),
        child: Image.asset(
          'assets/images/asf_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
