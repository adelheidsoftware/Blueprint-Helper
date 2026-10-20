# Blueprint Helper

A RuneScape client plugin for Invention's **Discovery** puzzle. While the Discovery window is open, it reads the
arrangement on the track and the level the game reports, keeps a history of every arrangement you have tried, and
tells you which two modules to swap next. Following its suggestions reaches **Perfect** within 11 swaps on every
blueprint, and in about 7 on average.

The helper never moves a module, never clicks anything, and never reads anything you cannot see on screen. You keep
dragging modules; it keeps the bookkeeping.

Contents: [What it does](#what-it-does) | [Installing](#installing) | [Using it](#using-it) | [Settings](#settings) |
[How it works](#how-it-works) | [Files](#files) | [Privacy](#privacy) | [For reviewers](#for-reviewers) |
[Development](#development)

## What it does

- **Guide mode** (the default). After each graded arrangement the helper names the two slots to swap, outlines them in
  blue on the Discovery window and brackets them under the module tiles in its own panel. Once only one Perfect
  arrangement is left, every module that is out of place gets a green number showing the slot it belongs in, both on
  the track and among the modules waiting beside it, so you can finish in one go.
- **Logbook mode.** The same reading and history without suggestions, for players who want to solve the puzzle
  themselves and only want the bookkeeping.
- **Prototyping help.** After each Prototype, the modules the game kept are outlined green on the board and counted,
  so you always know which ones are confirmed and which still need testing.
- **History.** Every arrangement you tried with the level it scored, newest first, with the module icons.
- **Memory per blueprint.** Switching to another blueprint and back restores that blueprint's readings, prototyping
  progress and solution. Everything is forgotten when you close the client; only the settings are saved.

## Installing

Install it from the Plugin Hub inside the client or from the plugin's page on Mod.io. It depends on **PrettyUI**
1.2.0 or newer, which the hub installs alongside it. No permissions are requested.

## Using it

1. Open the Plugins window and select Blueprint Helper so its panel is showing. Open Discovery at an inventor's
   workbench and select a blueprint.
2. **Prototyping.** Place any five modules and Prototype. The modules the game keeps are outlined green; replace the
   rejected ones from the rest of the board and Prototype again until five are confirmed.
3. **Arranging.** Place all five modules on the track. When the game shows a level, the helper reads it and suggests a
   swap, for example "Swap 2 and 4". The two slots are outlined on the Discovery window. Drag one of the two modules
   onto the other.
4. Repeat. The line under the suggestion says how many arrangements are still possible and how many swaps you will
   need at most. When it turns green and reads "Solution known", place every numbered module in its slot.
5. When the game shows Perfect, click Invent.

The trash icon on the title row forgets this blueprint's readings. If a reading was mis-read (the helper says
"Readings disagree"), an undo icon appears next to it to drop the newest reading; suggestions keep coming in the
meantime, based on the readings that agree with each other.

## Settings

The settings tab of the Plugins window holds:

| Setting | Default | Effect |
| --- | --- | --- |
| Guide / Logbook | Guide | Whether a swap is suggested after each reading |
| Highlight slots and modules on the Discovery window | on | The blue and green outlines over the game window |
| Show the XP percentage next to the level | on | "Good \| 60% XP" instead of "Good" |
| Compact history | off | Level names only, without module icons |
| Reset all data | | Forgets every remembered blueprint and restores the defaults |

Changes apply immediately.

## How it works

This section explains the whole engine from the ground up, including the lookup table it ships with and how that
table was made. Nothing in it is needed to use the plugin.

### The puzzle is a guessing game

Each blueprint hides a rank from 1 to 5 for each of the five modules, and a rank from 1 to 5 for each of the five
slots on the track. Both sets of ranks are a shuffle of 1 to 5. When you grade an arrangement, the game adds up, over
the five slots, the difference between the rank of the module in the slot and the rank of the slot, and shows the sum
as a level:

| Sum of differences | 0 | 2 | 4 | 6 | 8 | 10 or 12 |
| --- | --- | --- | --- | --- | --- | --- |
| Level | Perfect | Excellent | Very good | Good | Satisfactory | Poor |

The sum is always even. Perfect means every module sits in the slot whose rank matches its own. This rule reproduces
all 535 graded arrangements in a corpus of 25 recorded puzzles.

Take a blueprint whose modules A, B, C, D, E secretly have the ranks 2, 5, 3, 4, 1, and whose slots 1 to 5 have the
ranks 4, 1, 2, 5, 3. You place A B C D E in slots 1 to 5. The differences are |2-4| + |5-1| + |3-2| + |4-5| + |1-3| =
2 + 4 + 1 + 1 + 2 = 10, so the game says Poor. The Perfect arrangement is D E A B C: D's rank 4 in the slot of rank 4,
E's rank 1 in the slot of rank 1, and so on. You never see any of the ranks; the helper's job is to work them out from
the levels you do see.

### What one reading tells you

There are 120 ways to rank the modules and 120 ways to rank the slots, so 14,400 possible pairs of rankings. The
helper calls one such pair a seed. Replacing every rank r by 6 - r on both sides changes none of the differences, so
a seed and its mirror image give the same level to every arrangement and share the same Perfect arrangement: they
can never be told apart, and the helper only needs to consider one of each pair, 7,200 seeds in all.

Every graded arrangement is a reading. The helper keeps the seeds that would have produced exactly that level for
exactly that arrangement and discards the rest. After the first reading:

| Level of the first row | Seeds still possible | Different Perfect arrangements among them |
| --- | --- | --- |
| Perfect | 60 | 1 |
| Excellent | 240 | 10 |
| Very good | 720 | 45 |
| Good | 1,440 | 95 |
| Satisfactory | 2,100 | 99 |
| Poor | 2,640 | 89 |

The second number is what the helper shows as **permutations left**. Many seeds can share one Perfect arrangement,
and the arrangement is all you need to finish, so that is the number to watch. "Solution known" means it has reached
one, even if a few seeds still fit.

### Why the helper talks about slots, not modules

The helper never needs to know which module is which. It numbers the modules 1 to 5 by the slot they sat in when the
first row was graded, and every suggestion is "swap slot i and slot j". That has a useful consequence: two players
with different modules, different blueprints and different hidden ranks, who see the same sequence of levels while
following the suggestions, are in exactly the same situation, with the same set of seeds still possible. The
best next swap is the same for both. The opening table is built on that fact.

### The opening table

Choosing the best swap when thousands of seeds are still possible means looking several swaps ahead: each of the
ten possible swaps can be answered by up to five levels, each of those by ten swaps again, and so on. That search
takes minutes on a desktop. The client gives a plugin a few milliseconds per tick, so the early part of every puzzle
is solved in advance and shipped as a table, `src/core/opening_table.lua`.

**Keys.** A key is the sequence of levels the game has shown so far, opening reading first, written as digits and
joined by dots: 1 Excellent, 2 Very good, 3 Good, 4 Satisfactory, 5 Poor. The key "5.3.4" means: the first graded row
was Poor, after the suggested swap it was Good, and after the next suggested swap it was Satisfactory. Perfect never
appears in a key because it ends the puzzle, and there is no key for an Excellent opening because that already leaves
only ten possible answers, which the live search handles.

**Values.** Each value is `{ slot, slot, swaps }`: swap those two slots next, and if you keep following the
suggestions you will need at most that many swaps after this one. The entry for "5.3.4" is `{ 1, 3, 7 }`.

**Where it stops.** The table covers exactly the situations with more than 12 Perfect arrangements still possible. At
12 or fewer the exact search is cheap enough to run live, so the table hands over. That makes it 137 entries, about
2 KB: 4 keys of one level, 15 of two, 45 of three, 47 of four, 18 of five, 7 of six and 1 of seven.

**A puzzle from start to finish.** The blueprint from the example above, with the helper's suggestions followed every
time. The hidden ranks are only shown so you can check the levels yourself.

| Swap | Row (slots 1 to 5) | Level | Key | Seeds left | Permutations left | Suggestion | Decided by |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | A B C D E | Poor | 5 | 2,640 | 89 | Swap 1 and 2, at most 11 more | table |
| 1 | B A C D E | Good | 5.3 | 288 | 47 | Swap 3 and 4, at most 8 more | table |
| 2 | B A D C E | Satisfactory | 5.3.4 | 72 | 24 | Swap 1 and 3, at most 7 more | table |
| 3 | D A B C E | Satisfactory | 5.3.4.4 | 26 | 13 | Swap 1 and 5, at most 6 more | table |
| 4 | E A B C D | Poor | | 6 | 3 | Swap 1 and 3, at most 4 more | search |
| 5 | B A E C D | Good | | 2 | 1 | Swap 1 and 4, at most 3 more | search |
| 6 | C A E B D | Very good | | 2 | 1 | Swap 1 and 5, at most 2 more | search |
| 7 | D A E B C | Excellent | | 2 | 1 | Swap 2 and 3, at most 1 more | search |
| 8 | D E A B C | Perfect | | | | | |

After swap 3 only 13 Perfect arrangements remain, so the next reading takes the count below 12 and the search takes
over; the key column stops because the table is no longer consulted. From swap 5 on, two seeds still fit but
both have the same Perfect arrangement, so the panel says "Solution known" and marks every module's target slot. A
player who places all of them at once gets there in one move instead of three.

**How the table was made.** For every key that following the table can produce, an offline program tried each of
the ten swaps, split the remaining seeds by the level each swap would produce, and recursed, looking for the swap
whose worst outcome needs the fewest further swaps. That is the same minimax the live search runs, without a time
limit, and with results remembered across the search. It ran over all 7,200 seeds, and every entry's "at most"
figure is the exact worst case from that situation. The whole table was then checked by replaying every seed through
the finished engine: the longest path is 11 swaps and the average is 7.348.

**Leaving the path.** If you swap something other than what was suggested, the sequence of levels no longer
describes your situation, so the table is set aside for this blueprint and the two live layers continue from your
actual readings. Nothing can go wrong with the readings themselves, since the surviving seeds are always computed
from what the game really showed; only the promise of finishing within 11 swaps is lost.

### The endgame search

Once 12 or fewer Perfect arrangements remain, the helper searches at the moment you need the suggestion. It asks,
for d = 1, 2, 3 and so on, "can every remaining seed be brought to Perfect within d swaps?", and the first d that
works is the bound shown as "at most d swaps". Two quick checks cut the search down. With d swaps left you can tell
apart at most 1 + 5 + 25 + ... answers, because each swap gives one of five levels other than Perfect and Perfect
finishes exactly one answer; if more answers than that remain, d is too small. And if any remaining answer is more
than d swaps away from the current row, d is too small as well. The search expands at most 1,000 positions, which
keeps it under about 50 milliseconds in the client; if it runs out, the greedy choice below answers instead.

### The greedy choice

Whenever neither of the above applies, the helper avoids any swap that leads back to an arrangement already graded,
and among the rest picks the one whose worst outcome leaves the fewest Perfect arrangements. Ties go to the swap
whose farthest remaining answer is closest, then to the one whose largest outcome holds the fewest seeds, then to
swaps that could themselves be Perfect. On its own this layer would need up to 13 swaps; it exists for the situations the table
and the search do not cover.

### The guarantee

With the three layers together, every one of the 7,200 seeds reaches Perfect within 11 swaps of the first
graded row, 7.35 on average. 60 seeds are Perfect at once and 152 need all 11. Eleven is also the floor: an
exhaustive search over strategies found none that guarantees fewer.

### The lookup tables inside the engine

A single suggestion scores up to 2,640 seeds against each of ten swaps, and the search repeats that at every
position it expands. To keep that within a few milliseconds, everything the engine touches in its inner loops is an
integer or a lookup in a table built once when the plugin loads:

- **The 120 arrangements** (`permutations.lua`) are numbered, and the engine refers to an arrangement by its number.
  Number 1 is 1 2 3 4 5, the first graded row.
- **Composition** says what you get by applying one arrangement after another. Swapping slots i and j of an
  arrangement is the composition of that arrangement with the arrangement that only exchanges slots i and j: one
  lookup instead of copying and editing a table. Grading uses it too, below.
- **Swap distance** between two arrangements is the smallest number of swaps that turns one into the other, which is
  5 minus the number of cycles in the rearrangement. 1 2 3 4 5 to 2 1 3 4 5 is one swap; to 2 3 1 4 5 is two.
- **The grade table** (`scoring.lua`) holds the level for every pair of "ranks sitting in the slots" and "ranks of
  the slots", 14,400 entries. The ranks sitting in the slots are themselves the composition of the module ranks with
  the arrangement, so grading any arrangement against any seed is two lookups: one composition, one grade.
- **The seeds** (`seeds.lua`) are three arrays indexed by seed number: the module-rank arrangement, the slot-rank
  arrangement, and the Perfect arrangement, which is "in every slot, the module whose rank equals the slot's rank".
  A set of seeds is a plain array of numbers, and a reading filters it in one pass.
- **Counting distinct answers** without clearing a table between calls uses a stamp: each pass has a new stamp
  value, and an answer counts only if its stamp is not already the current one.

### Reading the game reliably

The helper only reads what is on screen: the five track slots (which module sprite sits where), the score label, the
blueprint's name, which stage layer is visible, the prototyping board, and whether a dialog or the Prototype animation
is on top. It polls these 25 times a second while Discovery is open and twice a second while it is closed.

The level is read from the two XP numbers in the score label rather than from its words: the sum of base and extra XP
divided by the base is 1, 2, 3, 3.5, 4 or 5 from Poor to Perfect in every client language. Only the names the helper
displays are English.

When you change the arrangement, the game shows "Analysing..." for a server tick before the new level, and the server
grades only the arrangement on the track when its tick lands. So a level that follows the pending text is paired with
the latest arrangement, which also covers a swap that leaves the level unchanged. If a poll happens to miss the
pending text, the label is trusted after 1.2 seconds. Lifting a module off the track is not a reading.

While prototyping, a module is on the track while its board icon is hidden, and rejected once the game draws its cross
over it. New crosses appearing after a Prototype confirm every module that is still on the track, and a confirmed
module stays confirmed even after you take it off the track again.

### Limits

- Jagex may change the Discovery interface. The helper looks its components up by name and checks their types; if
  anything is missing it says so in its panel instead of guessing, and will need an update.
- A mis-read level (a glitch, or a window dragged mid-swap) shows up as "Readings disagree". Drop the newest reading
  with the undo icon, or reset the blueprint.
- Puzzle progress lives in memory only. Relogging starts every blueprint from scratch, as the game itself does.

## Files

```text
plugin.json                  manifest: name, version, the PrettyUI dependency
main.lua                     wiring: dependency check, settings, events, PluginShutdown
src/constants.lua            version string, event names, PersistentDB keys
src/settings.lua             load and save the four settings, with validation
src/client.lua               guarded client lookups: nil instead of an error for an unknown name or stale component
src/core/                    the puzzle logic; plain Lua, no client API
  levels.lua                 the six levels; parsing the score label from its XP numbers
  row.lua                    what a track row is and when it is complete
  permutations.lua           the 120 arrangements as permutations; composition, swaps, swap distance
  scoring.lua                the grading rule as a lookup table
  seeds.lua                  the 7,200 seeds and the operations on sets of them
  search.lua                 the endgame search
  opening_table.lua          the 137 opening moves (generated offline)
  deduce.lua                 chooses between table, search and greedy
  commit.lua                 when a polled (arrangement, label) pair becomes a reading
  prototyping.lua            the prototyping tracker: which modules a Prototype confirmed or rejected
  session.lua                one puzzle from the player's point of view; the view model for the UI
src/game/                    client adapters
  interface_ids.lua          the Discovery components, by name
  discovery_reader.lua       reads the interface into a snapshot table
  watcher.lua                the polling loop
  overlay.lua                the outlines and numbers over the Discovery window
src/ui/                      PrettyUI views
  theme.lua                  colours and sizes
  helper_view.lua            the panel in the Plugins window
  settings_view.lua          the settings tab
  confirm_dialog.lua         the confirmation in front of both reset buttons
tests/                       standalone Lua 5.4 tests; not part of the plugin and not shipped
package.py                   builds the Mod.io zip in dist/ after the tests pass: py package.py
```

Everything under `src/core/` runs under a standalone Lua 5.4 interpreter, which is how the engine's guarantee was
checked: every one of the 7,200 seeds was replayed through it under honest play. The suite in `tests/` does the same
on every run (`replay_test`); run it with `lua tests/run_all.lua [name ...]`.

## Privacy

The plugin requests no permissions. It reads nothing but the Discovery interface, sends nothing anywhere, and stores
nothing but the four settings above in the client's plugin database.

## For reviewers

What the plugin touches, and where each claim can be checked:

- **Reads** the Discovery interface's components by name, read-only. `src/game/interface_ids.lua` lists every name
  and `src/game/discovery_reader.lua` is the only file that reads them; it never assigns to a game component.
- **Draws** its own components on the plugin build layer (`src/game/overlay.lua`, all clickthrough and disabled) and
  PrettyUI views inside the Plugins window (`src/ui/`).
- **Stores** four settings in PersistentDB (`src/settings.lua`). Puzzle progress is never written anywhere.
- **Sends** nothing. The manifest has no `urls` and requests no permissions.
- **Never acts** for the player: no inputs, no menu entries, no click-zone changes. Every suggestion is computed
  from levels the game has already displayed for arrangements the player already tried.

Everything under `src/core/` is plain Lua: a search for `ui.`, `Event.`, `id.` or `PersistentDB` there finds no
client call. The opening table is data the engine consults for the choice of swap and for nothing else; the
surviving seeds are recomputed from the real readings every time, so a wrong entry could cost swaps but never
correctness. The test suite in `tests/` (standalone Lua 5.4) checks the table with the rest of the engine:
`replay_test` replays every seed and confirms the 11-swap bound and the 7.348 average.

Whether a swap suggestion is acceptable under the plugin guidelines was put to the RuneScape Plugin Portal before
this plugin was built and answered on 2026-10-19: the full plugin, including Guide mode, is allowed. Logbook mode
stays available for players who want to solve the puzzle themselves.

## Development

The client runs Lua 5.4.8. For editor support install the Lua Language Server and point it at the community
[runescape-api-stubs](https://github.com/FriendlyDevelopment/runescape-api-stubs) types. To run a development copy,
put this folder into the client's `dev_plugins` directory under the name `blueprint-helper`, then in the developer
console run `prf` once and `prl blueprint-helper` after every change.

Run the tests with `lua tests/run_all.lua`; it picks up every `*_test.lua` in `tests/`. Lint with
`luacheck main.lua src tests`, which reads `.luacheckrc`.

When releasing:

1. Bump `version` in `plugin.json` and `VERSION` in `src/constants.lua` together.
2. Add the release to `CHANGELOG.md` under a `## [x.y.z] - date` heading. Its text is the release note on Mod.io.
3. Build the upload with `py package.py`. It runs Luacheck (when installed) and the tests, and refuses to package if
   either fails, the two versions differ, or the changelog has no entry for the version.

Questions and bug reports: <aaron@adelheid.org>.
