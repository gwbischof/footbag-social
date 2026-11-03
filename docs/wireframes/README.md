# Wireframes

The structure the app was built from: what each screen holds and why, not how
it looks (the club theme came later). Open any `.dc.html` file in a browser to
see that screen. The editable original is the
[Footbag Social Wireframes](https://claude.ai/artifact/6ipwTqNE2Y4uv4zJQDoiKr) canvas;
these copies are a snapshot of it from 2026-11-03.

> Nav is Dash · Feed · [+] · Discover · Chat. Dash is home. The [+] creates a SESSION, not a post. Locations are 1-3 mile areas until the host approves you.


## Getting in

- [Splash](Splash.dc.html) — Splash is where the Matrix client restores its session and first-syncs, then routes to Dash or Login. Not just branding.
- [Login](Login.dc.html) — Google and Apple only — no password, no email form, no homeserver field. Both run through Dex, so Synapse still sees one OIDC provider.

## Main flow

- [Dash — home](Dash.dc.html) — Dash is the landing screen: running session with live timer, the area map, your upcoming sessions, TRY NEXT suggestions drawn from your reports, goals and clubs.
- [Dash — first run](DashEmpty.dc.html) — The first screen a new user sees, and at launch it is empty for almost everyone. Leads with the action that works alone rather than an empty map and blank progress bars. Solo logging, goals and the trick database all work with nobody else on the app.
- [Feed](Main.dc.html) — One community feed. No follows. Sort: Recent / Top (day, week, month, year, all). Filter: user, club, location. Posting lives in this header now.
- [Compose post](Compose.dc.html) — Up to 4 media; clips to pict-rs; a pasted YouTube/Vimeo link becomes a native card. Club, session and location prefill from the session you just left. TAGGING with a trick, composite or string is what fills that entry's video list.
- [Post detail](PostDetail.dc.html) — Flat comments, no threads. Tags are real data: club, session and trick are foreign keys, location is geo.
- [Discover](Discover.dc.html) — Same geo query as the feed's location filter. Tricks hangs off here as a fourth chip rather than becoming a sixth tab.
- [Chat](Chat.dc.html) — Split on WHO RUNS IT, not open-vs-closed. Channels we run are cleartext and moderatable, open or members-only (#mods). Anything users make — DMs, group chats, a club's — is encrypted and unreadable by us. 'Members only' is a weaker promise than 'encrypted' and must be labelled as such.
- [Rankings](Rankings.dc.html) — Ranks what the timer and attendance corroborate: play time, sessions, streak. Raw self-reported counts are not ranked here — per-trick records live on the trick page, where a clip is required.

## Sessions — the primary object

- [New session](NewSession.dc.html) — Start now is ONE TAP, not a form — place from nearest known, type and visibility from your profile, club because you are only in one, name generated. Schedule is the only mode that needs a form, and only for when and where.
- [Session — not started](SessionDetail.dc.html) — Everyone sees an AREA: request to join, host approves, then the exact spot. Messaging the host is an encrypted DM, which is also how the exact spot travels — keeping it out of our database.
- [Session running](SessionActive.dc.html) — A 'still playing?' check every 30 min bounds the run: miss it and the session auto-stops, with duration counted only to the last confirmation. Needs push to reach a backgrounded app.
- [Edit session](EditSession.dc.html) — Creator side: approve or decline join requests, which is what reveals the exact location. Only upcoming sessions are editable.
- [Report progress](ReportProgress.dc.html) — Pick from your favourites and grade each one: tried / footing / hitting / consistent. Not a tick box — 'footing it' is the state people spend most of their time in. A first gets a star.
- [Session results](SessionResults.dc.html) — Published results carry the host's note and each player's note alongside the numbers. Notes are the only free text here, so they are the part that needs moderation.
- [Session goals](SessionGoals.dc.html) — Pick goals after starting, never before — Start stays one tap. Or skip it and pick at the end: your favourites ARE the goal list, so there is nothing to set up.
- [Report · no ladder](ReportSimple.dc.html) — Net and stitching have no tricks to grade, so they get time, photos and words. The ladder screen is for freestyle, kicking and casual. Keeping the thin types is still right — their job is filtering Discover.

## Clubs and profiles

- [Club](Club.dc.html) — Clubs live in our own DB, not Matrix spaces. Club chat is a group DM.
- [Edit club](EditClub.dc.html) — Holds the public play location, which is what puts a club in Discover. Open: who may edit, and what happens to posts if a club is deleted.
- [Player profile](Profile.dc.html) — A player profile is the feed filtered to one person — a view, not a follow graph. The practice heatmap answers 'is this player active?' from dated session data.
- [Edit profile](EditProfile.dc.html) — Discoverable is opt-in and location is city level. 'Show my sessions' decides whether anyone else sees the sessions you log — and it is what makes the feed-share option appear on a report.
- [Club members](ClubMembers.dc.html) — Membership is by invite or accepted request. The app creates NO club room — members organise their own encrypted group chat. No bridge, no sync, nothing to reconcile.

## Tricks, composites and strings

- [Tricks & strings](Tricks.dc.html) — Seeded from the Modified /moves/ dictionary: 277 entries with descriptions, ADD breakdowns, nicknames and 50 video-backed records. The 'someone must type hundreds of tricks' cost is now an import script plus curation.
- [Trick detail](TrickDetail.dc.html) — Every video tagged with this trick collects here. TUTORIALS sit above records, because someone opening a trick page is usually trying to learn it, not admire it. Records still need a clip.
- [String detail](StringDetail.dc.html) — A string is an ordered join onto tricks, so the numbering is real data. Its record is the drill metric — reps of the string — and it ranks the same clip-backed way.
- [Compose a string](StringComposer.dc.html) — Users compose their own strings and favourite them. Favourites are what the session report offers, which is why browsing is the fallback rather than the default.
- [Suggest an entry](SuggestEntry.dc.html) — Users suggest; a moderator approves. A COMPOSITE is one trick with adjectives on a base (pixie drifter), not a sequence — that is what separates it from a string. Adds are stored as a breakdown, not a number.
- [Trick — no video yet](TrickDetailEmpty.dc.html) — What MOST of the dictionary looks like on day one — 277 imported entries, 50 with records, almost none with tutorials. Never blank though: name, adds, nickname and description come from the import, so only the video half is empty. Asks for a tutorial and points at the base move.

## Settings and system

- [Notifications](NotifSettings.dc.html) — Two senders, one list: chat push comes from Synapse via a push gateway (Sygnal), everything else from our API straight to APNs/FCM. Encrypted DMs can only say 'New message'.
- [Update required](UpdateGate.dc.html) — Two tiers: a dismissible prompt for most releases, a blocking gate only when the API can't serve that version. The floor moves only after the store build is confirmed live, or everyone is locked out with nothing to install.
- [Notifications](Notifications.dc.html) — One inbox for feed, sessions, clubs, chat and moderation — the bell badges it from the Dash header. Separate from what gets PUSHED. Chat items come from Matrix and the rest from our API, so it merges two sources onto one clock.

## Moderation — the feed only

- [Report post](ReportPost.dc.html) — Nothing could be reported before this existed, so mods would have had to find bad posts by scrolling. Reports are the input side — without them the queue is empty and useless.
- [Mod queue](ModQueue.dc.html) — Remove HIDES a post, it does not delete it: reversible, and session and trick tags stay intact. Purging media from pict-rs is a separate deliberate step. Every action is attributed.
- [Moderators](ModTeam.dc.html) — Chat moderation already ships in the fork — power levels, redact, kick, ban, report. This governs the FEED only. One appointment should set power level 50 too, so 'mod' means one thing.
