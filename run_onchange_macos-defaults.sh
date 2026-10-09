#!/bin/bash
# macOS defaults - managed by chezmoi
# To update: change values here, then run `chezmoi apply`

###############################################################################
# Dock
###############################################################################

defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock orientation -string "left"
defaults write com.apple.dock tilesize -int 16

# Hot corners: bottom-right = Quick Note (14)
defaults write com.apple.dock wvous-br-corner -int 14

###############################################################################
# Scroll & Trackpad
###############################################################################

# Natural scrolling OFF (0 = standard, 1 = natural)
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

###############################################################################
# Finder
###############################################################################

defaults write com.apple.finder ShowSidebar -bool true
defaults write com.apple.finder SidebarWidth -int 256

# Show these on desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false


# List view by default
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

###############################################################################
# Gestures & windows
###############################################################################

# Two-finger swipe between pages: OFF
defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false

# Native window tiling: no gaps between tiled windows (AeroSpace does tiling)
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false

###############################################################################
# Keyboard shortcuts: Cmd-Space = Raycast, Option-Space = Spotlight
###############################################################################

# Symbolic hotkey 64 = "Show Spotlight search"; params = (char 32, keycode 49 Space, 524288 Option)
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 \
  "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true

# Raycast rewrites its plist on quit, so only set this while it is not running.
if [ -d /Applications/Raycast.app ] && ! pgrep -xq Raycast; then
  defaults write com.raycast.macos raycastGlobalHotkey -string "Command-49"
fi

###############################################################################
# Login items (apps must already be installed; first run asks to allow
# automation of System Events)
###############################################################################

for app in Raycast AeroSpace Granola Notion; do
  [ -d "/Applications/$app.app" ] || continue
  osascript -e "tell application \"System Events\" to if not (exists login item \"$app\") then make login item at end with properties {path:\"/Applications/$app.app\", hidden:false}" >/dev/null 2>&1 || true
done

killall Dock Finder 2>/dev/null || true
