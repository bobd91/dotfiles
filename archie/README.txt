For packages that do not live under the user home directory


Some will need 'sudo stow ...' to install/remove 

keyd   - key mapping, config has to be in /etc/keyd
local - /usr/local


Some cannot be installed with stow but are kept here for source control

clover - EFI boot manager (stow dir not mounted when clover runs)
stow - patch Stow.pm to allow absolute symlinks (stow stowing stow is asking for trouble)
