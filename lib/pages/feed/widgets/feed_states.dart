// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/skeleton.dart';
import 'package:material_ui/material_ui.dart';

/// A post's shape, before the post arrives.
///
/// The same proportions as a real card -- header, square, two lines -- so
/// the first page lands without anything moving. A spinner in the middle of
/// an empty screen says "wait"; this says what is coming.
class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    builder: (context, c) {
      Widget bar(double w, double h) =>
          Container(width: w, height: h, color: c);
      return DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Nyfa.rule)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(110, 12),
                      const SizedBox(height: 6),
                      bar(70, 10),
                    ],
                  ),
                ],
              ),
            ),
            AspectRatio(aspectRatio: 1, child: ColoredBox(color: c)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(90, 14),
                  const SizedBox(height: 10),
                  bar(260, 12),
                  const SizedBox(height: 6),
                  bar(180, 12),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class FeedEmpty extends StatelessWidget {
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const FeedEmpty({
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Diamond(size: 44, filled: false, color: Nyfa.greenDim),
        const SizedBox(height: 20),
        Text(
          title.toUpperCase(),
          textAlign: TextAlign.center,
          style: Nyfa.heading.copyWith(fontSize: 24),
        ),
        if (body != null) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              body!,
              textAlign: TextAlign.center,
              style: Nyfa.bodyMuted,
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 24),
          NyfaForm.action(
            key: const Key('FeedEmptyAction'),
            label: actionLabel!,
            onPressed: onAction,
          ),
        ],
      ],
    ),
  );
}

class FeedProblem extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const FeedProblem({required this.error, required this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final text = switch (error) {
      FootbagApiException(isNotSignedIn: true) => l10n.signedOutAgain,
      FootbagApiException(:final detail) => detail,
      _ => l10n.oopsSomethingWentWrong,
    };
    return FeedEmpty(
      title: text,
      actionLabel: l10n.tryAgain,
      onAction: onRetry,
    );
  }
}

/// The end of the list: loading the next page, a retry, or a quiet stop.
class FeedFooter extends StatelessWidget {
  final bool loading;
  final bool failed;
  final bool atEnd;
  final VoidCallback onRetry;

  const FeedFooter({
    required this.loading,
    required this.failed,
    required this.atEnd,
    required this.onRetry,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    if (failed) {
      return InkWell(
        onTap: onRetry,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.loadMoreFailed,
            textAlign: TextAlign.center,
            style: Nyfa.bodyMuted,
          ),
        ),
      );
    }
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: Nyfa.green),
          ),
        ),
      );
    }
    // The end is marked with the club's diamond on a rule, rather than a
    // sentence: there is nothing to say, only that there is no more.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: atEnd
          ? const Row(
              children: [
                Expanded(child: Divider(color: Nyfa.rule)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Diamond(size: 12, color: Nyfa.greenDim),
                ),
                Expanded(child: Divider(color: Nyfa.rule)),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}
