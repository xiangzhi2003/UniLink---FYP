import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_tokens.dart';
import '../utils/error_messages.dart';
import 'empty_state.dart';

enum _AsyncPhase { loading, error, empty, data }

/// Wraps a `Future<T>` with the loading/error/empty/data states that were
/// previously copy-pasted (FutureBuilder + manual ConnectionState checks)
/// across browse_screen.dart, my_listings_screen.dart, chat_list_screen.dart,
/// transactions_list_screen.dart and transaction_detail_screen.dart.
///
/// Wrap the returned widget in a `RefreshIndicator` at the call site if you
/// need pull-to-refresh (this widget only owns the future/state, not the
/// scroll gesture, since call sites vary between GridView/ListView).
class AsyncStateView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final bool Function(T data)? isEmpty;
  final Widget? emptyState;
  final VoidCallback? onRetry;
  final Widget? loadingSkeleton;

  const AsyncStateView({
    super.key,
    required this.future,
    required this.builder,
    this.isEmpty,
    this.emptyState,
    this.onRetry,
    this.loadingSkeleton,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        late final _AsyncPhase phase;
        late final Widget child;

        if (snapshot.connectionState == ConnectionState.waiting) {
          phase = _AsyncPhase.loading;
          child = loadingSkeleton ?? const _DefaultSkeleton();
        } else if (snapshot.hasError) {
          phase = _AsyncPhase.error;
          child = EmptyState(
            icon: Icons.error_outline,
            title: 'Something went wrong',
            message: friendlyErrorMessage(snapshot.error!),
            actionLabel: onRetry != null ? 'Retry' : null,
            onAction: onRetry,
          );
        } else {
          final data = snapshot.data as T;
          if (isEmpty != null && isEmpty!(data)) {
            phase = _AsyncPhase.empty;
            child = emptyState ??
                const EmptyState(icon: Icons.inbox_outlined, title: 'Nothing here yet');
          } else {
            phase = _AsyncPhase.data;
            child = builder(context, data);
          }
        }

        return AnimatedSwitcher(
          duration: AppDurations.normal,
          child: KeyedSubtree(key: ValueKey(phase), child: child),
        );
      },
    );
  }
}

/// Generic shimmer placeholder (a column of rounded bars) used when a
/// screen doesn't supply its own shape-matched [loadingSkeleton].
class _DefaultSkeleton extends StatelessWidget {
  const _DefaultSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.outline.withValues(alpha: 0.3),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, __) => Container(
          height: 72,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder shaped like a responsive listing grid, for screens
/// (browse/my-listings) whose loading state should mirror the grid layout.
class GridSkeleton extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;

  const GridSkeleton({super.key, this.crossAxisCount = 2, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.outline.withValues(alpha: 0.3),
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.72,
        ),
        itemCount: itemCount,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }
}
