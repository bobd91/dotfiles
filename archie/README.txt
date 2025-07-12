For packages that do not live under the user home directory


Some will need 'sudo stow ...' to install/remove 

keyd   - key mapping, config has to be in /etc/keyd
local - /usr/local/bin default terminal/browser/vi links

-------

Some cannot be installed with stow but are kept here for source control,
see package README.txt files for further information

clover - EFI boot manager (this file system is not mounted when clover runs)
stow - patch Stow.pm to allow absolute symlinks (stow stowing stow is asking for trouble)
lightdm - Light Display Manager, file permission problems with linked files
