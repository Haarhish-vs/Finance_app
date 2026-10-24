import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Reusable loading spinner with optional text status
class AppLoadingIndicator extends StatelessWidget {
  final String? message;
  final bool isCompact;

  const AppLoadingIndicator({
    super.key,
    this.message,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      width: isCompact ? 24.0 : 36.0,
      height: isCompact ? 24.0 : 36.0,
      child: const CircularProgressIndicator(
        strokeWidth: 3.0,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );

    if (isCompact || message == null) {
      return Center(child: spinner);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            spinner,
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
