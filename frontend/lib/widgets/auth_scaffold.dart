import 'package:flutter/material.dart';
import 'stamp_mark.dart';

/// Shared layout for the auth/profile flow: a centered card on a paper
/// background, headed by the [StampMark] brand/verification mark. Replaces
/// the `Scaffold > Center > ConstrainedBox` boilerplate that used to be
/// repeated across every auth screen.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool sealed;
  final Widget child;

  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.sealed = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StampMark(sealed: sealed),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 28),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
