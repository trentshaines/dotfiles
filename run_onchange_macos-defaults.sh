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

