<p align="center">
  <img src="assets/AppIcon.png" alt="Brain Dump app icon" width="128" height="128" />
</p>

<h1 align="center">Brain Dump</h1>

<p align="center">
  A focused macOS day planner modeled on the <em>Harvard Business Review</em> Daily Timebox.<br />
  Each day is a single sheet — <strong>Brain Dump</strong>, <strong>Top 3</strong>, and an hour-blocked <strong>Schedule</strong> — and whatever you don't finish rolls forward to tomorrow.
</p>


---

## What it is

Brain Dump turns the paper "Daily Timebox" worksheet into a native macOS app. You capture everything on your mind in the **Brain Dump**, pull the three things that actually matter into **Top Priorities**, then **time-block** them onto an hourly schedule. Anything still open at the end of the day automatically reappears in the next day's brain dump, so nothing falls through the cracks. A rotating scholarly quote sets the tone each time you launch.

The whole app is a three-pane sidebar shell: **Today**, **Tasks**, and **Backlog**, with **Settings** in the footer.

---

## Highlights

- **One sheet per day** — Top 3, Brain Dump, and an hourly Schedule, side by side.
- **Automatic rollover** — unfinished items move to today; completed days are kept as history.
- **Drag-and-drop time-blocking** — drag a task onto the schedule or into a priority slot.
- **Full task search** — keyword + tag + completion-date filters across every day.
- **Backlog** — a parking lot for "later" tasks, promoted into a day when you're ready.
- **Tags & notes** on every task, with tag autocomplete from your existing vocabulary.
- **8-color schedule blocks**, conflict detection, and one-tap completion.
- **JSON backup** — export/import all your data; **Clear Data** keeps your settings.
- **Never loses data on launch** — a corrupt store is preserved and the app recovers automatically.
- **Neo-Academic design** — deep navy + crimson, Hanken Grotesk + Source Serif 4, thin borders.

---

## Features

### The daily sheet (Today)

Today is a full-window worksheet: a date header with the day's quote on top, then two columns — **Top Priorities + Brain Dump** on the left, the **Schedule** on the right.

#### Top Priorities (Top 3)

- Up to **three ordered priority slots**, with a live `N/3` counter. Empty slots read "Priority 1/2/3".
- **Promote** a brain-dump item into Top 3 via its **Move to Priority** context-menu item, or by **dragging** it onto a slot.
- When all three slots are full, promoting opens a **Swap** sheet so you can choose which existing priority gets bumped back to the brain dump.
- **Reorder / swap** priorities by dragging one slot onto another.
- **Demote** with the **Move to Brain Dump** context-menu item, or by dragging the priority back into the brain-dump area.
- A scheduled priority shows a **clock icon + start time**; a completed one is **struck through**.
- Click a row to expand its notes; hover to reveal the **edit** (pencil) action.

#### Brain Dump

- An **uncapped** capture list for the day — minor tasks, tangents, thoughts.
- **Add** with the **+** button or **⌘N** — both open the *New Task* sheet (title, description, tags, and an optional "Add to Schedule" toggle).
- Each row shows the title, **tag chips**, and **expandable notes** (click to expand/collapse).
- Hover a row for inline **delete** (✕) and **edit** (pencil) actions.
- **Context menu:** *Schedule*, *Move to Priority*, *Move to Backlog*.
- **Drag** a row onto a schedule slot to time-block it, or onto a Top-3 slot to promote it.

#### Schedule

- A vertical **hourly timeline** in **30-minute slots**, spanning your configured day window (default **5:00 AM – 10:00 PM**) and scrolling inside its card.
- **Drop a task** onto any empty slot to open the **Time Block** sheet.
- The Time Block sheet has **dual scroll-wheel start/end pickers** (15-minute steps), an **8-color** swatch palette, and a live **duration** readout.
- Each block shows the **title, time range, and a color stripe**. Hover for **remove** (✕) and **edit** (pencil); a **checkbox** marks it complete (strike-through + timestamp).
- **Conflict detection:** overlapping blocks are rejected ("Conflicts with another block"); **adjacent** blocks (e.g. 9–10 then 10–11) are allowed. Minimum block length is **15 minutes**, and blocks must fit within the 24-hour day.
- Click a block to open its **read-only detail**; edit it to reschedule or recolor.

> The day-window hours only bound what the grid *displays*. A block scheduled outside the window still exists and is clipped to the visible range.

### Automatic rollover

On every launch the app sweeps all past days:

- An item with **at least one completed schedule entry** that day **stays put** — the day is preserved as history (item, schedule, Top-3 reference intact).
- An item **with no completed entry** is **moved into today's brain dump**; its old schedule entries are deleted and it's removed from that day's Top 3.
- The sweep is **idempotent** — running it again changes nothing.

### Navigating dates

- Click the **date header** (a chevron appears on hover) to open a **month-calendar popover**.
- Pick any **past or current** day to view it; **future days are disabled**. A **Today** button jumps back to the current day.
- The calendar footer shows item counts ("3 items today", "5 items on Jun 2").
- **Past days are read-only** — add/edit/delete/drag affordances are hidden.

### Tasks (search & filter)

The **Tasks** screen lists every non-backlog task across all days, newest first:

- **Keyword search** across **title and description** (case-insensitive).
- **Tag filter** chips, drawn from your global tag vocabulary.
- **Completed Only** toggle, with an optional **date range** (From / To) that filters by **completion date**.
- Each result shows the title (struck through when completed), a notes preview, tags, the day it belongs to, and a `COMPLETED <timestamp>` stamp. Click any result to open its detail.

### Backlog

A parking lot for tasks that aren't tied to a day:

- **Add** with the **Add Task** button or **⌘N**.
- Each item shows title, notes preview, and tags.
- **Move to today** promotes an item into today's brain dump; the **✕** deletes it.
- Click an item to view or edit it.

### Task details, notes & tags

The **Task Detail** sheet handles create, edit, and read-only views:

- **Title** (required), **Description** (multi-line), and **Tags** with autocomplete from tags you've already used.
- An optional **schedule section** — toggle *Add to Schedule*, pick a time range and color — so you can capture and time-block in one step.
- Tags are normalized automatically (trimmed, lowercased, de-duplicated).
- Tapping a scheduled block opens a **read-only** detail view with the time range and completion status.

### Settings

Open **Settings** from the sidebar gear:

- **General → Day Time Range** — set the schedule grid's start (0:00–20:00) and end (4:00–24:00) hours. The day must span **at least 4 hours**; the choice persists across launches.
- **Backup** — **Export** all data to a versioned JSON file, or **Import** a backup (a **replace-all** restore, behind a confirmation). Malformed or wrong-version files are rejected with a clear message.
- **Clear Data** — permanently delete every task, schedule entry, and backlog item (behind a confirmation). **Your settings, like the day range, are preserved.**
- **Notifications** — placeholder section (no settings yet).

### Data safety & resilience

- The schema is **versioned** with a migration seam, so future updates migrate your data instead of discarding it.

---

## Keyboard shortcuts

Custom shortcuts defined in the app:

| Shortcut | Action                                           | Where                              |
| -------- | ------------------------------------------------ | ---------------------------------- |
| **⌘1**   | Go to Today                                      | Anywhere                           |
| **⌘2**   | Go to Tasks                                      | Anywhere                           |
| **⌘3**   | Go to Backlog                                    | Anywhere                           |
| **⌘B**   | Show / hide the sidebar                          | Anywhere                           |
| **⌘N**   | New brain-dump task (opens the *New Task* sheet) | Today, on editable (non-past) days |
| **⌘N**   | New backlog task                                 | Backlog screen                     |


Standard macOS shortcuts also apply via the system menu bar: **⌘Q** quit, **⌘W** close window, **⌘M** minimize, **⌘H** hide.

### Gestures & drag-and-drop

| Gesture                                       | Action                                         |
| --------------------------------------------- | ---------------------------------------------- |
| **Drag** a brain-dump row → **schedule slot** | Open the Time Block sheet to time-block it     |
| **Drag** a brain-dump row → **Top-3 slot**    | Promote it to a priority (swap prompt if full) |
| **Drag** a priority → **another slot**        | Reorder / swap priorities                      |
| **Drag** a priority → **brain-dump area**     | Demote it back to the brain dump               |
| **Click** a task row                          | Expand its notes (if any)                      |
| **Click** a schedule block                    | Open its read-only detail                      |
| **Click** the date header                     | Open the month calendar                        |
| **Hover** a row / block                       | Reveal edit / delete / complete actions        |

---

## Requirements

- **macOS 14 (Sonoma) or later**

## Build & run

Day-to-day development happens in Xcode:

```bash
xed BrainDump.xcodeproj      # open in Xcode; ⌘R builds, runs, and debugs the app
```

Headless build + launch, or package a distributable DMG:

```bash
./scripts/run-app.sh                 # xcodebuild build + open BrainDump.app
CONFIG=Release ./scripts/run-app.sh  # Release build
./scripts/build-dmg.sh               # Release .app → unsigned .dmg (needs: brew install create-dmg)
```

The `BrainDumpKit` library and its tests build with SwiftPM:

```bash
swift build                  # build BrainDumpKit
swift test                   # run all tests
swift test --filter <name>   # run a single test (substring match on the @Test name)
```

> Releases are produced by the GitHub Actions workflow on `v*` tags, which runs the tests and publishes an **unsigned universal `.dmg`**. Because it's unsigned, first launch needs a right-click → **Open** (or *System Settings → Privacy & Security*) to get past Gatekeeper.

---

## Privacy

Brain Dump is **fully local**. There is no account, no sync, and no network access — your data stays in the on-disk store and in any JSON backups you export yourself.
