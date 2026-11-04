// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/utils/file_selector.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/utils/platform_infos.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart' show MatrixFile;

/// The first run: who you are, before the feed.
///
/// The doc expected this to be needed -- Apple sign-in can withhold a name,
/// so a new player may arrive as nothing better than their handle. Four
/// questions, all optional but the name, and Skip is always there: a welcome
/// that blocks the app is a form, not a welcome. Finishing or skipping both
/// mark it done, on the server, so it is shown once per account.
///
/// Continue ends on a drafted introduction rather than an empty feed. On the
/// Modified forum, newcomers whose first post got a reply came back 85% of
/// the time against 41%, and an introduction is the easiest first post to
/// answer -- the moderators are emailed about any that sit unanswered.
class WelcomePage extends StatefulWidget {
  final FootbagPlayer me;

  const WelcomePage({required this.me, super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late final name = TextEditingController(text: widget.me.displayName);
  late final city = TextEditingController(text: widget.me.city ?? '');
  late final Set<String> styles = {...widget.me.playStyles};
  late bool discoverable = widget.me.discoverable;
  bool saving = false;

  /// The photo just chosen, shown while it uploads and after.
  Uint8List? photo;
  bool uploadingPhoto = false;

  /// A face, asked for up front: in a feed of strangers, a coloured letter
  /// says nothing about who someone is. Uploaded at once, so Skip keeps it.
  Future<void> _pickPhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    final client = Matrix.of(context).client;
    MatrixFile? file;
    if (PlatformInfos.isMobile) {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (picked != null) {
        file = MatrixFile(bytes: await picked.readAsBytes(), name: picked.path);
      }
    } else {
      final picked = (await selectFiles(
        context,
        type: FileType.image,
      )).firstOrNull;
      if (picked != null) {
        file = MatrixFile(bytes: await picked.readAsBytes(), name: picked.name);
      }
    }
    if (file == null || !mounted) return;
    setState(() {
      photo = file!.bytes;
      uploadingPhoto = true;
    });
    try {
      await client.setAvatar(file);
    } catch (_) {
      if (!mounted) return;
      setState(() => photo = null);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.oopsSomethingWentWrong)),
      );
    } finally {
      if (mounted) setState(() => uploadingPhoto = false);
    }
  }

  @override
  void initState() {
    super.initState();
    name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool save}) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    setState(() => saving = true);
    try {
      final client = Matrix.of(context).client;
      await (save
          ? client.updateMe(
              displayName: name.text.trim(),
              city: city.text.trim(),
              playStyles: styles.toList(),
              discoverable: discoverable,
              onboarded: true,
            )
          : client.updateMe(onboarded: true));
      if (save) {
        router.go(
          Uri(
            path: '/rooms/feed/new',
            queryParameters: {
              'caption': draftIntroduction(
                l10n,
                name: name.text,
                city: city.text,
                styles: styles,
              ),
            },
          ).toString(),
        );
      } else if (router.canPop()) {
        router.pop();
      } else {
        router.go('/rooms/feed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is FootbagApiException ? e.detail : l10n.oopsSomethingWentWrong,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      key: const Key('WelcomeScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: AppBar(
        backgroundColor: Nyfa.ground,
        surfaceTintColor: Nyfa.ground,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            key: const Key('WelcomeSkip'),
            onPressed: saving ? null : () => _finish(save: false),
            child: Text(
              l10n.skip,
              style: const TextStyle(
                fontFamily: Nyfa.body,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Nyfa.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: NyfaForm.action(
            key: const Key('WelcomeContinue'),
            label: l10n.welcomeContinue,
            onPressed: name.text.trim().isEmpty || saving
                ? null
                : () => _finish(save: true),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: Text(
                  l10n.welcomeTitle,
                  style: Nyfa.title.copyWith(fontSize: 30),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Text(l10n.welcomeBody, style: Nyfa.bodyMuted),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: l10n.addAPhoto,
                      child: InkWell(
                        key: const Key('WelcomePhoto'),
                        customBorder: const CircleBorder(),
                        onTap: uploadingPhoto ? null : _pickPhoto,
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Nyfa.tonal,
                          foregroundImage: photo == null
                              ? null
                              : MemoryImage(photo!),
                          child: uploadingPhoto
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_a_photo_outlined,
                                  color: Nyfa.paper,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextButton(
                        onPressed: uploadingPhoto ? null : _pickPhoto,
                        style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          foregroundColor: Nyfa.paper,
                          minimumSize: const Size(48, 48),
                        ),
                        child: Text(
                          photo == null ? l10n.addAPhoto : l10n.changePhoto,
                          style: Nyfa.bodyText.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              NyfaForm.field(
                key: const Key('WelcomeName'),
                controller: name,
                label: l10n.displayName,
                helper: l10n.displayNameHelp,
                maxLength: 128,
                capitalization: TextCapitalization.words,
              ),
              NyfaForm.section(l10n.playStyles),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(l10n.playStylesHelp, style: Nyfa.bodyMuted),
              ),
              NyfaForm.chips(
                keyPrefix: 'WelcomeStyle',
                options: [
                  (value: 'kicking', label: l10n.sessionTypeKicking),
                  (value: 'freestyle', label: l10n.sessionTypeFreestyle),
                  (value: 'net', label: l10n.sessionTypeNet),
                  (value: 'stitching', label: l10n.sessionTypeStitching),
                ],
                selected: styles,
                onToggle: (v) => setState(
                  () => styles.contains(v) ? styles.remove(v) : styles.add(v),
                ),
              ),
              const SizedBox(height: 20),
              NyfaForm.field(
                key: const Key('WelcomeCity'),
                controller: city,
                label: l10n.city,
                maxLength: 128,
                capitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              NyfaForm.toggle(
                key: const Key('WelcomeDiscoverable'),
                label: l10n.discoverable,
                explain: l10n.discoverableExplain,
                value: discoverable,
                onChanged: (v) => setState(() => discoverable = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Hi, I'm Kenji, from Brooklyn. I play freestyle and net." -- a first post
/// written from what the welcome was just told, theirs to change or delete.
String draftIntroduction(
  L10n l10n, {
  required String name,
  required String city,
  required Set<String> styles,
}) {
  final who = name.trim();
  final where = city.trim();
  final plays = [
    for (final s in const ['kicking', 'freestyle', 'net', 'stitching'])
      if (styles.contains(s))
        switch (s) {
          'kicking' => l10n.sessionTypeKicking,
          'freestyle' => l10n.sessionTypeFreestyle,
          'net' => l10n.sessionTypeNet,
          _ => l10n.sessionTypeStitching,
        }.toLowerCase(),
  ];
  return [
    where.isEmpty ? l10n.introHi(who) : l10n.introHiFrom(who, where),
    if (plays.isNotEmpty)
      l10n.introPlays(
        plays.length == 1
            ? plays.single
            : '${plays.sublist(0, plays.length - 1).join(', ')} ${l10n.and} ${plays.last}',
      ),
  ].join(' ');
}
