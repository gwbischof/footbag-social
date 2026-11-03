// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// The real screens -- their own controllers and views -- with only the
// network swapped for canned data, for looking at. Each preview overrides
// the controller's load(); nothing else differs from the app.

import 'package:footbag_network/pages/dash/dash.dart';
import 'package:footbag_network/pages/discover/discover.dart';
import 'package:footbag_network/pages/favourites/favourites.dart';
import 'package:footbag_network/pages/new_session/new_session.dart';
import 'package:footbag_network/pages/profile/profile.dart';
import 'package:footbag_network/pages/rankings/rankings.dart';
import 'package:footbag_network/pages/report/report.dart';
import 'package:footbag_network/pages/trick_picker/trick_picker.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:latlong2/latlong.dart';

String _iso(Duration ago) =>
    DateTime.now().subtract(ago).toUtc().toIso8601String();

FootbagSession _session(Map<String, dynamic> extra) => FootbagSession.fromJson({
  'id': 8,
  'name': 'Tompkins Square — evening',
  'type': 'freestyle',
  'host_id': '@me:x',
  'host_name': 'Kenji',
  'joining': 'open',
  'on_feed': 'public',
  'attendee_count': 3,
  'my_state': 'host',
  ...extra,
});

FootbagPlayer _player(
  String id,
  String name, {
  String? city,
  List<String> styles = const [],
}) => FootbagPlayer.fromJson({
  'user_id': id,
  'display_name': name,
  'bio': '',
  'city': city,
  'play_styles': styles,
});

FootbagEntry _entry(
  String slug,
  String name,
  String kind,
  List<String> adds, {
  List<String> aka = const [],
}) => FootbagEntry.fromJson({
  'slug': slug,
  'name': name,
  'kind': kind,
  'description': '',
  'aka': aka,
  'adds': adds,
});

// -- Dash ---------------------------------------------------------------------

class PreviewDash extends Dash {
  /// 'running' shows a session in progress; anything else an idle Dash.
  final String mode;

  const PreviewDash({this.mode = 'idle', super.key});

  @override
  DashController createState() => _PreviewDashState();
}

class _PreviewDashState extends DashController {
  @override
  Future<void> load() async {
    final running = (widget as PreviewDash).mode == 'running';
    setState(() {
      canModerate = true;
      sessions = [
        if (running)
          _session({
            'is_running': true,
            'started_at': _iso(const Duration(minutes: 47)),
            'last_checkin_at': _iso(const Duration(minutes: 22)),
          }),
        _session({
          'id': 9,
          'name': 'Washington Sq Saturday',
          'scheduled_at': DateTime.now()
              .add(const Duration(days: 2, hours: 3))
              .toUtc()
              .toIso8601String(),
          'host_name': 'Landes',
          'host_id': '@l:x',
          'my_state': 'approved',
        }),
        _session({
          'id': 7,
          'name': 'Sunday circle',
          'started_at': _iso(const Duration(days: 3, hours: 2)),
          'ended_at': _iso(const Duration(days: 3)),
          'duration_seconds': 7200,
        }),
        _session({
          'id': 6,
          'name': 'Union Square drills',
          'type': 'kicking',
          'started_at': _iso(const Duration(days: 6, hours: 1)),
          'ended_at': _iso(const Duration(days: 6)),
          'duration_seconds': 3300,
        }),
      ];
      runningGoals = running
          ? const [
              FootbagGoal(entrySlug: 'paradox-mirage', name: 'Paradox Mirage'),
              FootbagGoal(entrySlug: 'whirl', name: 'Whirl'),
            ]
          : const [];
      tryNext = const [
        FootbagIdea(
          entrySlug: 'blurry-whirl',
          name: 'Blurry Whirl',
          rule: 'next_step',
          becauseName: 'Whirl',
        ),
        FootbagIdea(
          entrySlug: 'atomic-mirage',
          name: 'Atomic Mirage',
          rule: 'next_step',
          becauseName: 'Mirage',
        ),
      ];
      here = const LatLng(40.728, -73.99);
      nearby = [
        _session({
          'id': 11,
          'name': 'Tompkins pickup',
          'host_id': '@m:x',
          'host_name': 'Marco',
          'my_state': null,
          'is_running': true,
          'started_at': _iso(const Duration(minutes: 30)),
          'area': {'lat': 40.727, 'lng': -73.982, 'radius_m': 1609},
        }),
      ];
    });
  }

  @override
  Future<void> loadNearby({bool ask = false}) async {}
}

// -- Discover -----------------------------------------------------------------

class PreviewDiscover extends Discover {
  const PreviewDiscover({super.initialTab, super.key});

  @override
  DiscoverController createState() => _PreviewDiscoverState();
}

class _PreviewDiscoverState extends DiscoverController {
  @override
  Future<void> load() async => setState(() {
    players = [
      _player('@l:x', 'Landes', city: 'Brooklyn', styles: ['freestyle', 'net']),
      _player('@m:x', 'Marco', city: 'Manhattan', styles: ['freestyle']),
      _player(
        '@la:x',
        'Lamous',
        city: 'Queens',
        styles: ['stitching', 'kicking'],
      ),
      _player('@j:x', 'Jake', city: 'Chicago', styles: ['net']),
    ];
    sessions = [
      _session({
        'host_id': '@l:x',
        'host_name': 'Landes',
        'my_state': null,
        'is_running': true,
        'started_at': _iso(const Duration(minutes: 40)),
      }),
      _session({
        'id': 12,
        'name': 'Prospect Park net',
        'type': 'net',
        'host_id': '@j:x',
        'host_name': 'Jake',
        'my_state': 'requested',
        'scheduled_at': DateTime.now()
            .add(const Duration(days: 1))
            .toUtc()
            .toIso8601String(),
      }),
      _session({
        'id': 13,
        'name': 'Union Square circle',
        'host_id': '@m:x',
        'host_name': 'Marco',
        'my_state': null,
        'attendee_count': 6,
        'scheduled_at': DateTime.now()
            .add(const Duration(days: 3))
            .toUtc()
            .toIso8601String(),
      }),
    ];
    clubs = [
      FootbagClub.fromJson({
        'id': 1,
        'name': 'Tompkins Footbag',
        'location': 'East Village',
        'member_count': 23,
        'my_state': 'approved',
        'my_role': 'organiser',
      }),
      FootbagClub.fromJson({
        'id': 2,
        'name': 'Brooklyn Net Club',
        'location': 'Prospect Park',
        'member_count': 11,
        'my_state': 'requested',
      }),
      FootbagClub.fromJson({
        'id': 3,
        'name': 'Chicago Shred',
        'location': 'Chicago',
        'member_count': 41,
        'my_state': null,
      }),
    ];
  });
}

// -- Rankings -----------------------------------------------------------------

class PreviewRankings extends Rankings {
  const PreviewRankings({super.key});

  @override
  RankingsController createState() => _PreviewRankingsState();
}

class _PreviewRankingsState extends RankingsController {
  @override
  Future<void> load() async {
    final names = [
      'Landes',
      'Marco',
      'Kenji',
      'Lamous',
      'Garrett',
      'Jake',
      'Ana',
    ];
    setState(() {
      clubs = [
        FootbagClub.fromJson({
          'id': 1,
          'name': 'Tompkins Footbag',
          'my_state': 'approved',
        }),
      ];
      club ??= 1;
      rows = [
        for (final (i, n) in names.indexed)
          FootbagRanking.fromJson({
            'position': i + 1,
            'user_id': '@$n:x',
            'display_name': n,
            'city': i.isEven ? 'Brooklyn' : 'Manhattan',
            'value': (11 - i) * 3600 + 900 * i,
            'is_you': n == 'Kenji',
          }),
      ];
      heatmap = [
        for (var d = 0; d < 70; d += (d % 3) + 1)
          FootbagHeatmapDay.fromJson({
            'day': DateTime.now()
                .subtract(Duration(days: d))
                .toIso8601String()
                .substring(0, 10),
            'seconds': 1800 + (d * 977) % 7200,
            'sessions': 1,
          }),
      ];
    });
  }
}

// -- Report -------------------------------------------------------------------

class PreviewReport extends Report {
  const PreviewReport({super.key}) : super(sessionId: 7);

  @override
  ReportController createState() => _PreviewReportState();
}

class _PreviewReportState extends ReportController {
  @override
  Future<void> load() async {
    setState(() {
      session = _session({
        'id': 7,
        'name': 'Sunday circle',
        'started_at': _iso(const Duration(hours: 3)),
        'ended_at': _iso(const Duration(hours: 1)),
      });
      goals = const [
        FootbagFavourite(
          entrySlug: 'paradox-mirage',
          name: 'Paradox Mirage',
          position: 0,
        ),
        FootbagFavourite(entrySlug: 'whirl', name: 'Whirl', position: 1),
      ];
      favourites = const [
        FootbagFavourite(
          entrySlug: 'butterfly',
          name: 'Butterfly',
          position: 0,
        ),
        FootbagFavourite(entrySlug: 'osis', name: 'Osis', position: 1),
        FootbagFavourite(
          entrySlug: 'atomic-mirage',
          name: 'Atomic Mirage',
          position: 2,
        ),
      ];
    });
    setGrade('paradox-mirage', FootbagGrade.footing);
    setGrade('whirl', FootbagGrade.hitting);
    toggleFirst('whirl');
  }
}

// -- Profile, favourites, trick picker, schedule ----------------------------------

class PreviewProfile extends ProfilePage {
  const PreviewProfile({super.key});

  @override
  ProfileController createState() => _PreviewProfileState();
}

class _PreviewProfileState extends ProfileController {
  @override
  Future<void> load() async => setState(() {
    player = _player(
      '@k:x',
      'Kenji',
      city: 'Brooklyn',
      styles: ['freestyle', 'net'],
    );
    nameController.text = 'Kenji';
    bioController.text =
        'Freestyle since 2019. Usually at Tompkins on Tuesdays.';
    cityController.text = 'Brooklyn';
    styles.addAll(['freestyle', 'net']);
  });
}

class PreviewFavourites extends Favourites {
  const PreviewFavourites({super.key});

  @override
  FavouritesController createState() => _PreviewFavouritesState();
}

class _PreviewFavouritesState extends FavouritesController {
  @override
  Future<void> load() async => setState(() {
    favourites = const [
      FootbagFavourite(
        entrySlug: 'paradox-mirage',
        name: 'Paradox Mirage',
        position: 0,
      ),
      FootbagFavourite(entrySlug: 'whirl', name: 'Whirl', position: 1),
      FootbagFavourite(entrySlug: 'butterfly', name: 'Butterfly', position: 2),
      FootbagFavourite(entrySlug: 'osis', name: 'Osis', position: 3),
    ];
    working = List.of(favourites!);
  });
}

class PreviewTrickPicker extends TrickPicker {
  const PreviewTrickPicker({super.key}) : super(alreadyHave: const {'mirage'});

  @override
  TrickPickerController createState() => _PreviewTrickPickerState();
}

class _PreviewTrickPickerState extends TrickPickerController {
  @override
  Future<void> load() async => setState(() {
    entries = [
      _entry(
        'atomic-mirage',
        'Atomic Mirage',
        'composite',
        ['dex', 'dex', 'del'],
        aka: ['Atom Smasher'],
      ),
      _entry('butterfly', 'Butterfly', 'trick', ['dex', 'del']),
      _entry('mirage', 'Mirage', 'trick', ['dex', 'del']),
      _entry('osis', 'Osis', 'trick', ['bod', 'del']),
      _entry('paradox-mirage', 'Paradox Mirage', 'composite', [
        'pdx',
        'dex',
        'del',
      ]),
      _entry('whirl', 'Whirl', 'trick', ['dex', 'del']),
      FootbagEntry.fromJson({
        'slug': 'toe-blur',
        'name': 'Toe Blur',
        'kind': 'trick',
        'description': '',
        'aka': <String>[],
        'adds': <String>[],
        'approved': false,
      }),
    ];
    chosen.add('whirl');
  });
}

class PreviewNewSession extends NewSession {
  const PreviewNewSession({super.key});

  @override
  NewSessionController createState() => _PreviewNewSessionState();
}

class _PreviewNewSessionState extends NewSessionController {
  @override
  void loadClubs() => clubs = [
    FootbagClub.fromJson({
      'id': 1,
      'name': 'Tompkins Footbag',
      'my_state': 'approved',
    }),
  ];
}
