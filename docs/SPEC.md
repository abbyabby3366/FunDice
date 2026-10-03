# FunDice — Technical Specification (contract v1)

This file is the single source of truth shared by the backend, the Flutter app and the assets.
If something is ambiguous, choose the most conventional option, implement it, and mention the decision in your
final report. **Never change an interface defined here without reporting it.**

---

## 1. Product

FunDice is a two‑player **bluffing dice game** (Liar's Dice style) for Android and iOS.

* Each player has up to **5 dice**. You only see your own dice. Players take turns **bidding** how many dice
  of a face are on the table in total (both hands), or call **"Liar!"**. The loser of a challenge loses one die;
  the last player with dice wins.
* **Peek** (the game's "catch"): each player may secretly peek at one random die of the opponent, 3 times per game.
  Every peek has a 30 % chance of being caught; when caught, the opponent is told and one of the peeker's own dice is revealed.
* **No lobby, no room codes.** Pairing works like this:
  1. Every player's app "rolls" five dice **on the server** (Roll tab). The server remembers each *online* player's
     **last 5 rolls**.
  2. To start a game, you type in the **5 dice your opponent is currently showing** (Play tab, left → right, in order).
     The moment the 5th die is entered the app sends it to the server.
  3. The server looks only at **currently‑online players' last 5 rolls** and answers with who it is
     (`matched`), that several players match (`ambiguous` → ask for one more roll to disambiguate), `busy` or `not_found`.
  4. You confirm ("Challenge Sam"), Sam gets an invitation and accepts, and the game starts.
* Both phones need internet (Wi‑Fi or mobile data). Everything runs through a Node/Express server hosted on Render.

## 2. Repository layout and file ownership

```
FunDice/
  pubspec.yaml, analysis_options.yaml      Flutter project (android/ + ios/ like PdfScanner)
  android/  ios/
  lib/ …                                   Flutter app (see §4)
  assets/ …                                images (see §7)
  test/ …                                  Flutter tests
  docs/SPEC.md                             this file
  backend/                                 Node 22 + Express + ws (see §3)
  render.yaml                              Render blueprint (rootDir: backend)
  README.md
```

Ownership (an agent edits **only** its own files; if you need a change elsewhere, say so in your report):

| Owner | Files |
|---|---|
| `backend` | everything under `backend/`, `render.yaml` |
| `assets` | `assets/**`, `flutter_launcher_icons.yaml`, `flutter_native_splash.yaml`, `tools/**`, `test/assets/**`, generated Android/iOS icon + splash resources |
| `core-data` | `lib/main.dart`, `lib/app.dart`, `lib/core/constants/**`, `lib/models/**`, `lib/services/**`, `lib/state/**`, tests in `test/models`, `test/services`, `test/state`, `test/e2e`, and shared test fakes in `test/helpers/**` (`FakeApiClient`, `FakeRealtimeClient`, `buildTestController(...)` — used by every screen test) |
| `core-design` | `lib/core/theme/**`, shared widgets listed in §4.6, in `lib/widgets/{die_view,dice_row,rolling_dice,app_button,app_avatar,felt_panel,empty_state,section_header,app_toast}.dart`, tests in `test/widgets` |
| `screens-a` | `lib/screens/{splash,onboarding,home_shell,roll,settings,how_to_play}_screen.dart`, `lib/widgets/server_url_dialog.dart`, `lib/widgets/connection_status_banner.dart`, tests in `test/screens/a_*` |
| `screens-b` | `lib/screens/play_screen.dart`, `lib/widgets/{dice_entry_pad,match_result_card,invite_sheet,invite_waiting_card}.dart`, tests in `test/screens/b_*` |
| `screens-c` | `lib/screens/game_screen.dart`, `lib/widgets/game/**`, tests in `test/screens/c_*` |

`pubspec.yaml` dependencies are fixed (`http`, `web_socket_channel`, `shared_preferences`, `flutter_svg`,
dev: `flutter_launcher_icons`, `flutter_native_splash`, `flutter_lints`). If you really need another package, report it instead of adding it.

---

## 3. Backend contract (Node 22, Express, ws)

### 3.1 Conventions

* ESM (`"type": "module"`), Node ≥ 22, `npm test` uses the built‑in `node:test` runner (no jest/mocha).
* Dependencies (keep it small): `express`, `ws`, `jsonwebtoken`, `helmet`, `express-rate-limit`, `zod`. Dev: none required
  (use global `fetch` + `ws` client in tests).
* **In‑memory state only** (users online, rolls, invites, games). No database. A restart loses games/invites; clients must resync.
* JSON UTF‑8 bodies. Timestamps: ISO‑8601 UTC with milliseconds. IDs are prefixed UUIDv4: `usr_…`, `inv_…`, `gam_…`.
* Dice are arrays of **5 integers 1‑6**.
* Auth: `Authorization: Bearer <jwt>` — JWT HS256 signed with `JWT_SECRET`, payload `{ sub: "<userId>", name: "<display name>" }`, expiry 30 days.
* Errors: HTTP status + `{ "error": { "code": "<snake_case>", "message": "<human readable, shown in the app>", "retryAfter": <seconds, optional> } }`.

| HTTP | `code` | When |
|---|---|---|
| 400 | `bad_request` | malformed JSON / body |
| 400 | `invalid_name` | name not 2‑16 chars after trim, or has disallowed characters |
| 400 | `invalid_dice` | dice are not 5 ints in 1..6 |
| 400 | `invalid_bid` | quantity/face out of range, or does not raise the current bid |
| 400 | `self_invite` | inviting yourself |
| 401 | `unauthorized` | missing / invalid / expired token |
| 403 | `not_matched` | inviting a user you have not just matched (see 3.4) |
| 404 | `invite_not_found` | unknown invite or not addressed to / created by you |
| 404 | `no_active_game` | you are not in a game |
| 409 | `already_in_game` | you are in a game that is still `playing` |
| 409 | `opponent_busy` | target is in a game or already has a pending incoming invite |
| 409 | `opponent_offline` | target has no live WebSocket |
| 409 | `invite_expired` | invite no longer pending |
| 409 | `not_your_turn` | |
| 409 | `no_bid_to_challenge` | |
| 409 | `no_peeks_left` | |
| 409 | `nothing_to_peek` | every opponent die this round is already seen (no peek is consumed) |
| 409 | `game_over` | action on a finished game |
| 429 | `rate_limited` | `retryAfter` in seconds |
| 500 | `server_error` | never leak stack traces |

Names: trimmed, internal whitespace collapsed, 2‑16 chars, Unicode letters / digits / space / `_` `-` `.` only.

### 3.2 REST endpoints

`GET /healthz` (no auth) → `200 {"ok":true,"uptime":12.3,"version":"1.0.0"}`

`POST /api/register` body `{"name":"Alex"}` → `201 {"token":"<jwt>","user":{"id":"usr_…","name":"Alex"}}`
If a **valid** `Authorization` header is present the same user id is kept (rename / token refresh); otherwise a new id is created.
Limit: 10 / hour / IP.

`GET /api/me` (auth) → resync snapshot used at launch and after every reconnect:
```json
{
  "user": { "id": "usr_…", "name": "Alex" },
  "rolls": [ { "seq": 7, "dice": [3,1,6,6,2], "at": "2026-10-03T10:00:00.000Z" } ],
  "invites": { "incoming": null, "outgoing": null },
  "game": null,
  "config": { "diceCount": 5, "rollHistory": 5, "peeksPerGame": 3, "inviteTtlSec": 60, "graceSec": 60 }
}
```
`rolls` = my last ≤5 rolls, **oldest first, newest last**. `game` is a `GameView` (see 3.6) or `null`
(a finished game that I have not dismissed is still returned).

`POST /api/roll` (auth) → `200 {"roll":{"seq":8,"dice":[…],"at":"…"},"rolls":[…last 5, newest last…]}`.
Server rolls with `crypto.randomInt`. `seq` increments per user from 1. `409 already_in_game` while a game is `playing`. Limit 60/min/user.

`POST /api/match` (auth) body `{"dice":[3,1,6,6,2],"next":[…optional second roll…]}` → `200` one of:
```json
{ "status": "matched",   "opponent": { "id": "usr_…", "name": "Sam" } }
{ "status": "busy",      "opponent": { "id": "usr_…", "name": "Sam" } }
{ "status": "ambiguous", "candidates": 2 }
{ "status": "not_found" }
```
Algorithm (3.3). `409 already_in_game` if I am playing.

`POST /api/invites` (auth) body `{"to":"usr_…"}` → `201 {"invite":Invite}`
`POST /api/invites/:id/accept` (recipient) → `200 {"game":GameView}`
`POST /api/invites/:id/decline` (recipient) → `200 {"ok":true}`
`DELETE /api/invites/:id` (sender cancels) → `200 {"ok":true}`

`Invite`:
```json
{ "id":"inv_…", "status":"pending", "from":{"id":"usr_…","name":"Alex"}, "to":{"id":"usr_…","name":"Sam"},
  "createdAt":"…", "expiresAt":"…" }
```
`status` ∈ `pending | accepted | declined | cancelled | expired`.

`GET /api/game` → `200 {"game":GameView|null}`
`POST /api/game/bid` body `{"quantity":3,"face":4}` → `200 {"game":GameView}`
`POST /api/game/challenge` → `200 {"game":GameView}` (round already resolved; `lastRound` filled; next round already started unless the game ended)
`POST /api/game/peek` → `200 {"game":GameView,"peek":{"index":2,"value":5,"caught":false}}`
`POST /api/game/leave` → `200 {"game":GameView|null}` — while `playing`: forfeit (leaver's game becomes `null`; opponent sees `finished`, `endReason:"forfeit"`); while `finished`: dismiss → `null`.

Rate limits: global 300 req / 5 min / IP; match 30/min/user plus lockout (3.3); game actions 120/min/user. `app.set('trust proxy', 1)` (Render sits behind a proxy).
Also: `helmet()`, body limit 10kb, `x-powered-by` off, JSON 404 for unknown routes, central error handler.

### 3.3 Matching algorithm (`POST /api/match`)

Candidates = every **online** user (≥1 authenticated WebSocket) **other than me** having a roll `r` in their last
`ROLL_HISTORY` (5) rolls with `r.dice` equal to `dice` — **same order, exact equality**.
If `next` is given, the user must also have a roll `r2` with `r2.seq > r.seq` and `r2.dice == next`.

* 0 candidates → `not_found`. 1 candidate → `matched` (or `busy` if that user is in a `playing` game or has a pending
  incoming invite). ≥2 candidates → `ambiguous` with `candidates` = count (**never reveal names/ids/dice of candidates**).
* The client reacts to `ambiguous` by asking the opponent to roll again and sends `dice` (first roll) + `next` (their new roll).
* On `matched`/`busy` the server records a **grant** `me → opponent` valid 5 minutes. `POST /api/invites` requires a valid grant,
  or that the two users finished a game together within the last 10 minutes (rematch) — otherwise `403 not_matched`.
* Lockout: 8 consecutive `not_found` results within 2 minutes → `429 rate_limited` with `retryAfter: 60`. A success resets the counter.
* Responses never contain anyone's dice.

### 3.4 Invites

* One outgoing invite per user (a new one cancels the previous and notifies the old target). Invite TTL `INVITE_TTL_MS` (60 s) →
  status `expired`, both sides are notified.
* Target must be online, not in a `playing` game, and have no pending incoming invite.
* Accepting: if either side is now in a `playing` game → `409`; otherwise create the game, mark invite `accepted`, cancel any outgoing invite of the accepter.

### 3.5 WebSocket (`wss://<host>/ws`)

* Client connects, and within **5 s** sends `{"type":"auth","token":"<jwt>"}`. Success → `{"type":"hello","userId":"usr_…","serverTime":"…"}`.
  Failure → `{"type":"error","code":"unauthorized"}` then close with code **4401**. `maxPayload` 4 KB. ≤5 connections per user.
* A user is **online** while ≥1 authenticated socket is open. Server sends protocol pings every 25 s and terminates sockets that miss a pong.
* Server → client events (all JSON, always have `type`):
  * `{"type":"invite","invite":Invite}` — to the recipient
  * `{"type":"invite_update","invite":Invite}` — to both parties when status changes (accepted / declined / cancelled / expired)
  * `{"type":"game","game":GameView}` — to each player whenever *their view* changes (also on opponent online/offline changes)
* Client → server: only `auth`. Everything else is ignored.
* On SIGTERM close sockets with code 1012.

### 3.6 `GameView` (per‑player projection; never contains the opponent's dice)

```json
{
  "id": "gam_…", "version": 17, "status": "playing", "round": 3, "turn": "you",
  "you":      { "id": "usr_…", "name": "Alex", "diceCount": 4, "peeksLeft": 2 },
  "opponent": { "id": "usr_…", "name": "Sam",  "diceCount": 5, "online": true, "offlineDeadline": null },
  "myDice": [3, 1, 6, 2],
  "bid": { "by": "opponent", "quantity": 3, "face": 4 },
  "peeks":   [ { "index": 2, "value": 5 } ],
  "exposed": [ { "index": 0, "value": 3 } ],
  "lastRound": {
    "round": 2, "bid": { "by": "you", "quantity": 4, "face": 6 }, "challenger": "opponent",
    "total": 3, "bidHeld": false, "loser": "you",
    "hands": { "you": [1,2,6,6], "opponent": [4,4,1,5,2] }
  },
  "winner": null, "endReason": null,
  "log": [ { "id": 41, "type": "bid", "actor": "opponent", "text": "Sam bid 3 × 4", "notify": false, "at": "…" } ],
  "updatedAt": "…"
}
```
* `version` strictly increases with every change; clients ignore older versions.
* `status` ∈ `playing | finished`. `turn`, `bid.by`, `challenger`, `loser`, `winner`, `actor` ∈ `you | opponent` (relative to the viewer; `winner` may be `null`).
* `myDice` — my dice for the current round (length = `you.diceCount`). `peeks` — what I learned about the **opponent's** current dice
  (`index` = position in the opponent's dice array, `value` 1‑6). `exposed` — which of **my** dice (index into `myDice`) the opponent has seen because I was caught.
  Both reset every new round.
* `lastRound` — result of the most recent challenge (null before the first). `hands` revealed here only. `bidHeld` = `total >= bid.quantity`; `loser` = `bidHeld ? challenger : bid.by`.
* `endReason` ∈ `dice_lost | forfeit | disconnect | null`.
* `opponent.offlineDeadline` — ISO time when the opponent will forfeit if still offline, else `null`.
* `log` — last 30 entries, personalised ("You bid 3 × 4"), `type` ∈ `round_start | bid | challenge | round_result | peek | peek_caught | opponent_offline | opponent_online | forfeit | game_over`;
  `notify:true` marks entries the client should surface as a toast (`peek_caught`, `opponent_offline`, `opponent_online`, `forfeit`).

### 3.7 Game rules (authoritative, server side — `src/game/engine.js`, pure + injectable RNG)

1. 2 players, each starts with `DICE_COUNT` (5) dice and `PEEKS_PER_GAME` (3) peeks. The starter of round 1 is random.
2. **Round start**: the server rolls every player's dice (count = their current dice), clears `peeks`/`exposed`, clears `bid`.
3. **Bid**: only on your turn. `1 ≤ quantity ≤ total dice in play` (both players), `face` 1‑6. The first bid of a round is free; every later bid must have
   `quantity > current.quantity` **or** (`quantity == current.quantity` **and** `face > current.face`). No wild dice. A bid passes the turn.
4. **Challenge ("Liar!")**: only on your turn and only if a bid exists. Count dice showing `bid.face` in **both** hands (`total`).
   `bidHeld = total >= bid.quantity`. If held the challenger loses one die, otherwise the bidder does. Fill `lastRound`.
   If the loser has 0 dice left → game `finished` (`endReason: dice_lost`, `winner` = other). Otherwise a new round starts and the **loser** starts it.
5. **Peek**: allowed any time while `playing` (any turn) if `peeksLeft > 0`. Picks a random opponent die not yet in my `peeks`
   (none left → `409 nothing_to_peek`, nothing consumed), consumes one peek and returns it. With probability `PEEK_CAUGHT_CHANCE` (0.30) the peek is **caught**:
   the opponent gets a `peek_caught` log entry (`notify:true`) and one random die of the peeker not already exposed becomes visible to the opponent
   (opponent's `peeks` gets it, peeker's `exposed` gets it). The peeker also gets a `peek_caught` entry. The response `peek.caught` tells the peeker.
6. **Forfeit**: `leave` while playing. **Disconnect**: if a player has no live socket for `DISCONNECT_GRACE_MS` (60 s) while `playing`, that player forfeits
   (`endReason: disconnect`). Coming back before the deadline cancels it; opponent is told through `opponent.online`/`offlineDeadline` and `opponent_offline`/`opponent_online` log entries.
7. Finished games stay visible to both players until each calls `leave` (dismiss) or 10 minutes pass. Finished ≠ busy: players can roll/match/invite again (rematch).

### 3.8 Configuration (env, defaults)

`PORT` (3000; Render injects its own), `JWT_SECRET` (required when `NODE_ENV=production`, otherwise a random one with a console warning),
`ROLL_HISTORY=5`, `DICE_COUNT=5`, `PEEKS_PER_GAME=3`, `PEEK_CAUGHT_CHANCE=0.3`, `INVITE_TTL_MS=60000`, `DISCONNECT_GRACE_MS=60000`.
The server must be creatable from tests with injected config, `rng` and clock (`createServer({config, rng, now})`) so expiry/forfeit can be tested in milliseconds.

### 3.9 Deployment (Render)

`render.yaml` at the repo root (`FunDice/render.yaml`): one `web` service, `runtime: node`, `rootDir: backend`, `buildCommand: npm ci`, `startCommand: npm start`,
`healthCheckPath: /healthz`, env `NODE_VERSION=22`, `JWT_SECRET` with `generateValue: true`. README explains: free plan sleeps after ~15 min idle (first request takes up to a minute —
the app shows "Waking up the server…"), single instance, memory‑only state, and how to point the app at the service (`--dart-define=API_BASE_URL=…` or Settings → Server).

### 3.10 Dev bot (`backend/scripts/bot.js`, `npm run bot`)

Connects to `BASE_URL` (default `http://localhost:3000`) as "Bot Benny", keeps its WebSocket alive, rolls (and re-rolls every 45 s while idle),
**prints its current dice clearly** ("Type these on the Play tab: 3 1 6 6 2"), auto‑accepts invites, plays with a simple heuristic
(expected count = own matches + opponentDice/6; challenge if the bid exceeds expectation by > 1.5, else raise minimally), and starts nothing on its own. It lets one person test everything with one phone.

---

## 4. Flutter architecture

Plain Flutter, **no state‑management package** (like PdfScanner): a `ChangeNotifier` (`AppController`) exposed with an `InheritedNotifier` (`AppScope`).
Folder layout mirrors PdfScanner: `lib/core/{constants,theme,utils}`, `lib/models`, `lib/screens`, `lib/services`, `lib/state`, `lib/widgets`.
Portrait only (`SystemChrome.setPreferredOrientations`), light theme only, Material 3.

### 4.1 Constants — `lib/core/constants/app_config.dart`
`AppConfig.defaultServerUrl` = `String.fromEnvironment('API_BASE_URL')`; if empty: debug builds → Android `http://10.0.2.2:3000`, other platforms `http://localhost:3000`;
release builds → empty string (never point at an unknown host). If the effective URL is empty the app must prompt for it (Settings → Server dialog) instead of failing silently.
Also: `registerTimeout = 75 s` (Render cold start), `requestTimeout = 15 s`, `wakingHintAfter = 5 s`, reconnect backoff 1 s → 30 s (×2, jitter).

### 4.2 Models — `lib/models/*.dart` (immutable, `fromJson`, tolerate unknown fields)

`AppUser{id,name}` · `Roll{seq,dice,at,shared}` (`shared=false` for the offline local fallback) · `Invite{id,status(InviteStatus),from,to,createdAt,expiresAt}` ·
`Side{you,opponent}` · `Bid{by,quantity,face}` · `GamePlayer{id,name,diceCount,peeksLeft}` · `GameOpponent{id,name,diceCount,online,offlineDeadline}` ·
`SeenDie{index,value}` · `RoundResult{round,bid,challenger,total,bidHeld,loser,yourHand,opponentHand}` · `GameLogEntry{id,type,actor,text,notify,at}` ·
`GameView{… §3.6 …}` with helpers `isMyTurn`, `isFinished`, `totalDice`, `iWon`, `Bid minimumNextBid` (smallest legal bid) and `bool isLegalBid(q,f)` ·
`MatchStatus{matched,busy,ambiguous,notFound}`, `MatchResult{status,opponent?,candidates?}` · `PeekResult{index,value,caught}` · `ServerConfig{diceCount,rollHistory,peeksPerGame,inviteTtlSec,graceSec}` ·
`ApiException{code,message,statusCode,retryAfterSec}` with `isOffline` (`code == 'offline'`), `isUnauthorized`.

### 4.3 Services — `lib/services/*.dart`

* `LocalStore` (shared_preferences): `token`, `userId`, `userName`, `serverUrl`, `hapticsEnabled`.
* `ApiClient({baseUrl, http.Client? client})`: one method per endpoint in §3.2 (`warmUp`, `register`, `me`, `roll`, `match`, `createInvite`, `acceptInvite`, `declineInvite`, `cancelInvite`, `getGame`, `bid`, `challenge`, `peek`, `leaveGame`);
  mutable `baseUrl` and `token`; maps transport failures/timeouts to `ApiException(code:'offline')`, non‑2xx to `ApiException(code,message,…)` from the error body.
* `RealtimeClient`: connects to `ws(s)://<base>/ws`, sends `auth`, exposes `Stream<ServerEvent> events` (`HelloEvent`, `InviteEvent`, `InviteUpdateEvent`, `GameEvent`) and
  `ValueListenable<bool> connected`; auto‑reconnect with backoff; test‑friendly (channel factory injectable).

### 4.4 `AppController` — `lib/state/app_controller.dart` (+ `AppScope` in `lib/state/app_scope.dart`)

```dart
enum AppPhase { booting, needsName, ready }
enum ServerStatus { connecting, waking, online, offline }   // waking = first attempt taking > wakingHintAfter

class AppController extends ChangeNotifier {
  AppController({required ApiClient api, required RealtimeClient realtime, required LocalStore store});

  AppPhase get phase;            ServerStatus get serverStatus;     AppUser? get user;
  List<Roll> get rolls;          // newest LAST, max rollHistory
  Invite? get incomingInvite;    Invite? get outgoingInvite;        GameView? get game;
  ServerConfig get config;       bool get hapticsEnabled;           String get serverUrl;
  String? get notice;            void consumeNotice();              // one‑shot toast text, shown globally by HomeShell

  Future<void> bootstrap();                      // read store → identity? phase=ready (optimistic) : phase=needsName; then connect/resync in background
  Future<void> registerName(String name);        // onboarding + rename; long timeout; throws ApiException
  Future<void> setServerUrl(String url);         // persists, reconnects
  Future<void> setHaptics(bool enabled);
  Future<void> resync();                         // GET /api/me → replace rolls/invites/game/config; 401 → silently re‑register with stored name

  Future<Roll> roll();                           // server roll; if offline returns a local Roll(shared:false) without touching `rolls`
  Future<MatchResult> match(List<int> dice, {List<int>? next});
  Future<void> sendInvite(AppUser to);   Future<void> cancelOutgoingInvite();
  Future<void> acceptInvite();           Future<void> declineInvite();

  Future<void> bid(int quantity, int face);
  Future<PeekResult> peek();
  Future<void> challenge();
  Future<void> leaveGame();                      // forfeit while playing, dismiss when finished
}
```
Rules: methods throw `ApiException` (UI shows `.message`); state updates from REST responses **and** WebSocket events are merged by `GameView.version`;
after every (re)connect call `resync()`; a `game` that disappears from the server while the client had a `playing` game sets `notice = 'The game ended (server restarted).'`;
notices are produced for: invite declined / expired / cancelled, and new `GameLogEntry` with `notify == true`. `AppHaptics.enabled` mirrors `hapticsEnabled`.
`AppScope.of(context)` returns the controller and rebuilds dependents when it notifies.

### 4.5 Navigation & screens

`app.dart`: `MaterialApp(theme: AppTheme.light, home: AppGate())`; `AppGate` switches on `phase`: `booting → SplashScreen`, `needsName → OnboardingScreen`, `ready → HomeShell`.
`HomeShell` (screens‑a) owns the global behaviour: bottom navigation **Roll | Play | Settings** (`IndexedStack`), the connection banner, showing `notice` toasts,
`showInviteSheet(context)` when `incomingInvite != null` (once per invite id), and pushing `GameScreen` when `game != null` and it is not already open.
`GameScreen` is driven entirely by `controller.game`; it pops itself when `game == null`; when a rematch creates a new game id it just rebuilds.

Public widget API (constructors must stay exactly like this — other agents call them):
```dart
SplashScreen()  OnboardingScreen()  HomeShell()  RollScreen()  SettingsScreen()  HowToPlayScreen()   // screens-a
PlayScreen()   Future<void> showInviteSheet(BuildContext context)                                      // screens-b
GameScreen()                                                                                          // screens-c
Future<void> showServerUrlDialog(BuildContext context)                                                // screens-a (lib/widgets/server_url_dialog.dart)
```

### 4.6 Shared widgets (core‑design) — pure UI, **no imports from models/services/state**

```dart
enum DieState { normal, peeked, highlighted, dimmed, selected, empty }
DieView({int? value, double size = 56, DieState state = DieState.normal, String? semanticsLabel})   // null value → face‑down die (die_hidden.svg); empty → dashed slot
DiceRow({required List<int?> values, double dieSize = 56, double spacing = 8, Map<int, DieState> states = const {}, WrapAlignment alignment = center})
RollingDice({required List<int?> values, required bool rolling, double dieSize = 56, VoidCallback? onSettled})   // while rolling==true faces shuffle + wobble; when it turns false they settle on `values` (≥250 ms settle animation); null value = face-down die
AppButton({required String label, VoidCallback? onPressed, AppButtonStyle style = primary|secondary|destructive|ghost, IconData? icon, bool loading = false, bool expand = true})
AppAvatar({required String seed, required String name, double size = 44})            // initials on a colour derived from `seed`
FeltPanel({required Widget child, EdgeInsets padding, double radius = 24})           // green felt, subtle radial gradient + inner border
EmptyState({required String asset, required String title, String? message, Widget? action})
SectionHeader(String title, {Widget? trailing})
showAppToast(BuildContext context, String message, {bool isError = false})
```

---

## 5. Design system

Conventional, calm and friendly; light theme; generous spacing; one primary action per screen; large tap targets (≥ 48 dp); readable at 1.3× text scale; no custom fonts (system font).

| Token | Value |
|---|---|
| `primary` | `#0E7A5F` (emerald) · `primaryDark #0A5C47` · `primaryLight #D6F2E8` |
| `felt` / `feltDark` / `feltLight` | `#0B5D46` / `#08473A` / `#0F7357` |
| `gold` (bids, peeks, winner) | `#F2B632` · `goldDark #B9851A` · `goldLight #FFF3D1` |
| `dieFace` / `dieEdge` / `pip` / `pipRed` | `#FFFCF2` / `#E6DFCB` / `#1F2328` / `#D93636` (the 1‑pip is red, casino style) |
| `background` / `surface` / `surfaceMuted` / `border` | `#F6F7F5` / `#FFFFFF` / `#EEF0EC` / `#E2E5DF` |
| `textPrimary` / `textSecondary` / `textMuted` | `#14181B` / `#5E6A66` / `#98A29E` |
| `danger` / `success` / `warning` | `#E5484D` / `#17A673` / `#F5A524` (+ light tints for backgrounds) |

Radii: cards 16, buttons 14, sheets 24 (top), die = 18 % of its size. Spacing scale 4 · 8 · 12 · 16 · 24 · 32.
Type: display 32/800, title 22/700, subtitle 17/600, body 16/400, caption 13/500 (secondary colour). Buttons 17/600, height 52.
Motion: 150‑250 ms for UI, 700 ms dice roll (ease‑out wobble), haptics on roll‑settle, keypad press, bid, challenge, round result, win/lose (all through `AppHaptics`).
Accessibility: every die has a semantics label ("Die showing 4" / "Hidden die"), colours never the only signal, contrast ≥ 4.5:1 for text.

---

## 6. Screens and UX (what "conventional" means here)

**Onboarding** — welcome illustration, title "Welcome to FunDice", one text field "What should we call you?" (2‑16 chars, inline validation), **Continue**.
While registering the button shows a spinner and after 5 s the hint "Waking up the server — the first time can take up to a minute". Errors inline. If the server URL is empty a "Set server address" link opens the dialog.

**Roll tab** — Title "FunDice" + small connection dot. A `FeltPanel` with the 5 dice (face‑down "?" before the first roll), under it "Total 17" and a row "1×0 2×1 3×1 4×0 5×0 6×3" (count per face).
Big **Roll** button (primary, full width). "Recent rolls" list: last 5 rolls newest first, each = time + mini dice. Caption: "Friends find you by these dice while you're online." Offline → banner and rolls are local ("Offline — this roll isn't shared").

**Play tab** — Illustration + "Find your opponent" + "Type the 5 dice your opponent is showing, left to right." Five slots (tap a slot to edit) and a keypad of six dice‑face buttons 1‑6 + backspace.
**Auto‑submits when the 5th die is entered** (≈250 ms later). States: *searching* (spinner) → *matched* card (avatar, name, "Online", **Challenge** + "Not them?") ·
*ambiguous* ("More than one player has these dice. Ask them to roll again and enter their new dice." + a second entry row, auto‑submit with `next`) ·
*not_found* ("No online player has rolled these dice recently. Check the order and try again." + shake) · *busy* ("Sam is in a game right now.") ·
*rate_limited* (message + countdown). After **Challenge**: waiting card "Waiting for Sam…" with live countdown to `expiresAt` and **Cancel**; declined/expired → toast + back to entry.

**Invitation sheet** (anywhere in the app) — avatar, "Sam wants to play", countdown, **Accept** / **Decline**. Auto‑closes when cancelled/expired/answered.

**Game screen** — full‑screen felt table. Top: back (confirm "Leave game? You'll forfeit."), "Round 3", opponent chip (avatar, name, online dot; offline → "Reconnecting… 0:42").
Opponent dice row (face‑down; peeked dice revealed with gold ring + eye badge). Centre: current bid card ("Sam's bid: 3 × [die 4]" / "No bid yet — you start") and turn pill ("Your turn" / "Sam is thinking…").
One‑line log ticker (tap → full log sheet). My dice row (exposed dice have an eye badge). Controls on my turn: quantity stepper (min = smallest legal), six face buttons, **Place bid**; **Liar!** (destructive, enabled only when a bid exists); **Peek (2 left)** (first use shows a short risk explanation; disabled when none left/nothing to peek; shows the revealed die).
After a challenge a **round‑result sheet** reveals both hands (matching dice highlighted), the verdict ("Sam's bid was a bluff — Sam loses a die") and **Continue**. Controls are disabled while it is shown.
Finished → in‑place game‑over view: trophy / defeat illustration, "You won!" / "Sam won", reason line (dice lost / forfeit / disconnect), **Rematch** (sends an invite, shows waiting state) and **Home** (dismisses).

**Settings** — Name (tap to edit), Haptics switch, **How to play** page (rules in plain language with the peek rule), Server (shows URL, **Change**, "Test connection"), About (version).

Copy tone: short, friendly, no jargon. Empty and error states always say what to do next.

---

## 7. Assets (`assets/`) — all original, generated by `tools/generate_assets.py` (Pillow) + hand‑written SVG

```
assets/images/logo.svg                      the FunDice mark: two tilted dice, **no text** (text is drawn by Flutter), transparent background
assets/images/dice/die_1.svg … die_6.svg    120×120 viewBox, ivory die, rounded square, pips; the 1 is red
assets/images/dice/die_hidden.svg           face‑down die (emerald, inner border, diamond emblem — **no text**)
assets/images/illustrations/welcome.svg     three dice tumbling (onboarding)
assets/images/illustrations/searching.svg   dice + magnifier / radar (Play tab)
assets/images/illustrations/trophy.svg      win
assets/images/illustrations/defeat.svg      lose (gentle, not sad‑harsh)
assets/images/illustrations/offline.svg     no connection / server unreachable
assets/app_icon/icon_1024.png               opaque, full bleed (iOS) · icon_foreground.png (Android adaptive, transparent, safe zone) · splash_logo.png
```
SVG must be flutter_svg‑safe: plain shapes, paths, linear/radial gradients; **no filters, masks, CSS `<style>`, or fonts**. Palette from §5. Each file ≤ 20 KB.
App icon + native splash are produced with `flutter_launcher_icons` / `flutter_native_splash` (config in their own YAML files, not pubspec).

---

## 8. Quality bar

* Backend: `npm test` green (engine rules, matching incl. order/window/online‑only/ambiguous/`next`/busy, grants, invites lifecycle, game flow over REST+WS,
  disconnect forfeit, rate limits, auth). `npm start` boots without config in dev.
* Flutter: `flutter analyze` → **No issues found**; `flutter test` green (models, controller with fakes, widgets, screen smoke tests at 320×568 and 412×915 with text scale 1.0 and 1.3 — no overflow exceptions);
  `test/e2e/backend_e2e_test.dart` drives two real clients against the real backend (spawned with `node`), skipped unless `FUNDICE_E2E=1`.
* Disk space on this machine is **very low (~3.8 GB free)**: never run `flutter build`, Gradle, emulators, or create large files unless your task explicitly says so. Use the scratchpad for temp files.
* Use absolute paths. Shell is Git Bash / PowerShell on Windows 11. Node 22, Flutter 3.35.5 / Dart 3.9.2.
