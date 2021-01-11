#!/usr/bin/sh
echo "Installing Xorg..."
echo | pacman --needed -S xorg xorg-server mesa

# Video drivers for AMD:
echo "Installing AMD GPU drivers..."
echo | pacman --needed -S xf86-video-amdgpu xf86-video-vesa
#Alternatively, for Intel:
#echo "Installing Intel GPU drivers"
#echo | pacman --needed -S xf86-video-intel

# Alternatively, for NVIDIA (proprietary):
#echo "Installing proprietary GPU drivers for NVIDIA..."
#pacman --needed -S xorg xorg-server nvidia nvidia-utils 

# Or (open-source):
#echo "Installing open-source GPU drivers for NVIDIA..."
#pacman --needed -S xorg xorg-server xf86-video-nouveau mesa

# More GUI stuffs
echo "Installing i3wm and other needed tools (dmenu, feh, picom)..."
(echo; echo)| pacman --needed -S i3 dmenu feh picom

# Browser and terminal emulator
[[ -z $TERMINAL ]] || declare TERMINAL="alacritty"
[[ -z $BROWSER ]] || declare BROWSER="firefox"

echo "Installing $BROWSER and $TERMINAL..."
echo | pacman --needed -S $BROWSER $TERMINAL
