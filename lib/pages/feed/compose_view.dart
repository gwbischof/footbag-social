// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/compose.dart';
import 'package:footbag_network/pages/feed/feed_view.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:material_ui/material_ui.dart';

class ComposeView extends StatelessWidget {
  final ComposeController controller;

  const ComposeView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = controller;

    return PopScope(
      canPop: !c.hasContent || c.leaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await c.confirmLeave()) {
          c.leaving = true;
          navigator.pop();
        }
      },
      child: Scaffold(
        key: const Key('ComposeScaffold'),
        backgroundColor: Nyfa.ground,
        appBar: Nyfa.appBar(title: l10n.newPostTitle),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Nyfa.rule)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: NyfaForm.action(
                key: const Key('ComposeShare'),
                label: c.uploading ? l10n.waitingForUploads : l10n.publishPost,
                onPressed: c.canShare ? c.share : null,
              ),
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: feedMaxWidth),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const SizedBox(height: 16),
                _MediaStrip(controller: c),
                const SizedBox(height: 20),
                NyfaForm.field(
                  key: const Key('ComposeCaption'),
                  controller: c.caption,
                  label: l10n.captionHint,
                  minLines: 3,
                  maxLines: 10,
                  maxLength: 2200,
                ),
                NyfaForm.section(l10n.tagTrick),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(l10n.tagTrickExplain, style: Nyfa.bodyMuted),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final slug in c.tags)
                        _TagChip(
                          label: c.tagNames[slug] ?? slug,
                          onRemove: () => c.untag(slug),
                        ),
                      if (c.tags.length < 10)
                        _AddChip(
                          key: const Key('ComposeTag'),
                          label: l10n.tagTrick,
                          onTap: c.tagTricks,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                NyfaForm.toggle(
                  key: const Key('ComposeTutorial'),
                  label: l10n.markTutorial,
                  explain: l10n.markTutorialExplain,
                  value: c.tutorial,
                  onChanged: c.setTutorial,
                ),
                if (c.sessions?.isNotEmpty ?? false) ...[
                  NyfaForm.section(l10n.fromSession),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(l10n.fromSessionExplain, style: Nyfa.bodyMuted),
                  ),
                  NyfaForm.chips(
                    keyPrefix: 'ComposeSession',
                    options: [
                      (value: 'none', label: l10n.noSession),
                      for (final s in c.sessions!)
                        (value: '${s.id}', label: s.name),
                    ],
                    selected: {c.sessionId?.toString() ?? 'none'},
                    onToggle: (v) =>
                        c.setSession(v == 'none' ? null : int.parse(v)),
                  ),
                  if (c.canShareResults) ...[
                    const SizedBox(height: 8),
                    NyfaForm.toggle(
                      key: const Key('ComposeShareResults'),
                      label: l10n.includeEveryonesResults,
                      explain: l10n.includeEveryonesResultsBody,
                      value: c.shareResults,
                      onChanged: c.setShareResults,
                    ),
                  ],
                ],
                if (c.clubs.isNotEmpty) ...[
                  NyfaForm.section(l10n.postToClub),
                  NyfaForm.chips(
                    keyPrefix: 'ComposeClub',
                    options: [
                      (value: 'none', label: l10n.noClub),
                      for (final club in c.clubs)
                        (value: '${club.id}', label: club.name),
                    ],
                    selected: {c.clubId?.toString() ?? 'none'},
                    onToggle: (v) =>
                        c.setClub(v == 'none' ? null : int.parse(v)),
                  ),
                ],
                const SizedBox(height: 16),
                NyfaForm.toggle(
                  key: const Key('ComposeArea'),
                  label: l10n.addArea,
                  explain: l10n.addAreaExplain,
                  value: c.addArea,
                  onChanged: c.locating ? (_) {} : c.setAddArea,
                ),
                if (c.addArea) ...[
                  const SizedBox(height: 8),
                  NyfaForm.field(
                    key: const Key('ComposePlace'),
                    controller: c.place,
                    label: l10n.placeName,
                    maxLength: 128,
                    capitalization: TextCapitalization.words,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The photos and clips, in post order. Drag to reorder; the first is the
/// one people see in the feed before they swipe.
class _MediaStrip extends StatelessWidget {
  final ComposeController controller;

  const _MediaStrip({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = controller;

    if (c.drafts.isEmpty) {
      // Nothing picked yet: the add target is the whole width, because
      // media is what most posts are for. A text post simply skips it.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: InkWell(
          key: const Key('ComposeAddMedia'),
          onTap: c.pickMedia,
          child: Container(
            height: 180,
            decoration: BoxDecoration(border: Border.all(color: Nyfa.rule)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 34,
                  color: Nyfa.green,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.addMedia.toUpperCase(),
                  style: Nyfa.heading.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(l10n.photoOrClip, style: Nyfa.bodyMuted),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 132,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // Long-press to drag, with no handle drawn: a handle on every
        // thumbnail covers the photo it is meant to move.
        buildDefaultDragHandles: false,
        itemCount: c.drafts.length,
        onReorderItem: c.reorder,
        footer: c.drafts.length < maxPostMedia
            ? Padding(
                padding: const EdgeInsets.all(4),
                child: InkWell(
                  key: const Key('ComposeAddMore'),
                  onTap: c.pickMedia,
                  child: Container(
                    width: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Nyfa.rule),
                    ),
                    child: const Icon(Icons.add, color: Nyfa.green, size: 28),
                  ),
                ),
              )
            : null,
        itemBuilder: (context, i) {
          final d = c.drafts[i];
          return Padding(
            key: ObjectKey(d),
            padding: const EdgeInsets.all(4),
            child: ReorderableDelayedDragStartListener(
              index: i,
              child: _DraftTile(
                draft: d,
                resolve: c.resolveMedia,
                index: i,
                onRemove: () => c.remove(d),
                onRetry: () => c.retry(d),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  final Draft draft;
  final Uri Function(String) resolve;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  const _DraftTile({
    required this.draft,
    required this.resolve,
    required this.index,
    required this.onRemove,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final d = draft;
    Widget image;
    if (d.preview != null) {
      image = Image.memory(d.preview!, fit: BoxFit.cover);
    } else if (d.media != null) {
      image = Image.network(
        resolve(d.media!.thumbUrl).toString(),
        fit: BoxFit.cover,
      );
    } else {
      image = const ColoredBox(color: Nyfa.raised);
    }

    return SizedBox(
      width: 100,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          if (d.isVideo)
            const Positioned(
              left: 6,
              bottom: 8,
              child: Icon(
                Icons.play_arrow_rounded,
                color: Nyfa.paper,
                size: 22,
              ),
            ),
          if (index == 0)
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                color: Nyfa.green,
                padding: const EdgeInsets.fromLTRB(5, 2, 5, 0),
                child: const Diamond(size: 10, color: Nyfa.ground),
              ),
            ),
          if (d.failed)
            Material(
              color: Nyfa.ground,
              child: InkWell(
                onTap: onRetry,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: Text(
                      l10n.uploadFailed,
                      textAlign: TextAlign.center,
                      style: Nyfa.bodyMuted.copyWith(fontSize: 12),
                    ),
                  ),
                ),
              ),
            )
          else if (!d.done)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                // The web reports nothing until the end, so an honest bar
                // there is an indeterminate one.
                value: d.progress > 0 && d.progress < 1 ? d.progress : null,
                minHeight: 3,
                color: Nyfa.green,
                backgroundColor: Nyfa.rule,
              ),
            ),
          Positioned(
            right: 0,
            top: 0,
            child: Semantics(
              button: true,
              label: MaterialLocalizations.of(context).deleteButtonTooltip,
              child: InkWell(
                onTap: onRemove,
                child: Container(
                  width: 30,
                  height: 30,
                  color: Nyfa.ground,
                  child: const Icon(Icons.close, size: 16, color: Nyfa.paper),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _TagChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.only(left: 12),
    decoration: BoxDecoration(border: Border.all(color: Nyfa.green)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Diamond(size: 10, color: Nyfa.green),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: Nyfa.display,
            fontSize: 16,
            letterSpacing: 0.8,
            color: Nyfa.paper,
          ),
        ),
        IconButton(
          onPressed: onRemove,
          tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
          icon: const Icon(Icons.close, size: 16, color: Nyfa.muted),
        ),
      ],
    ),
  );
}

class _AddChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddChip({required this.label, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(border: Border.all(color: Nyfa.rule)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add, size: 16, color: Nyfa.green),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: Nyfa.display,
              fontSize: 16,
              letterSpacing: 0.8,
              color: Nyfa.paper,
            ),
          ),
        ],
      ),
    ),
  );
}
