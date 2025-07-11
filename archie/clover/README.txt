NOTE: Stow cannot copy files, only create symbolic links
      As Clovers EFI configuration is needed before the stow partition is even mounted 
      a symbolic link will not work.
      Therefore this stow package does not install any files,
      the files are here so as to be under version control


Use Clover to boot Windows and multiple Linux variants

https://github.com/CloverHackyColor/CloverBootloader
https://wiki.archlinux.org/title/Clover

To support multiple Linux variants we do things slightly differently...

Mount EFI partition as /efi

Create a directory for each Linux variant required under /boot
/boot/arch
/boot/lfs
/boot/...

# /etc/fstab
# EFI Partition
UUID=xxxx-xxxx      	/efi     	vfat      	rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro	0 2

Bind mount /efi/boot/<This Linux Variant> to /boot as this is where Linux likes to put the kernel

So for my Arch install I have
# EFI Kernel goes in /boot
/efi/boot/arch	/boot	none	bind

For lfs I have
# EFI Kernel goes in /boot
/efi/boot/lfs   /boot   none   bind

All kernels must be EFI boot stubs, Arch does this by default.  Not worked out lfs yet ...


The Clover config file config.plist can have separate entries for

Arch
initrd=\boot\arch\amd-ucode.img initrd=\boot\arch\initramfs-linux.img root=UUID=.... rw add_efi_memmap

And lfs
initrd=\boot\lfs\amd-ucode.img initrd=\boot\lfs\initramfs-linux.img root=UUID=.... rw add_efi_memmap

Once Clover is installed, the boot directories set up and the mounts configured, the Clover configuration file config.plist must be copied to /efi/EFI/Clover/

Reboot and hopefully things will work ... !!!
