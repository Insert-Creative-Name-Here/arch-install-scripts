#!/bin/sh

partitionAndMount() {
    readonly DEVICE='/dev/nvme0n1'
    readonly BOOT_PARTITION_SIZE='550' # size in MiB
    readonly ROOT_PARTITION_SIZE='50' # size in GiB

    # Wipe filesystem signatures on ${DEVICE}
    echo "Wiping all signatures from ${DEVICE}"
    exec wipefs --all --force ${DEVICE} &> /dev/null

    (echo "g";  # Creates a GUID partition table 

    # boot partition
    echo "n";   # Creates new parition
    echo "";    # make this partition no. 1
    echo "";
    echo "+${BOOT_PARTITION_SIZE}M"; # Make a 550MiB partition
    echo "t";   # Choose type
    echo "1";   # Choose EFI System

    # root partition
    echo "n";
    echo "";    # make this partition no. 2
    echo "";
    echo "+${ROOT_PARTITION_SIZE}G";    # Make a 50GiB partition

    # home partition
    echo "n";
    echo "";    # make this partition no. 3
    echo "";    
    echo "";    # Use the remainder of space
    echo "w") | fdisk ${DEVICE} &> /dev/null
    
    echo "Making a FAT32 filesystm on ${DEVICE}p1..."
    mkfs.fat -F32 ${DEVICE}p1 &> /dev/null
    echo "Making an EXT4 filesystem on ${DEVICE}p2..."
    mkfs.ext4 ${DEVICE}p2 &> /dev/null
    echo "Making an EXT4 filesystem on ${DEVICE}p3..."
    mkfs.ext4 ${DEVICE}p3 &> /dev/null

    # Mount filesystem
    mount ${DEVICE}p2 /mnt
    [[ -d /mnt/home ]] || mkdir /mnt/home
    mount ${DEVICE}p3 /mnt/home

    # Generate filesystem table
    genfstab -U /mnt >> /mnt/etc/fstab
    
    return 0
}

installBasePackages () {
    echo "Installing base packages..."
    (echo; echo) | pacstrap /mnt base base-devel &> /dev/null
    echo "Installing latest linux..."
    echo | pacstrap /mnt linux linux-headers linux-firmware &> /dev/null
    echo "Installing LTS linux..."
    echo | pacstrap /mnt linux-lts linux-lts-headers &> /dev/null

    return
}

main() {
    echo "Synchronizing machine's time with the Internet..."
    timedatectl set-ntp true

    # Call the functions, yadda yadda
    partitionAndMount

    installBasePackages

    # Second script must be in a separate file because of how arch-chroot works
cat <<'END_OF_SECOND_SCRIPT' > /mnt/root/archinstall-part-2.sh
#!/bin/sh

# Set device timezone
setTimeZone () {
    declare region="Europe"
    declare city="Bucharest"

    echo "Setting timezone to ${region}/${city}..."
    ln -sf /usr/share/zoneinfo/${region}/${city} /etc/localtime &> /dev/null

    echo "Uncommenting the appropriate lines in /etc/locale.gen..."
    sed -i '/#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
    
    [[ ${city} == "Bucharest" ]] &&
        sed -i '/#ro_RO.UTF-8 UTF-8/s/^#//' /etc/locale.gen

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
    useradd -m ${username}

    echo
    passwd ${username}

    echo "Setting privileges for ${username}..."
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

    # Make a 2 GiB swapfile
    dd if=/dev/zero of=/swapfile bs=1M count=2048
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap defaults 0 0" >> /etc/fstab

    echo "Done inside chroot, exiting..."
    exit
}
main
END_OF_SECOND_SCRIPT

    # arch-chroot [target] just starts /bin/sh in [target]; this below runs a
    # the second part of the script. The second argument must be specified
    # relative to the new root path
    arch-chroot /mnt /root/archinstall-part-2.sh

    echo "Unmounting /mnt..."
    umount -l /mnt

    echo "Done! Now, unplug the installation medium and reboot!"

    exit
}
main
