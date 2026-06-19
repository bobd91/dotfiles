For packages that do not live under the user home directory


Some will need 'sudo stow ...' to install/remove 

keyd  - /etc/keyd config
local - /usr/local/bin default terminal/browser/vi links
x11   - /etc/X11/xorg.conf.d/00-keyboard.conf for gb keyboard
alsa  - /etc/modprobe.d/alsa_base.conf for usb audio as default

-------

Some cannot be installed with stow but are kept here for source control,
see package README.txt files for further information

clover - EFI boot manager (this file system is not mounted when clover runs)
stow - patch Stow.pm to allow absolute symlinks (stow stowing stow is asking for trouble)
lightdm - Light Display Manager, file permission problems with linked files
