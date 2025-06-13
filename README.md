# FocusSession.spoon

A Hammerspoon Spoon for focused work sessions with escalating nudges to keep you on task.

## Features

- 🎯 **Always-visible timer** - Floating overlay shows current task and countdown
- ⏱️ **30/15/10 minute workflow** - Initial 30 min, 15 min extension, 10 min grace period
- 🔔 **Escalating nudges** - Visual pulses that increase in frequency over time
- 🔒 **Screen lock enforcement** - Automatically locks screen if you don't finish
- 📊 **Session logging** - All sessions saved to CSV for analysis
- ⌨️ **Global hotkeys** - Start sessions without switching apps
- 🚫 **Distraction prevention** - Forces you to commit to finishing or face consequences

## Installation

1. **Install Hammerspoon** (if not already installed):
   ```bash
   brew install hammerspoon
   ```

2. **Run the installer**:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Grant Accessibility permissions**:
   - Open System Preferences → Security & Privacy → Privacy → Accessibility
   - Add Hammerspoon and enable it

4. **Test the installation**:
   - Press `⌥⌘T` to start your first focus session

## Usage

### Starting a Session

Press `⌥⌘T` and you'll be prompted to:
1. Enter what task you're working on
2. Select how long you plan to work (25/30/45/60/90 minutes)

### During the Session

- A floating timer appears in the top-right corner showing your task and remaining time
- Every 5 minutes, the overlay will pulse to remind you to stay focused
- When time runs out, you'll get a dialog asking if you're finished

### Session Flow

1. **Initial Period** (your chosen duration)
   - Timer counts down
   - Gentle pulse every 5 minutes
   - At the end: "Finished?" dialog

2. **Extension** (if you choose "+15 min")
   - Additional 15 minutes
   - More frequent pulses (every 3 minutes)
   - Orange overlay color

3. **Grace Period** (if extension expires)
   - Final 10 minutes
   - Red overlay color
   - Intense red screen flashes every minute

4. **Final Choice**
   - "Finished" → Session ends successfully
   - "Not Finished" → Screen locks immediately

### Hotkeys

- `⌥⌘T` - Start new focus session
- `⌥⌘⌃Q` - Abort current session
- `⌥⌘1` - Quick 25-minute session
- `⌥⌘2` - Quick 30-minute session  
- `⌥⌘3` - Quick 45-minute session
- `⌥⌘S` - Show current session status

## Session Data

All sessions are automatically logged to `~/FocusSessions.csv` with the format:

```csv
timestamp_start,timestamp_end,task,planned_min,actual_min,outcome
2025-06-13T09:02:00,2025-06-13T09:35:00,Spec draft,30,33,completed
```

You can import this data into Excel, Google Sheets, or any analytics tool to track your focus patterns.

## Configuration

The configuration is stored in `FocusSession.spoon/config.json`. You can modify:

- Hotkey combinations
- Colors and UI appearance
- Flash intervals
- CSV file location
- Default session durations

## Requirements

- macOS 15.2+
- Hammerspoon
- Accessibility permissions

## Architecture

The app is built with a modular architecture:

- **SessionController** - Main state machine managing session flow
- **UIOverlay** - Floating timer display using hs.canvas
- **TimerEngine** - Countdown and flash timing management
- **PromptDialog** - User input dialogs using AppleScript
- **SystemActions** - Screen lock and system integration
- **Logger** - CSV data persistence
- **HotkeyBinder** - Global keyboard shortcuts

## Troubleshooting

### "No response from dialog"
- Grant Accessibility permissions to Hammerspoon
- Restart Hammerspoon after granting permissions

### "Screen lock not working" 
- The app uses `pmset displaysleepnow` which requires password after sleep
- Configure this in System Preferences → Security & Privacy

### "Timer not visible"
- Check if Hammerspoon has Screen Recording permissions
- Try restarting the session with `⌥⌘⌃Q` then `⌥⌘T`

## Philosophy

This tool implements "commitment with consequences" - you can extend once, but after that you must either finish or face screen lock. This creates the right incentives to:

1. Plan realistic session lengths
2. Stay focused during work
3. Build better time estimation skills
4. Reduce context switching

The escalating visual cues help maintain awareness without being overly disruptive.

## Contributing

Feel free to submit issues and feature requests. The modular architecture makes it easy to extend functionality.

## License

MIT License - feel free to modify and distribute.
