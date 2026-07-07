import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Tunable layout numbers for [AuthHeaderScaffold]. Edit these directly to
/// nudge the header's proportions — each controls one visual thing.
class _HeaderMetrics {
  // Left/right padding of the header text block. Must equal
  // [cardHorizontalPadding] or the title and the form fields below won't
  // line up on the same left edge.
  static const double headerHorizontalIndent = 20.0;

  // Left/right padding of the card content (form). Kept equal to
  // [headerHorizontalIndent] on purpose — see above.
  static const double cardHorizontalPadding = 20.0;

  // Max width of the header's own text/back-button column on wide web
  // viewports. No effect on phones (always narrower than this).
  static const double headerMaxContentWidth = 420.0;

  // Explicit tap-target size for the back chevron, replacing Material's
  // implicit 48px default so its geometry is predictable.
  static const double backIconTapSize = 40.0;

  // How far left the chevron glyph is nudged so its stroke lines up with
  // the title's left edge instead of sitting inset inside its tap target.
  // Raise if the chevron still looks too far right, lower if it overshoots.
  static const double backIconVisualInset = 12.0;

  // Vertical gap: back button row -> title.
  static const double spacingBackToTitle = 8.0;

  // Vertical gap: title -> subtitle.
  static const double spacingTitleToSubtitle = 8.0;

  // Vertical gap: subtitle (or title, if no subtitle) -> top of the white
  // card. Raise for more breathing room, lower to bring the card up sooner.
  static const double spacingSubtitleToCard = 24.0;

  // Top padding used instead of a fake reserved back-button height on
  // screens that don't show a back button.
  static const double noBackButtonTopInset = 8.0;
}

/// Two-tone auth layout: a navy header (optional back button, title,
/// subtitle) over a rounded-top paper card holding the form. Used by the
/// welcome/login/register screens so the auth flow reads as one piece.
class AuthHeaderScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget child;

  const AuthHeaderScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _HeaderMetrics.headerMaxContentWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _HeaderMetrics.headerHorizontalIndent,
                    8,
                    _HeaderMetrics.headerHorizontalIndent,
                    _HeaderMetrics.spacingSubtitleToCard,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (onBack != null)
                        SizedBox(
                          height: _HeaderMetrics.backIconTapSize,
                          child: Transform.translate(
                            offset: const Offset(
                              -_HeaderMetrics.backIconVisualInset,
                              0,
                            ),
                            child: IconButton(
                              tooltip: 'Back',
                              onPressed: onBack,
                              icon: Icon(
                                Icons.arrow_back,
                                color: scheme.onPrimary,
                              ),
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              constraints: const BoxConstraints(
                                minWidth: _HeaderMetrics.backIconTapSize,
                                minHeight: _HeaderMetrics.backIconTapSize,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(
                          height: _HeaderMetrics.noBackButtonTopInset,
                        ),
                      const SizedBox(height: _HeaderMetrics.spacingBackToTitle),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: scheme.onPrimary),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(
                          height: _HeaderMetrics.spacingTitleToSubtitle,
                        ),
                        Text(
                          subtitle!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.xxl),
                  topRight: Radius.circular(AppRadius.xxl),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    _HeaderMetrics.cardHorizontalPadding,
                    32,
                    _HeaderMetrics.cardHorizontalPadding,
                    24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
