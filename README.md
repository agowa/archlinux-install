# Arch Linux Install

This repository shortens the path to install a full archlinux system by compressing the
ArchLinux wiki into just the relevant commandline commands, without long explanations.

This guide is entended for advanced linux users, that know what they do (at least slightly)
and either just want to get a quick start on how to install ArchLinux without skim reading
the wiki.

If you're new to Linux in generell, this guide is not for you, you may want to use the
official [Installation Guide](https://wiki.archlinux.org/index.php/Installation_guide) instead.


## YubiKey

### SSH Authentication

1. Generate a certificate within slot 9a of the PIV module.
1. Extract the openssh public key string: `ssh-keygen -D /usr/lib/opensc-pkcs11.so -e`
1. To unlock the yubikey for openssh: `ssh-add -s /usr/lib/opensc-pkcs11.so`
