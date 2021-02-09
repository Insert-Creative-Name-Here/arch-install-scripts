#!/bin/sh

# Automatically install Arch Linux

## Some config data
# Drive to install on
readonly DEVICE='/dev/nvme0n1'
readonly BOOT_PARTITION_SIZE='550' # size in MiB
readonly ROOT_PARTITION_SIZE='50' # size in GiB

# Timezone
readonly REGION='Europe'
readonly CITY='Bucharest'

# User preferences
readonly SHELL='zsh'
readonly USERNAME='icnh'
readonly HOSTNAME='archlinux'


partitionAndMount() {
    # Wipe filesystem signatures on ${DEVICE}
    echo "Wiping all signatures from ${DEVICE}"
    exec wipefs --all --force ${DEVICE} &> /dev/null

    (echo "g";  # Creates a GUID partition table 

    # boot partition
    echo "n";   # Creates new parition
    echo "1";   # make this partition no. 1
    echo "";
    echo "+${BOOT_PARTITION_SIZE}M";
    echo "t";   # Choose type
    echo "1";   # Choose EFI System

    # root partition
    echo "n";
    echo "2";   # make this partition no. 2
    echo "";
    echo "+${ROOT_PARTITION_SIZE}G";

    # home partition
    echo "n";
    echo "3";   # make this partition no. 3
    echo "";    
    echo "";    # Use the remainder of space
    echo "w") | fdisk ${DEVICE} &>/dev/null

    [[ "${DEVICE}" =~ "nvme" ]] && DEVICE+="p"

    echo "Making a FAT32 filesystm on ${DEVICE}1..."
    mkfs.fat -F32 "${DEVICE}1" &>/dev/null
    echo "Making an EXT4 filesystem on ${DEVICE}2..."
    mkfs.ext4 "${DEVICE}2" &>/dev/null
    echo "Making an EXT4 filesystem on ${DEVICE}3..."
    mkfs.ext4 "${DEVICE}3" &>/dev/null

    # Mount filesystem
    mount "${DEVICE}2" /mnt
    [[ -d /mnt/home ]] || mkdir /mnt/home
    mount "${DEVICE}3" /mnt/home

    # Generate filesystem table
    genfstab -U /mnt >> /mnt/etc/fstab
    
    return 0
}

installBasePackages () {
    echo "Installing base packages..."
    yes | pacstrap /mnt base base-devel &> /dev/null
    echo "Installing latest linux..."
    yes | pacstrap /mnt linux linux-headers linux-firmware &> /dev/null
    echo "Installing LTS linux..."
    yes | pacstrap /mnt linux-lts linux-lts-headers &> /dev/null

    return
}

main() {
    echo "Synchronizing machine's time with the Internet..."
    timedatectl set-ntp true

    # Call the functions, yadda yadda
    partitionAndMount

    installBasePackages

    # Second script must be in a separate file because of how arch-chroot works
    readonly SECOND_PART='root/archinstall-p2.sh'
cat <<END_OF_SECOND_SCRIPT > /mnt/${SECOND_PART}
#!/bin/sh

# Set device timezone
setTimeZone () {
    echo "Setting timezone to ${REGION}/${CITY}..."
    ln -sf /usr/share/zoneinfo/${REGION}/${CITY} /etc/localtime &> /dev/null

    echo "Uncommenting the appropriate lines in /etc/locale.gen..."
    sed -i '/#en_GB.UTF-8 UTF-8/s/^#//' /etc/locale.gen
    
    [[ ${CITY} == "Bucharest" ]] &&
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
    pacman -S --noconfirm sudo neovim git sed \
                            ${SHELL} networkmanager &> /dev/null

    echo "Enabling NetworkManager..."
    systemctl enable NetworkManager

    return 0
}

hostAndUserName() {
    echo "Adding hostname to /etc/hostname..."
    echo "${HOSTNAME}" > /etc/hostname

    echo "Adding required lines to /etc/hosts..."
    echo "127.0.0.1\tlocalhost" >> /etc/hosts
    echo "::1\tlocalhost" >> /etc/hosts
    echo "127.0.1.1\t${HOSTNAME}.localdomain\t${HOSTNAME}" >> /etc/hosts

    echo
    passwd

    echo "Adding user ${USERNAME}..."
    useradd -m ${USERNAME}

    echo
    passwd ${USERNAME}

    echo "Setting privileges for ${USERNAME}..."
    usermod -xG wheel,audio,video,optical,storage ${USERNAME}
    
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

    installPackages

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
    chmod +x /mnt/${SECOND_PART}
    arch-chroot /mnt /${SECOND_PART}

    echo "Removing second part of the script..."
    rm -f /mnt/${SECOND_PART}

    echo "Unmounting /mnt..."
    umount -l /mnt

    echo "Done! Now, unplug the installation medium and reboot!"

    exit
}
main
