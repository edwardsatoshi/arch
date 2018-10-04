#!/bin/bash

read -p "User name: " $user
read -p "Host name: " $host

while true; do
	  read -s -p "Define Password: " pw
	  echo
	  read -s -p "Repeat Password: " pw2
	  echo
	  [ "$pw" = "$pw2" ] && break
	  echo "Mismatch. try again"
done


setup(){
  # uefi
  [ -d "/sys/firmware/efi/efivar" ] || { echo "Fail: no uefi."; exit 1}

  #internet
  ping -q -c 1 -W 1 https://www.archlinux.org >/dev/null ||
  {echo -e "Fail: no internet. tip: \e[32mGreen wifi-menu \e[39mDefault command connects to wifi\n "; exit 1}

  timedatectl set-ntp true

  # partition
  parted -s -a optimal /dev/sda mklabel gpt mkpart primary ext4 1MiB 100% set 1 esp on
  mkfs.ext4 /dev/sda1
  mount /dev/sda /mnt

  # swap file
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile

  # base system
  pacstrap /mnt base base-devel
  genfstab -U /mnt >> /mnt/etc/fstab
  arch-chroot /mnt
  printf "$user\n$host\n$pw\n$pw\n" arch-chroot sh $0 chroot
}

configure(){

  #timezone
  ln -sf /usr/share/zoneinfo/$(curl https://ipapi.co/timezone) /etc/localtime
  hwclock --systohc

  #localization
  echo -e "LANG=\"en_US.UTF-8\"\nLC_COLLATE=\"C\"" >> /etc/locale.conf
  echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
  locale-gen

  #keymap
  echo "KEYMAP=br-abnt2" >> /etc/vconsole.conf

  #hostname
  echo "$host" > /etc/hostname
	cat > /etc/hosts <<-EOF
		127.0.0.1	localhost
		::1      	localhost
		127.0.0.1 $host.localdomain $host
	EOF

  #networkmanager
	pacman -S networkmanager networkmanager-openrc network-manager-applet
	rc-update add NetworkManager default

  #grub
  pacman -S grub  efibootmgr os-prober
	grub-install --target=x86_64-efi --efi-directory=esp --bootloader-id=GRUB
	grub-mkconfig -o /boot/grub/grub.cfg

  #login
  useradd -m $user
	echo -en $pw\n$pw | passwd $user
	echo -en $pw\n$pw | passwd

  #drivers
  pacman -S xorg xf86-video-amdgpu mesa lib32-mesa intel-ucode xf86-input-synaptics

  #desktop environment
  pacman -S lxqt breeze-icons sddm

  #aur helper
  git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg -si

  #browser
	yay -S ungoogled-chromium

  #japanese language
  pacman -S adobe-source-han-sans-jp-fonts
	pacman -S ibus ibus-qt ibus-anthy
	yay -S ibus-mozc mozc-ut2
}

if [ "$1" == "chroot" ]
then
    configure
else
    setup
fi
