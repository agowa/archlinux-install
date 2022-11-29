# Install ARCH Linux with encrypted file-system and UEFI
# The official installation guide (https://wiki.archlinux.org/index.php/Installation_Guide) contains a more verbose description.

# Download the archiso image from https://www.archlinux.org/
# Copy to a usb-drive
dd if=archlinux.img | dd of=/dev/sdX bs=16M; sync # on linux

# Boot from the usb. If the usb fails to boot, make sure that secure boot is disabled in the BIOS configuration.

# To boot the pxe image within an iPXE environment you first need to press CTRL+B and look at the header.
# If the header only contains HTTP but not HTTPS you'll need to download the official pxe image and upload it to
# a http server (or to another server where you can host an ad-hoc temporary python3 web server)
# For that just download the pxe file from https://archlinux.org/releng/netboot/ into an empty directory
# rename it to `ipxe.pxe` and run `python3 -m http.server -d /path/to/the/directory/`
# After that run these commands within the iPXE shell to boot it:
#dhcp
#chain http://your-server.example.com:8000/ipxe.pxe

# Set german keymap
#loadkeys de-latin1

# This assumes a wifi only system...
wifi-menu

# Create partitions GPT
cgdisk /dev/sda
# For grub (legacy way):
# 1 100MB EFI partition # Hex code ef00
# 2 250MB Boot partition # Hex code ef02
# 3 100% size partiton # (to be encrypted) Hex code 8309
#
# For systemd-boot (default for rest of this):
# 1 350MB Boot partition # Hex code ef00
# 2 100% size partiton # (to be encrypted) Hex code 8309
#
# List of partition types: https://wiki.archlinux.org/title/GPT_fdisk#Partition_type
# 8300: Linux partition (btrfs, ext4, ...)
# ef00: EFI boot partition (FAT32)
# ef02: BIOS boot parition
# 8309: LUKS/Cryptsetup encrypted partition
# 8e00: LVM partition
# 8200: swap
# 8304: root partition

# Create partitions on MBR (should not be needed in most cases)
# later steps in this tutorial do not fully cover installing on MBR and may not fully apply.
# Use fdisk to create a partition layout and use one of these two partition setups:
# a)
# 1 350M Boot partition
# 2 100% size partition # (to be encrypted) Hex code 8309

mkfs.vfat -F32 /dev/sda1
# For grub also: mkfs.ext2 /dev/sda2
# For MBR instead: mkfs.ext4 /dev/sda1

# Setup the encryption of the system
# cryptsetup benchmark
# If you want a key file use `dd if=/dev/urandom of=/boot/keyfile bs=1024 count=4` to generate it.
cryptsetup --cipher aes-xts-plain64 --hash sha512 --iter-time 5000 --key-size 512 -y --use-random luksFormat /dev/sda2 # sda3 for setup with grub
cryptsetup luksOpen /dev/sda2 luks # sda3 for setup with grub

# Create encrypted partitions
# This creates one partions for root, modify if /home or other partitions should be on separate partitions
pvcreate /dev/mapper/luks
vgcreate vg0 /dev/mapper/luks
lvcreate --size 8G vg0 --name swap
lvcreate -l +100%FREE vg0 --name root

# Create filesystems on encrypted partitions
mkfs.ext4 /dev/mapper/vg0-root
mkswap /dev/mapper/vg0-swap

# Mount the new system 
mount /dev/mapper/vg0-root /mnt # /mnt is the installed system
swapon /dev/mapper/vg0-swap # Not needed but a good thing to test
mkdir /mnt/boot
# For setup with grub:
# mount /dev/sda2 /mnt/boot
# mkdir /mnt/boot/efi
# mount /dev/sda1 /mnt/boot/efi
#
# For systemd-boot:
mount /dev/sda1 /mnt/boot

# Install the system also includes stuff needed for starting wifi when first booting into the newly installed system
# Unless vim and zsh are desired these can be removed from the command
pacstrap /mnt base base-devel linux-firmware intel-ucode zsh vim nano bash htop net-tools git efibootmgr dialog wpa_supplicant mkinitcpio linux lvm2 # grub-efi-x86_64
# Note: If you get an error with pacman you may need to reset it (only occured within the customized archlinux boot environment of a cloud provider)
#rm -rf /etc/pacman.d/gnupg/* /var/lib/pacman/
#umount /etc/pacman.d/gnupg
#echo 'Server = https://ftp.halifax.rwth-aachen.de/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
#pacman-key --init
#pacman-key --populate
#pacman -S archlinux-keyring
#umount -R /mnt/boot
#rm -rf /mnt/
# And now remount /mnt/boot (and if available /mnt/boot/efi) and rerun pacstrap.

# 'install' fstab
genfstab -pU /mnt >> /mnt/etc/fstab
# Make /tmp a ramdisk (add the following line to /mnt/etc/fstab)
tmpfs	/tmp	tmpfs	defaults,noatime,mode=1777	0	0
# Change relatime on all non-boot partitions to noatime (reduces wear if using an SSD)

# Enter the new system
arch-chroot /mnt /bin/bash

# Setup system clock
rm /etc/localtime
ln -s /usr/share/zoneinfo/UTC /etc/localtime
# If it's a server stick to using UTC for consistent unambiguous timestamps, otherwise
# you may use your local one like:
#ln -s /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc --utc

# Set the hostname
echo MYHOSTNAME > /etc/hostname

# Set DNS-Server
# Copy /etc/systemd/resolved.conf (from this repository) to /etc/systemd/resolved.conf
systemctl enable systemd-resolved.service
rm -f /etc/resolv.conf
# If this throws an "rm: cannot remove '/etc/resolv.conf': Device or resource busy" error run:
#umount /etc/resolv.conf; rm -f /etc/resolv.conf
# and try again.
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Update locale
echo LANG=en_US.UTF-8 >> /etc/locale.conf
echo LANGUAGE=en_US >> /etc/locale.conf
echo LC_ALL=C >> /etc/locale.conf

# Set password for root
passwd

# Configure mkinitcpio with modules needed for the initrd image
vi /etc/mkinitcpio.conf
# Add 'ext4' to MODULES
# Add 'encrypt' and 'lvm2' to HOOKS before filesystems
# Also make sure 'keyboard' is listed somewhere to the left of 'encrypt'

# Regenerate initrd image
mkinitcpio -p linux

# Setup grub
#grub-install
#vi /etc/default/grub # edit the line GRUB_CMDLINE_LINUX to GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda3:luks:allow-discards" then run:
#grub-mkconfig -o /boot/grub/grub.cfg

# Add details for systemd-boot here
bootctl --path=/boot install
# Install systemd-boot-pacman-hook from https://aur.archlinux.org/packages/systemd-boot-pacman-hook/
# to auto update systemd-boot with pacman
git clone https://aur.archlinux.org/systemd-boot-pacman-hook.git
chown -R nobody:nobody ./systemd-boot-pacman-hook
cd ./systemd-boot-pacman-hook
su nobody -s /usr/sbin/makepkg
pacman -U systemd-boot-pacman-hook.*pkg.*
cd ..
rm -rf ./systemd-boot-pacman-hook
# Create bootloader entry
mkdir -p /boot/loader/entries
echo -e 'timeout 0\ndefault arch\neditor no\nauto-entries no\nauto-firmware no\nconsole-mode max' > /boot/loader/loader.conf
# If you're on a legacy system use sda3 instead of sda2 for the following:
echo -e 'title Arch Linux\nlinux /vmlinuz-linux\ninitrd /intel-ucode.img\ninitrd /amd-ucode.img\ninitrd /initramfs-linux.img\noptions root=/dev/mapper/vg0-root rw cryptdevice=/dev/sda2:luks:allow-discards resume=/dev/mapper/vg0-swap systemd.unified_cgroup_hierarchy=1 cgroup_no_v1="all" quiet' > /boot/loader/entries/arch.conf
echo -e 'title Arch Linux\nlinux /vmlinuz-linux\ninitrd /intel-ucode.img\ninitrd /amd-ucode.img\ninitrd /initramfs-linux-fallback.img\noptions root=/dev/mapper/vg0-root rw cryptdevice=/dev/sda2:luks:allow-discards resume=/dev/mapper/vg0-swap systemd.unified_cgroup_hierarchy=1 cgroup_no_v1="all" quiet' > /boot/loader/entries/arch-fallback.conf

# TODO: Add steps for secureboot signing
# TODO: Add steps for selinux support

# Exit new system and go into the cd shell
exit

# Unmount all partitions
umount -R /mnt
swapoff -a

# Reboot into the new system, don't forget to remove the cd/usb
reboot

# Set keyboard layout
#loadkeys de-latin1

# compose: defines the compose key
# terminate: defines the key/combination for killing the xserver
# localectl set-x11-keymap de pc105 de_nodeadkeys terminate:ctrl_alt_bksp,compose:rctrl
localectl set-x11-keymap us pc105+inet "" terminate:ctrl_alt_bksp,compose:rctrl
localectl set-keymap us
localectl status
echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
# echo 'de_DE.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen

# Install packages
pacman -S acpid
pacman -S xorg-server xorg-xinit xorg-drivers xf86-input-synaptics xorg-fonts-75dpi xorg-fonts-100dpi
pacman -S plasma-meta sddm sddm-kcm plasma-wayland-session ttf-dejavu ttf-liberation phonon-qt5-gstreamer phonon-qt5-vlc
pacman -S cups sshfs bash-completion zsh-completions
pacman -S neomutt offlineimap nullmailer
pacman -S opensc # For YubiKey
systemctl enable sddm acpid

# Install gui applications
#pacman -S kde-applications-meta
#pacman -S networkmanager-dispatcher-sshd networkmanager-dispatcher-ntpd dnsmasq
pacman -S kdegraphics-thumbnailers ffmpegthumbs libheif print-manager cups colord argyllcms kdeconnect xsel
pacman -S code chromium firefox dolphin konsole kbibtex okular gwenview kolourpaint krita skanlite kdegraphics-mobipocket
pacman -S krdc freerdp libvncserver libssh keditbookmarks kmix kile
pacman -S kontact kmail kaddressbook korganizer akregator kdepim-addons kleopatra ktimetracker ksysguard ksystemlog
pacman -S kwalletmanager dolphin-plugins ark p7zip unrar unarchiver lzop lrzip kwrite kcalc spectacle smb4k kamera
pacman -S ktorrent geoip kplotting geoip-database-extra

## Enable kde networkmanager
#systemctl enable NetworkManager.service

# Enable randomn number generators (also install opensc to use YubiKey as entropy source)
pacman -S rng-tools haveged
systemctl enable rngd.service haveged.service

# TODO: Add kerberos to pam

# Setup environment variables
echo 'export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gnupg/S.gpg-agent.ssh"' > /etc/profile.d/gpg-agent.ssh.sh # Allow openssh to use gpg to store secrets, but does not work with YubiKey PIV (fails to work with opensc)
#echo -e 'export http_proxy=""\nexport https_proxy=""\nexport ftp_proxy=""\nexport socks_proxy=""' > /etc/profile.d/proxy.sh # Provide empty proxy variable for buggy applications.
#echo -e 'export WINEPREFIX="$HOME/.wine32"\nexport WINEARCH=win32' > /etc/profile.d/wine.sh

# Setup aliases
echo -e '\nif test -d /etc/bash.bashrc.d/; then\n    for profile in /etc/bash.bashrc.d/*.sh; do\n        test -r "$profile" && . "$profile"\n    done\n    unset profile\nfi' >> /etc/bash.bashrc
mkdir /etc/bash.bashrc.d
echo 'alias ls="ls --color=auto"' >> /etc/bash.bashrc.d/ls-color.sh # colorate ls output
echo 'alias xclip="xsel --clipboard"' >> /etc/bash.bashrc.d/xclip.sh # register xclip as alias for xsel to access clipboard from bash

# TODO: Save /etc/profile.d/prompt.sh (from this repository) as /etc/profile.d/prompt.sh

# TODO: Add yubikey seps:
#     - to allow client auth in firefox and chrome)
#     - use stored ssh private keys

# Add Multilib
echo '[multilib]' >> /etc/pacman.conf
echo 'Include = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf
pacman -Syu

# Enable acpi for notebooks
systemctl enable --now acpid

# Install missing firmware and than
# add "xhci_pci thinkpad_acpi ehci_pci aesni_intel"
# to MODULES
# Regenerate initrd image
# xhci_pci for some controllers is available using: https://aur.archlinux.org/packages/upd72020x-fw/
mkinitcpio -p linux

# Allow sudo for group wheel
echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers

# Add real user
useradd -m -g users -G wheel -s /bin/bash user
passwd user

# TODO: Copy ~/.offlineimaprc (from this repository) to /home/user/.offlineimaprc
chmod 0400 /home/user/.offlineimaprc
chown user:user /home/user/.offlineimaprc
# TODO: Add credentials to /home/user/.offlineimaprc file

# TODO: Copy ~/.neomutt/neomuttrc (from this repository) to /home/user/.neomutt/neomuttrc
# TODO: Copy ~/.mailcap to /home/user/.mailcap
chmod 0500 /home/user/.neomutt
chmod 0400 /home/user/.neomutt/neomuttrc
chmod 0400 /home/user/.mailcap
chown user:user /home/user/.offlineimaprc

# TODO: Add steps for sending emails using smarthost from within neomutt.

# TODO: Logoff and logon as user again.
systemctl --user enable offlineimap-oneshot@MSExchange.timer
systemctl --user enable --now offlineimap-oneshot@MSExchange.service

# TODO: Copy /etc/systemd/ssh-agent.service to /etc/systemd/user/ssh-agent.service
# remove /etc/profile.d/gpg-agent.ssh.sh again, if ssh-agent.sock should be used
#echo 'export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"' > /etc/profile.d/ssh-agent.sh
#systemctl --user enable --now ssh-agent.service
# Use `ssh-add -s /usr/lib/opensc-pkcs11.so` to unlock yubikey for use with openssh

# Configure sendmail
# TODO: Replace with valid credentials and fqdns
mv /usr/sbin/sendmail /usr/sbin/sendmail-bin
touch /usr/sbin/sendmail
chmod 755 /usr/sbin/sendmail
echo '#!/bin/bash' > /usr/sbin/sendmail
echo '/usr/sbin/sendmail-bin -f `cat /etc/nullmailer/forced-from` $@ </dev/stdin' >> /usr/sbin/sendmail
echo 'user@example.tld' | tee /etc/nullmailer/forced-from > /etc/nullmailer/adminaddr
echo 'example.tld' | tee /etc/nullmailer/defaultdomain > /etc/nullmailer/me
echo 'mail.example.tld smtp --port=587 --starttls --auth-login --user=user@example.tld --pass=PASSWORD' > /etc/nullmailer/remotes
systemctl restart nullmailer.service
echo 'set from="user@example.tld" # Default from address' >> /home/user/.neomutt/neomuttrc

# Yubikey Luks unlock:
# AUR package yubikey-full-disk-encryption-git
git submodule add -b master https://aur.archlinux.org/yubikey-full-disk-encryption-git.git
cd yubikey-full-disk-encryption-git
makepkg
sudo pacman -U yubikey-full-disk-encryption-git-*-any.pkg.tar

# TODO: Copy etc/ykfde.conf to /etc/ykfde.conf
# Insert luks partition uuid into YKFDE_DISK_UUID=""
# Luks partition uuid can be queried using:
sudo cryptsetup luksDump /dev/sda3 | grep UUID
# Add Yubikey to Luks volume Key Slot 7
sudo ykfde-enroll -d /dev/sda3 -s 7
sudo nano /etc/mkinitcpio.conf
# TODO: Replace the encrypt with ykfde (HOOKS)
# Than regenerate the ramdisk,
# Systemd hooks currently don't work, but they are slower
# anyway. Even though systemd-boot is used.
sudo mkinitcpio -p linux
# Delete passphrase from volume (clear key slot 0):
sudo ykfde-enroll -d /dev/sda3 -s 0 -k
