#!/bin/sh

partitionAndMount() {
    declare -r $device="/dev/nvme0n1"

    # Wipe filesystem signatures on ${device}
    echo "Wiping all signatures from ${device}"
    exec wipefs --all --force ${device} &> /dev/null

    (echo "g";  # Creates a GUID partition table 

    # boot partition
    echo "n";   # Creates new parition
    echo "";    # make this partition no. 1
    echo "";
    echo "+550M"; # Make a 550MiB partition
    echo "t";   # Choose type
    echo "1";   # Choose EFI System

    # root partition
    echo "n";
    echo "";    # make this partition no. 2
    echo "";
    echo "+50G";    # Make a 50GiB partition

    # home partition
    echo "n";
    echo "";    # make this partition no. 3
    echo "";    
    echo "";    # Use the remainder of space
    echo "w") | fdisk ${device} &> /dev/null
    
    echo "Making a FAT32 filesystm on ${device}p1..."
    mkfs.fat -F32 ${device}p1 &> /dev/null
    echo "Making an EXT4 filesystem on ${device}p2..."
    mkfs.ext4 ${device}p2 &> /dev/null
    echo "Making an EXT4 filesystem on ${device}p3..."
    mkfs.ext4 ${device}p3 &> /dev/null

    # Mount filesystem
    mount ${device}p2 /mnt
    [[ -d /mnt/home ]] || mkdir /mnt/home
    mount ${device}p3 /mnt/home

    # Generate filesystem table
    genfstab -U /mnt >> /mnt/etc/fstab
    
    return
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

    declare -r second_script="./archinstall-part-2.sh"
    echo "Copying ${second_script} to /mnt..."
    cp ${second_script} /mnt

    # $(arch-chroot /mnt) just starts /bin/sh in /mnt; this below runs a
    # the second part of the script
    arch-chroot /mnt $second_script

    echo "Unmounting /mnt..."
    umount -l /mnt

    echo "Done! Now, unplug the installation medium and reboot!"
}
