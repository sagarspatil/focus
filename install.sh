#!/bin/bash

# FocusSession.spoon Installation Script
# Installs the FocusSession Hammerspoon Spoon

set -e

SPOON_NAME="FocusSession"
SPOON_DIR="${SPOON_NAME}.spoon"
HAMMERSPOON_SPOONS_DIR="$HOME/.hammerspoon/Spoons"
HAMMERSPOON_CONFIG="$HOME/.hammerspoon/init.lua"

echo "🎯 FocusSession Installation Script"
echo "=================================="

# Check if Hammerspoon is installed
if ! command -v hs &> /dev/null; then
    echo "❌ Hammerspoon not found. Please install Hammerspoon first:"
    echo "   https://www.hammerspoon.org/"
    exit 1
fi

echo "✅ Hammerspoon found"

# Create Hammerspoon directories if they don't exist
mkdir -p "$HAMMERSPOON_SPOONS_DIR"
echo "📁 Created Hammerspoon Spoons directory"

# Copy the Spoon
if [ -d "$SPOON_DIR" ]; then
    echo "📦 Installing FocusSession.spoon..."
    cp -r "$SPOON_DIR" "$HAMMERSPOON_SPOONS_DIR/"
    echo "✅ FocusSession.spoon installed to $HAMMERSPOON_SPOONS_DIR"
else
    echo "❌ FocusSession.spoon directory not found in current directory"
    exit 1
fi

# Check if init.lua exists and add FocusSession if needed
if [ ! -f "$HAMMERSPOON_CONFIG" ]; then
    echo "📝 Creating Hammerspoon configuration..."
    cat > "$HAMMERSPOON_CONFIG" << 'EOF'
-- Hammerspoon Configuration
-- Load FocusSession Spoon
local focusSession = hs.loadSpoon("FocusSession")
focusSession:start()
EOF
    echo "✅ Created new Hammerspoon configuration"
else
    # Check if FocusSession is already configured
    if grep -q "FocusSession" "$HAMMERSPOON_CONFIG"; then
        echo "⚠️  FocusSession already configured in init.lua"
    else
        echo "📝 Adding FocusSession to existing configuration..."
        cat >> "$HAMMERSPOON_CONFIG" << 'EOF'

-- FocusSession Spoon
local focusSession = hs.loadSpoon("FocusSession")
focusSession:start()
EOF
        echo "✅ Added FocusSession to existing configuration"
    fi
fi

# Reload Hammerspoon configuration
echo "🔄 Reloading Hammerspoon configuration..."
hs -c "hs.reload()"

echo ""
echo "🎉 Installation complete!"
echo ""
echo "Next steps:"
echo "1. Grant Accessibility permissions to Hammerspoon:"
echo "   System Preferences → Security & Privacy → Privacy → Accessibility"
echo "   Add Hammerspoon and enable it"
echo ""
echo "2. Test the installation:"
echo "   Press ⌥⌘T to start your first focus session"
echo ""
echo "Hotkeys:"
echo "  ⌥⌘T     - Start new focus session"
echo "  ⌥⌘⌃Q    - Abort current session"
echo "  ⌥⌘1     - Quick 25-minute session"
echo "  ⌥⌘2     - Quick 30-minute session"
echo "  ⌥⌘3     - Quick 45-minute session"
echo "  ⌥⌘S     - Show session status"
echo ""
echo "Your focus session data will be logged to:"
echo "  ~/FocusSessions.csv"
echo ""
echo "Happy focusing! 🎯"

# Open Accessibility preferences if needed
echo ""
read -p "Open Accessibility preferences now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
fi
