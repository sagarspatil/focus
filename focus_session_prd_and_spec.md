## 1. Product Requirements Document (PRD)

| Field             | Description                                                                                                          |
| ----------------- | -------------------------------------------------------------------------------------------------------------------- |
| **Document owner**| Sagar                                                                                                                |
| **Last update**   | 13 Jun 2025                                                                                                          |
| **Purpose**       | Keep the user locked on a single self-declared task, reduce unplanned Reddit/X browsing, and enforce short review loops (30 min + 15 min + 10 min). |
| **Primary persona** | Individual contributor or indie founder who works alone on a Mac and drifts into time-wasting sites.               |
| **Success metrics** | (a) Daily average Reddit + X time < 1 hour, measured by ScreenTime; (b) ≥ 80% of sessions marked “Finished” inside the first 30 minutes during the first 14 days; (c) self-reported focus score improves from baseline. |
| **Out of scope**  | Cross-device sync, ScreenTime configuration, gamification, streak tracking.                                          |
| **Key assumptions** | macOS 15.2, full Accessibility permission granted, no corporate MDM restrictions.                                   |

### Core user story

> As a distracted professional I want a floating, always-visible timer and escalating nudges so that I stick to one task and notice when the session is over.

### Functional requirements (high-level)

| #   | Requirement                                                                                  |
| --- | -------------------------------------------------------------------------------------------- |
| FR-1| User can start a **Focus Session** by providing *task name* and *planned minutes*.          |
| FR-2| Task name and live countdown float above all windows.                                        |
| FR-3| During the initial 30 min, the overlay flashes or pulses every 5 min.                        |
| FR-4| When the 30 min expire, a modal asks **Finished?** with buttons **Yes** or **+15 min**.      |
| FR-5| Extension period lasts 15 min and flashes every 3 min.                                       |
| FR-6| After extension ends, grant 10 min grace; if unanswered, full-screen red flash every 1 min.  |
| FR-7| If the user finally answers **Not finished**, the Mac is locked (display sleeps).           |
| FR-8| Overlay and timers must pause while the lock screen is active and resume on unlock.          |
| FR-9| Session log (start, end, outcome, total minutes) is appended to `~/FocusSessions.csv`.       |

### Non-functional & UX constraints

- Overlay must consume less than 2% CPU on an M-series Mac mini.  
- No em-dash characters in UI strings (government requirement).  
- Single-key global hotkey (⌥⌘T by default) starts a new session quickly.  
- Installer should require no Xcode – copy a folder to `~/.hammerspoon` and reload.  

### Open questions

1. Should “planned minutes” be free-form or limited to presets (25/30/45)?  
2. Should we auto-enable Do Not Disturb while any session is active?  
3. Is CSV logging enough, or do we need a daily summary notification?  

---

## 2. Technical specification for development

### 2.1 Architectural choice

| Requirement                     | Candidate                 | Decision  | Why                                                                     |
| ------------------------------- | ------------------------- | --------- | ----------------------------------------------------------------------- |
| Floating overlay & custom drawing | Hammerspoon (`hs.canvas`, `hs.drawing`) | Chosen   | Native Lua scripting, easy to draw text rectangles that stay on top.    |
| Periodic callbacks              | `hs.timer`                | Chosen   | Simple `hs.timer.doEvery` for fixed-interval tasks.                     |
| Modal prompts                   | `hs.dialog.choice`        | Chosen   | Provides Cocoa alert with custom buttons via Lua, no extra dependency. |
| Screen flash/red overlay        | `hs.canvas` full-screen rectangle | Chosen | Avoids external tools; easy to toggle visibility.                      |
| Lock / hard stop                | Shell call `pmset displaysleepnow` | Chosen | Works since macOS 10.9 and respects “require password after sleep”.     |
| Data persistence                | Lua `io.append` to local CSV | Chosen | Zero external libraries, human-readable, trivial for later import.      |
| Packaging                       | Hammerspoon Spoon         | Chosen   | Single-folder distribution, drop into `~/.hammerspoon/Spoons`.          |

### 2.2 Module breakdown

| Module            | Key files / objects      | Responsibilities                                                                 | Depends on                        |
| ----------------- | ------------------------ | ------------------------------------------------------------------------------- | --------------------------------- |
| SessionController | `FocusSession.lua`       | State machine (Idle → Active → Extension → Grace → Escalate → End). Holds task name, timers, start time. | TimerEngine, UIOverlay, PromptDialog, SystemActions, Logger |
| UIOverlay         | `Overlay.lua`            | Draws floating box with task name and countdown. Provides `pulse()` for flashes. | Hammerspoon canvas                |
| TimerEngine       | `Timers.lua`             | Manages all `hs.timer` objects. Emits events to SessionController.             |                                    |
| PromptDialog      | `Prompt.lua`             | Shows modal with Yes / Extend; returns user choice via callback.               |                                    |
| SystemActions     | `Actions.lua`            | `lockScreen()`, (future: `focusMode(enable)`, `playSound(name)`).               |                                    |
| Logger            | `Logger.lua`             | `append(recordTable)` to `~/FocusSessions.csv`.                                 |                                    |
| HotkeyBinder      | `Hotkey.lua`             | Binds ⌥⌘T to `SessionController.start()` and ⌥⌘⌃Q to `SessionController.abort()`.  |                                    |
| Config            | `config.json`            | User-editable: colors, flash interval, CSV path, hotkeys. Loaded on init.      |                                    |
| Installer script  | `install.sh`             | Copies Spoon, opens Accessibility pane for user permission grant.               |                                    |

### 2.3 Sequence diagram (happy path)

1. Hotkey pressed → `SessionController.start(task, minutes)`.  
2. UIOverlay `show()` with countdown.  
3. TimerEngine sets:  
   - `flashTimer` every 300 s for first phase.  
   - `countdownTimer` every 60 s to update overlay.  
4. After 30 min `countdownTimer` hits zero → PromptDialog shows.  
5. If **Yes** → SessionController `finish("completed")`.  
6. If **Extend** → switch to extension profile (15 min, flash every 180 s).  
7. Extension ends → start grace timer (10 min); flashes escalate to 60 s red screen.  
8. Final prompt → if **Not finished** → SystemActions.lockScreen(); SessionController `finish("interrupted")`.  
9. Logger writes a CSV row.

### 2.4 Data schema (`FocusSessions.csv`)

timestamp_start,timestamp_end,task,planned_min,actual_min,outcome
2025-06-13T09:02:00,2025-06-13T09:35:00,Spec draft,30,33,completed

### 2.5 Error handling

- If Hammerspoon loses Accessibility privileges, SessionController aborts and shows an `hs.notify` alert.  
- If `pmset displaysleepnow` fails, fallback to `open /System/Library/CoreServices/ScreenSaverEngine.app`.

### 2.6 Security and privacy

- No network calls.  
- All session data stored locally.  
- Accessibility permission required only for overlay stacking; no key logging.  