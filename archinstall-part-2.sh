#!/bin/sh

# Set device timezone
setTimeZone () {
    declare region="Europe"
    declare city="Bucharest"

    echo "Setting timezone to ${region}/${city}..."
    ln -sf /usr/share/zoneinfo/${region}/${city} /etc/localtime &> /dev/null

    echo "Uncommenting the appropriate lines in /etc/locale.gen..."
    sed -i '/#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
    
    [[ ${city} == "Bucharest" ]]
        && sed -i '/#ro_RO.UTF-8 UTF-8/s/^#//' /etc/locale.gen

    locale-gen
    
    echo "Synchronizing machine's time with the internet..."
    timedatectl set-ntp true

    echo "Synchronizing harware clock with system clock..."
    hwclock --systohc &> /dev/null
    

    echo "Writing to /etc/locale.conf..."
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf

    return 0
}

installPackages () {
    pacman -Syy

    echo "\nInstalling useful packages..."
    pacman -S --noconfirm 'sudo' 'neovim' 'git' 'sed' \
                            'zsh' 'networkmanager' &> /dev/null

    echo "Enabling NetworkManager..."
    systemctl enable NetworkManager

    return 0
}

hostAndUserName() {
    declare hostname="archlinux"
    declare username="icnh"

    echo "Adding hostname to /etc/hostname..."
    echo "${hostname}" > /etc/hostname

    echo "Adding required lines to /etc/hosts..."
    echo "127.0.0.1\tlocalhost" >> /etc/hosts
    echo "::1\tlocalhost" >> /etc/hosts
    echo "127.0.1.1\t${hostname}.localdomain\t${hostname}" >> /etc/hosts

    echo
    passwd

    echo "Adding user ${username}..."
    useradd -m ${usernam}

    echo
    passwd ${username}

    echo "Setting privileges for ${usernam}..."
    usermod -xG wheel,audio,video,optical,storage ${username}
    
    echo "Configuring wheel group..."
    echo '%wheel ALL=(ALL) ALL' | sudo EDITOR='tee -a' visudo

    return 0
}

grubInstallAndConfigure () {
    echo "Installing GRUB and some other boot tools..."
    pacman -S --noconfirm 'grub' 'efibootmgr' 'dosfstools' \
                            'os-prober' 'mtools' &> /dev/null

    echo "Making and mounting /boot/EFI directory..."
    [[ -d /boot/EFI ]] || mkdir /boot/EFI && mount /dev/nvme0n1p1 /boot/EFI

    echo "Running grub-install..."
    grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck 

    echo "Generating the GRUB configuration file..."
    grub-mkconfig -o /boot/grub/grub.cfg

    return 0
}

main() {
    # Call some more functions, yadda yadda.
    setTimeZone

    hostAndUserName

    grubInstallAndConfigure

    echo "Done inside chroot, exiting..."
    exit
}

main
