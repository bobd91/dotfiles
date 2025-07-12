# A change to stow disallowing absolute symlinks means our default apps in /usr/local/bin
# cannot be stowed.
# This affected many other people but it has not been fixed so
# this patch fixes the problem
# See https://github.com/ChilliEaster/stow-absolute-links

sudo patch /usr/share/perl5/vendor_perl/Stow.pm 0001-remove-absolute-link-restriction.patch
