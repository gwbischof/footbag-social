// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// The introduction the welcome drafts as a newcomer's first post.

import 'package:flutter_test/flutter_test.dart';
import 'package:footbag_network/l10n/l10n_en.dart';
import 'package:footbag_network/pages/welcome/welcome_page.dart';

void main() {
  final l10n = L10nEn();

  test('names, city and every style, in a sentence', () {
    expect(
      draftIntroduction(l10n, name: ' Kenji ', city: 'Brooklyn', styles: {'net', 'freestyle'}),
      "Hi, I'm Kenji, from Brooklyn. I play freestyle and net.",
    );
  });

  test('three styles read as a list', () {
    expect(
      draftIntroduction(l10n, name: 'Ana', city: '', styles: {'stitching', 'kicking', 'net'}),
      "Hi, I'm Ana. I play kicking, net and stitching.",
    );
  });

  test('just a name is still a hello', () {
    expect(draftIntroduction(l10n, name: 'Jake', city: '', styles: {}), "Hi, I'm Jake.");
  });
}
