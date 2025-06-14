# FocusSession.spoon Documentation

## Purpose

FocusSession.spoon is a Hammerspoon Spoon designed to help users maintain focus on a single task and reduce distractions. It enforces a structured work session with escalating nudges and consequences for not completing the task within the allocated time. The primary goal is to minimize time spent on distracting websites and improve productivity through short, focused work intervals.

## Features

- **Always-visible timer**: A floating overlay displays the current task and a countdown timer, keeping the user aware of the time remaining.
- **Structured workflow**: The session follows a 30/15/10 minute workflow, starting with an initial 30-minute focus period, followed by an optional 15-minute extension, and a final 10-minute grace period.
- **Escalating nudges**: Visual cues, such as pulses and screen flashes, increase in frequency as the session progresses to remind the user to stay on task.
- **Screen lock enforcement**: If the task is not completed by the end of the session, the screen automatically locks, creating a clear consequence for not finishing.
- **Session logging**: All focus sessions are logged to a CSV file (`~/FocusSessions.csv`), allowing users to track their work patterns and analyze their productivity.
- **Global hotkeys**: Users can start, abort, and manage sessions using global hotkeys, eliminating the need to switch applications.
- **Distraction prevention**: The tool encourages commitment to the current task by enforcing consequences if the user indicates they have not finished their work.
- **Configurable settings**: Users can customize hotkeys, UI appearance, flash intervals, CSV file location, and default session durations via a `config.json` file.

## Installation

1. **Install Hammerspoon**: If you don't have Hammerspoon installed, you can install it using Homebrew:
   ```bash
   brew install hammerspoon
   ```

2. **Run the installer**: Execute the installer script to set up FocusSession.spoon:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Grant Accessibility permissions**: For FocusSession.spoon to function correctly, you need to grant Accessibility permissions to Hammerspoon:
   - Open System Preferences → Security & Privacy → Privacy → Accessibility.
   - Add Hammerspoon to the list and ensure it is checked.

4. **Test the installation**: You can test if the installation was successful by starting your first focus session. Press `⌥⌘T`.

## Usage and Session Flow

### Starting a Session

To start a new focus session, press `⌥⌘T`. You will be prompted to:
1. Enter the task you are working on.
2. Select the planned duration for your session (options typically include 25, 30, 45, 60, or 90 minutes).

### During the Session

- A floating timer will appear in the top-right corner of your screen, displaying your current task and the remaining time.
- The overlay will pulse every 5 minutes as a gentle reminder to stay focused.
- When the initial time runs out, a dialog will appear asking if you have finished your task.

### Session Flow Stages

The session progresses through the following stages:

1.  **Initial Period**:
    *   This is the duration you selected when starting the session.
    *   The timer counts down.
    *   A gentle pulse occurs every 5 minutes.
    *   At the end of this period, a "Finished?" dialog appears.

2.  **Extension**:
    *   If you choose "+15 min" in the "Finished?" dialog, an additional 15 minutes are added to your session.
    *   Pulses become more frequent (e.g., every 3 minutes).
    *   The overlay color may change (e.g., to orange) to indicate the extension period.

3.  **Grace Period**:
    *   If the extension period expires and you haven't finished, a final 10-minute grace period begins.
    *   The overlay color may change again (e.g., to red).
    *   Nudges become more intense, such as red screen flashes every minute.

4.  **Final Choice**:
    *   At the end of the grace period (or if you end the session sooner), you make a final choice.
    *   If you select "Finished", the session ends successfully.
    *   If you select "Not Finished", your screen will lock immediately.

### Hotkeys

The following global hotkeys are available to manage your focus sessions:

-   `⌥⌘T`: Start a new focus session.
-   `⌥⌘⌃Q`: Abort the current session.
-   `⌥⌘1`: Start a quick 25-minute session.
-   `⌥⌘2`: Start a quick 30-minute session.
-   `⌥⌘3`: Start a quick 45-minute session.
-   `⌥⌘S`: Show the status of the current session.

## Architecture and Modules

FocusSession.spoon is built with a modular architecture, primarily utilizing Hammerspoon's capabilities. The key components are:

-   **SessionController (`FocusSession.lua`)**: This is the core module that manages the overall session flow. It acts as a state machine, transitioning through states like Idle, Active, Extension, Grace Period, and End. It holds session-specific information such as the task name, timers, and start time. It coordinates the actions of other modules like `TimerEngine`, `UIOverlay`, `PromptDialog`, `SystemActions`, and `Logger`.

-   **UIOverlay (`Overlay.lua`)**: Responsible for displaying the floating timer and task name on the screen. It uses `hs.canvas` to draw the overlay, which remains visible above other windows. It also provides a `pulse()` method for visual nudges.

-   **TimerEngine (`Timers.lua`)**: Manages all timer-related functionalities using `hs.timer`. It handles the countdown logic and triggers events for flashes or pulses, communicating these events to the `SessionController`.

-   **PromptDialog (`Prompt.lua`)**: Handles user interactions through modal dialogs. For example, it displays the "Finished?" dialog with options like "Yes" or "+15 min", and returns the user's choice to the `SessionController`. It uses AppleScript for these dialogs.

-   **SystemActions (`Actions.lua`)**: Performs system-level actions, most notably locking the screen (`lockScreen()`) if a session is not completed. It might also handle future actions like enabling a focus mode or playing sounds.

-   **Logger (`Logger.lua`)**: Responsible for data persistence. It appends a record of each session (including start time, end time, task, planned minutes, actual minutes, and outcome) to a CSV file, typically `~/FocusSessions.csv`.

-   **HotkeyBinder (`Hotkey.lua`)**: Manages the global keyboard shortcuts. It binds specific hotkeys (e.g., `⌥⌘T`) to actions within the `SessionController`, such as starting or aborting a session.

-   **Config (`config.json`)**: A JSON file where users can customize various settings. This includes hotkey combinations, UI appearance (colors), flash/pulse intervals, the path to the CSV log file, and default session durations. This file is loaded at initialization.

-   **Installer script (`install.sh`)**: A shell script that facilitates the installation process. It copies the Spoon files to the appropriate Hammerspoon directory (e.g., `~/.hammerspoon/Spoons`) and may guide the user in granting necessary permissions like Accessibility.

## Configuration

FocusSession.spoon allows users to customize its behavior through a configuration file. This file is typically located at `FocusSession.spoon/config.json` (within your Hammerspoon Spoons directory, e.g., `~/.hammerspoon/Spoons/FocusSession.spoon/config.json`).

You can modify the following settings in the `config.json` file:

-   **Hotkey combinations**: Change the default keyboard shortcuts for actions like starting a new session, aborting a session, or starting quick sessions.
-   **Colors and UI appearance**: Customize the colors of the floating overlay, text, and visual nudges (pulses/flashes) to suit your preferences.
-   **Flash intervals**: Adjust the frequency of visual nudges during the initial session, extension period, and grace period.
-   **CSV file location**: Specify a different path or filename for the session log file if you don't want to use the default `~/FocusSessions.csv`.
-   **Default session durations**: Modify the preset durations available for quick sessions or the standard session length options.

To apply any changes made to `config.json`, you will typically need to reload your Hammerspoon configuration.

## Data Logging

FocusSession.spoon automatically logs all focus sessions to a CSV (Comma Separated Values) file. This allows you to track your work habits, analyze your focus patterns, and see how your time is spent.

**File Location**:
By default, the session data is saved in your home directory at `~/FocusSessions.csv`. This location can be changed in the `config.json` file (see the Configuration section).

**Data Format**:
Each row in the CSV file represents a single focus session and contains the following columns:

-   `timestamp_start`: The date and time when the session started (e.g., `2025-06-13T09:02:00`).
-   `timestamp_end`: The date and time when the session ended.
-   `task`: The name of the task you entered when starting the session.
-   `planned_min`: The initial duration (in minutes) you planned for the session.
-   `actual_min`: The total actual duration (in minutes) of the session, including any extensions.
-   `outcome`: The result of the session (e.g., `completed`, `interrupted`, `aborted`).

**Example Row**:
```csv
timestamp_start,timestamp_end,task,planned_min,actual_min,outcome
2025-06-13T09:02:00,2025-06-13T09:35:00,Spec draft,30,33,completed
```

This data can be easily imported into spreadsheet software like Microsoft Excel, Google Sheets, Apple Numbers, or any data analysis tool for further review and visualization of your focus history.
