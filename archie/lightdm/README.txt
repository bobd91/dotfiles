All sorts of permissions problem with lightdm greeter complaining 
about access to .conf files and background .pngs
Best to copy files into place as root, that seems to work

sudo cp lightdm* /etc/lightdm
sudo cp arch-desktop* /usr/share/backgrounds
