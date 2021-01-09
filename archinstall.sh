#!/usr/bin/sh

# Set time (not yet chroot-ed)
setTime () {
    echo "Synchronizing machine's time with the Internet..."
    timedatectl set-ntp true

    return
}

partitionAndMount() {
    declare -r $device="/dev/nvme0n1"

    # Wipe filesystem signatures on ${device}
    echo "Wiping all signatures from ${device}"
    exec wipefs --all --force ${device} &> /dev/null

    (echo "g";  # Creates a gpt partition
    # boot partition
    echo "n";   # Creates new parition
    echo "";    # partition no. 1
    echo "";
    echo "+550M"; # Make a 550MiB partition
    echo "t";   # Choose type
    echo "1";   # Choose EFI System

    # root partition
    echo "n";
    echo "";    # partition no. 2
    echo "";
    echo "+50G";    # Make a 50GiB partition

    # home partition
    echo "n";
    echo "";    # partition no. 3
    echo "";    
    echo "";    # Use the remainder of space
    echo "w") | fdisk ${device} &> /dev/null
    
    echo "Making a FAT32 filesystm on ${device}p1..."
    mkfs.fat -F32 ${device}p1 &> /dev/null
    echo "Making an EXT4 filesystem on ${device}p2..."
    mkfs.ext4 ${device}p2
    echo "Making an EXT4 filesystem on ${device}p3..."
    mkfs.ext4 ${device}p3

    # Mount filesystem
    mount ${device}p2 /mnt
    mkdir /mnt/home
    mount ${device}p3 /mnt/home

    installBasePackages 

    # Generate filesystem table
    genfstab -U /mnt >> /mnt/etc/fstab
    
    return
}

installBasePackages () {
    echo "Installing base packages..."
    echo | pacstrap /mnt base &> /dev/null
    echo "Installing latest linux..."
    echo | pacstrap /mnt linux linux-headers linux-firmware &> /dev/null
    echo "Installing LTS linux..."
    echo | pacstrap /mnt linux-lts linux-lts-headers &> /dev/null

    return
}

# Set device timezone
setTimeZone () {
    declare region="Europe"
    declare city="Bucharest"

    echo "Setting timezone to $region/$city..."
    ln -sf /usr/share/zoneinfo/$region/$city /etc/localtime &> /dev/null

    echo "Synchronizing harware clock..."
    hwclock --systohc &> /dev/null
    
    echo "Uncommenting the appropriate lines in /etc/locale.gen..."
    sed -i '/#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
    
    if [[ $city == "Bucharest" ]]; then
        sed -i '/#ro_RO.UTF-8 UTF-8/s/^#//' /etc/locale.gen
    fi

    locale-gen

    echo "Writing to /etc/locale.conf..."
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf

    return
}

hostAndUserName() {
    declare hostname="archlinux"
    declare username="icnh"

    echo "Adding hostname to /etc/hostname..."
    echo "$hostname" > /etc/hostname

    echo "Adding required lines to /etc/hosts..."
    echo "127.0.0.1\tlocalhost" >> /etc/hosts
    echo "::1\tlocalhost" >> /etc/hosts
    echo "127.0.1.1\t$hostname.localdomain\t$hostname" >> /etc/hosts

    echo "\nSet root user password:"
    passwd

    echo "Adding user $username..."
    useradd -m $username
    passwd $username

    echo "Setting privileges for $username..."
    usermod -xG wheel,audio,video,optical,storage $username
    
    echo "You have to edit the visudoers file manually."
    echo "Uncomment the line with 'wheel ALL=(ALL) ALL'"
    sleep 7
    EDITOR=nvim visudo

    return
}

installPackages () {
    echo "Installing useful packages..."
    echo | pacman -S 'sudo' 'neovim' 'git' 'sed' 'zsh' 'networkmanager'

    echo "Enabling NetworkManager..."
    systemctl enable NetworkManager

    return
}

grubInstallAndConfigure () {
    echo | pacman -S 'grub' 'efibootmgr' 'dosfstools' 'os-prober' 'mtools'

    echo "Making and mounting /boot/EFI directory..."
    if [[ ! -d /boot/EFI ]]; then
        mkdir /boot/EFI
    fi
    mount /dev/nvme0n1p1 /boot/EFI

    echo "Installing GRUB..."
    grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck

    echo "Making GRUB configuration file..."
    grub-mkconfig -o /boot/grub/grub.cfg

    return
}

## Main script
# Call a bunch of functions sequentially
setTime
partitionAndMount
arch-chroot /mnt
installPackages
setTimeZone 
hostAndUserName
grubInstallAndConfigure

# Unmount
exit
echo "Unmounting /mnt..."
umount -l /mnt

echo "Done! Now, unplug the installation medium and reboot!"
