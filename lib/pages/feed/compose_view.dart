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
                // Tricks first: what the clip is of is what makes it findable,
                // and saying you landed one is the post the forum was built on.
                NyfaForm.section(l10n.tricks),
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
                if (c.tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _SwitchRow(
                    key: const Key('ComposeLandedSwitch'),
                    icon: Icons.check_circle_outline,
                    label: c.tags.length == 1 || c.landed == null
                        ? l10n.landedIt
                        : l10n.landedTrick(c.tagNames[c.landed] ?? c.landed!),
                    value: c.landed != null,
                    onChanged: (on) => c.setLanded(on ? c.tags.first : null),
                  ),
                  // Which one, only when there is a choice to make.
                  if (c.landed != null && c.tags.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: NyfaForm.chips(
                        keyPrefix: 'ComposeLanded',
                        options: [
                          for (final slug in c.tags)
                            (value: slug, label: c.tagNames[slug] ?? slug),
                        ],
                        selected: {c.landed!},
                        onToggle: c.setLanded,
                      ),
                    ),
                  if (c.landed != null)
                    _SwitchRow(
                      key: const Key('ComposeLandedFirst'),
                      icon: Icons.star_outline_rounded,
                      label: l10n.firstTime,
                      value: c.landedFirst,
                      onChanged: c.setLandedFirst,
                    ),
                ],
                // The trick rows end on their own rule; with none, the
                // options still need a line to start under.
                if (c.tags.isEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Nyfa.rule),
                ],
                if (c.challenges.isNotEmpty)
                  _OptionRow(
                    key: const Key('ComposeChallenge'),
                    icon: Icons.emoji_events_outlined,
                    label: l10n.enterAChallenge,
                    value:
                        c.challenges
                            .where((x) => x.id == c.challengeId)
                            .firstOrNull
                            ?.title ??
                        l10n.notEntering,
                    highlighted: c.challengeId != null,
                    onTap: () async {
                      final v = await _pick(
                        context,
                        title: l10n.enterAChallenge,
                        options: [
                          (value: null, label: l10n.notEntering),
                          for (final x in c.challenges)
                            (value: x.id, label: x.title),
                        ],
                        selected: c.challengeId,
                      );
                      if (v != null) c.setChallenge(v.value);
                    },
                  ),
                if (c.needsMediaForChallenge)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(56, 0, 20, 12),
                    child: Text(
                      l10n.challengeNeedsMedia,
                      style: Nyfa.bodyMuted,
                    ),
                  ),
                if (c.sessions?.isNotEmpty ?? false)
                  _OptionRow(
                    key: const Key('ComposeSession'),
                    icon: Icons.timer_outlined,
                    label: l10n.fromSession,
                    value:
                        c.sessions!
                            .where((x) => x.id == c.sessionId)
                            .firstOrNull
                            ?.name ??
                        l10n.noSession,
                    highlighted: c.sessionId != null,
                    onTap: () async {
                      final v = await _pick(
                        context,
                        title: l10n.fromSession,
                        options: [
                          (value: null, label: l10n.noSession),
                          for (final x in c.sessions!)
                            (value: x.id, label: x.name),
                        ],
                        selected: c.sessionId,
                      );
                      if (v != null) c.setSession(v.value);
                    },
                  ),
                if (c.canShareResults)
                  _SwitchRow(
                    key: const Key('ComposeShareResults'),
                    icon: Icons.groups_outlined,
                    label: l10n.includeEveryonesResults,
                    value: c.shareResults,
                    onChanged: c.setShareResults,
                  ),
                if (c.clubs.isNotEmpty)
                  _OptionRow(
                    key: const Key('ComposeClub'),
                    icon: Icons.groups_2_outlined,
                    label: l10n.postToClub,
                    value:
                        c.clubs
                            .where((x) => x.id == c.clubId)
                            .firstOrNull
                            ?.name ??
                        l10n.noClub,
                    highlighted: c.clubId != null,
                    onTap: () async {
                      final v = await _pick(
                        context,
                        title: l10n.postToClub,
                        options: [
                          (value: null, label: l10n.noClub),
                          for (final x in c.clubs) (value: x.id, label: x.name),
                        ],
                        selected: c.clubId,
                      );
                      if (v != null) c.setClub(v.value);
                    },
                  ),
                _SwitchRow(
                  key: const Key('ComposeTutorial'),
                  icon: Icons.school_outlined,
                  label: l10n.markTutorial,
                  value: c.tutorial,
                  onChanged: c.setTutorial,
                ),
                _SwitchRow(
                  key: const Key('ComposeArea'),
                  icon: Icons.place_outlined,
                  label: l10n.addArea,
                  // Said once, small, because it is the privacy promise.
                  detail: c.addArea ? l10n.addAreaExplain : null,
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
            decoration: const BoxDecoration(
              color: Nyfa.raised,
              borderRadius: Nyfa.roundedLarge,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 34,
                  color: Nyfa.green,
                ),
                const SizedBox(height: 10),
                Text(l10n.addMedia, style: Nyfa.heading.copyWith(fontSize: 18)),
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
                    decoration: const BoxDecoration(
                      color: Nyfa.raised,
                      borderRadius: Nyfa.rounded,
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
      child: ClipRRect(
        borderRadius: Nyfa.rounded,
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
                        style: Nyfa.meta,
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
    // Tonal, with the green kept to the diamond: a row of green boxes
    // made the tags the loudest thing on a screen whose point is the post.
    decoration: const BoxDecoration(
      color: Nyfa.tonal,
      borderRadius: Nyfa.rounded,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Diamond(size: 10, color: Nyfa.green),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: Nyfa.body,
            fontWeight: FontWeight.w600,
            fontSize: 14,
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
      decoration: const BoxDecoration(
        color: Nyfa.tonal,
        borderRadius: Nyfa.rounded,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add, size: 16, color: Nyfa.green),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: Nyfa.body,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Nyfa.paper,
            ),
          ),
        ],
      ),
    ),
  );
}

/// One option on the composer: an icon, what it is, its current value, and
/// a chevron -- the shape every phone's settings and every big app's
/// composer uses, so it needs no explaining.
class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlighted;
  final VoidCallback onTap;

  const _OptionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.highlighted = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Nyfa.rule)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Nyfa.paper),
          const SizedBox(width: 14),
          Text(
            label,
            style: Nyfa.bodyText.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: highlighted ? Nyfa.bodyText : Nyfa.bodyMuted,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Nyfa.muted),
        ],
      ),
    ),
  );
}

/// An on/off option, the same height and shape as [_OptionRow].
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.detail,
    super.key,
  });

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Nyfa.rule)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Nyfa.paper),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Nyfa.bodyText.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (detail != null) Text(detail!, style: Nyfa.meta),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Nyfa.ground,
              activeTrackColor: Nyfa.green,
              inactiveThumbColor: Nyfa.muted,
              inactiveTrackColor: Nyfa.raised,
            ),
          ],
        ),
      ),
    ),
  );
}

/// A one-of-several choice in a sheet. Returns the picked value wrapped, so
/// "none" (null) can be told apart from dismissing the sheet.
Future<({int? value})?> _pick(
  BuildContext context, {
  required String title,
  required List<({int? value, String label})> options,
  required int? selected,
}) => showModalBottomSheet<({int? value})>(
  context: context,
  backgroundColor: Nyfa.raised,
  shape: Nyfa.sheetShape,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(title, style: Nyfa.heading),
        ),
        for (final o in options)
          InkWell(
            onTap: () => Navigator.of(context).pop((value: o.value)),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: Text(o.label, style: Nyfa.bodyText)),
                  if (o.value == selected)
                    const Icon(Icons.check_rounded, color: Nyfa.green),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);
