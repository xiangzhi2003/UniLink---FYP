// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : app_button.dart
// Description     : Primary styled button widget with a tap-scale press animation.
// First Written on: Tuesday,07-Jul-2026
// Edited on       : Tuesday,07-Jul-2026

import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Shrinks slightly on press (the reference's `active:scale-95` tap
/// feedback) — stock Material buttons have no built-in equivalent.
class _TapScale extends StatefulWidget {
  final Widget child;
  final bool enabled;
  const _TapScale({required this.child, required this.enabled});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.enabled) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: AppDurations.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Filled call-to-action button with a built-in loading spinner, so call
/// sites stop hand-rolling `_loading ? CircularProgressIndicator() : Text()`.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final busy = isLoading || onPressed == null;
    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onSecondary,
            ),
          )
        : icon == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
              );

    return _TapScale(
      enabled: !busy,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: AnimatedSwitcher(
          duration: AppDurations.fast,
          child: KeyedSubtree(key: ValueKey(busy), child: child),
        ),
      ),
    );
  }
}

/// Outlined secondary button, styled from the theme's border/foreground.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool danger;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = danger ? scheme.error : scheme.primary;
    final busy = isLoading || onPressed == null;
    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: tint),
          )
        : icon == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
              );

    return _TapScale(
      enabled: !busy,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: tint,
          side: BorderSide(color: tint, width: 2),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        ),
        child: child,
      ),
    );
  }
}
