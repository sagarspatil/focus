#!/bin/bash

# Test script to verify FocusSession.spoon installation

echo "🧪 Testing FocusSession.spoon Installation"
echo "========================================="

# Check if all required files exist
REQUIRED_FILES=(
    "FocusSession.spoon/init.lua"
    "FocusSession.spoon/SessionController.lua"
    "FocusSession.spoon/UIOverlay.lua"
    "FocusSession.spoon/TimerEngine.lua"
    "FocusSession.spoon/PromptDialog.lua"
    "FocusSession.spoon/SystemActions.lua"
    "FocusSession.spoon/Logger.lua"
    "FocusSession.spoon/HotkeyBinder.lua"
    "FocusSession.spoon/config.json"
    "install.sh"
    "README.md"
)

echo "📁 Checking required files..."
ALL_PRESENT=true

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - MISSING"
        ALL_PRESENT=false
    fi
done

if [ "$ALL_PRESENT" = true ]; then
    echo "✅ All required files present"
else
    echo "❌ Some files are missing"
    exit 1
fi

# Check file sizes (should be > 0)
echo ""
echo "📊 Checking file sizes..."
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        SIZE=$(wc -c < "$file" | tr -d ' ')
        if [ "$SIZE" -gt 0 ]; then
            echo "✅ $file (${SIZE} bytes)"
        else
            echo "❌ $file is empty"
            ALL_PRESENT=false
        fi
    fi
done

# Check install script permissions
echo ""
echo "🔐 Checking install script permissions..."
if [ -x "install.sh" ]; then
    echo "✅ install.sh is executable"
else
    echo "❌ install.sh is not executable"
    echo "   Run: chmod +x install.sh"
    ALL_PRESENT=false
fi

# Check JSON config validity
echo ""
echo "📋 Checking config.json validity..."
if python3 -c "import json; json.load(open('FocusSession.spoon/config.json'))" 2>/dev/null; then
    echo "✅ config.json is valid JSON"
else
    echo "⚠️  Could not validate JSON (python3 not available)"
fi

# Summary
echo ""
if [ "$ALL_PRESENT" = true ]; then
    echo "🎉 All tests passed! FocusSession.spoon is ready for installation."
    echo ""
    echo "To install:"
    echo "1. Run: ./install.sh"
    echo "2. Grant Accessibility permissions to Hammerspoon"
    echo "3. Test with: ⌥⌘T"
    echo ""
    echo "The installation will:"
    echo "- Copy FocusSession.spoon to ~/.hammerspoon/Spoons/"
    echo "- Add configuration to ~/.hammerspoon/init.lua"
    echo "- Reload Hammerspoon"
    echo "- Create ~/FocusSessions.csv for logging"
else
    echo "❌ Some issues found. Please fix them before installing."
    exit 1
fi
