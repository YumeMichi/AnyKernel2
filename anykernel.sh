# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# Begin properties
properties() { '
kernel.string=Polar Kernel by YumeMichi @ xda-developers
do.devicecheck=1
do.modules=0
do.cleanup=1
do.cleanuponabort=0
device.name1=dipper
device.name2=equuleus
supported.versions=9 - 10
supported.patchlevels=
'; } # End properties

# Shell variables
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=auto;
ramdisk_compression=auto;

## AnyKernel methods (DO NOT CHANGE)
# Import patching functions/variables - see for reference
. tools/ak3-core.sh;

## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
set_perm_recursive 0 0 755 644 $ramdisk/*;
set_perm_recursive 0 0 750 750 $ramdisk/init* $ramdisk/sbin;

## Begin vendor changes
mount -o rw,remount -t auto /vendor > /dev/null;

cp -rf $home/patch/init.polar.sh /vendor/etc/init/hw/;
chmod 0644 /vendor/etc/init/hw/init.polar.sh;

# Make a backup of init.target.rc
restore_file /vendor/etc/init/hw/init.target.rc;
backup_file /vendor/etc/init/hw/init.target.rc;

# Do work #2
replace_string /vendor/etc/init/hw/init.target.rc "write /dev/stune/top-app/schedtune.colocate 0" "write /dev/stune/top-app/schedtune.colocate 1" "write /dev/stune/top-app/schedtune.colocate 0";

# Add performance tweaks
append_file /vendor/etc/init/hw/init.target.rc "==== Polar Kernel ====" init.target.rc;

# Make a backup of msm_irqbalance.conf
backup_file /vendor/etc/msm_irqbalance.conf;

cp -rf $home/patch/msm_irqbalance.conf /vendor/etc/msm_irqbalance.conf;
chmod 0644 /vendor/etc/msm_irqbalance.conf;

## AnyKernel install
ui_print " " "Decompressing boot image..."
dump_boot;

# Begin ramdisk changes

# Set Android version for kernel
ver="$(file_getprop /vendor/build.prop ro.vendor.build.version.release)"
if [ ! -z "$ver" ]; then
  patch_cmdline "androidboot.version" "androidboot.version=$ver"
else
  patch_cmdline "androidboot.version" ""
fi

# Hexpatch the kernel if Magisk is installed ('skip_initramfs' -> 'want_initramfs')
decomp_img=$home/kernel/Image
comp_img=$decomp_img.gz
if [ -f $comp_img ]; then
  if [ -d $ramdisk/.backup -o -d $ramdisk/.magisk ]; then
    ui_print " " "Magisk detected!";
    ui_print " " "Patching kernel so reflashing Magisk is not necessary...";
    $bin/magiskboot --decompress $comp_img $decomp_img;
    $bin/magiskboot --hexpatch $decomp_img 736B69705F696E697472616D667300 77616E745F696E697472616D667300;
    $bin/magiskboot --compress=gzip $decomp_img $comp_img;
  fi;

  # Concatenate all of the dtbs to the kernel
  cat $comp_img $home/dtbs/*.dtb > $home/Image.gz-dtb;
fi;

# Optimize F2FS extension list (@arter97)
find /sys/fs -name extension_list | while read list; do
  if grep -q odex "$list"; then
    echo "Extensions list up-to-date: $list"
    continue
  fi

  echo "Updating extension list: $list..."

  echo "Clearing extension list..."

  HOT=$(cat $list | grep -n 'hot file extens' | cut -d : -f 1)
  COLD=$(($(cat $list | wc -l) - $HOT))

  COLDLIST=$(head -n$(($HOT - 1)) $list | grep -v ':')
  HOTLIST=$(tail -n$COLD $list)

  echo $COLDLIST | tr ' ' '\n' | while read cold; do
    if [ ! -z $cold ]; then
      echo "[c]!$cold" > $list
    fi
  done

  echo $HOTLIST | tr ' ' '\n' | while read hot; do
    if [ ! -z $hot ]; then
      echo "[h]!$hot" > $list
    fi
  done

  echo "Writing new extension list..."

  cat $home/f2fs-cold.list | grep -v '#' | while read cold; do
    if [ ! -z $cold ]; then
      echo "[c]$cold" > $list
    fi
  done

  cat $home/f2fs-hot.list | while read hot; do
    if [ ! -z $hot ]; then
      echo "[h]$hot" > $list
    fi
  done
done

# End ramdisk changes

ui_print " " "Installing new boot image..."
write_boot;

## End install
ui_print " " "Done!"
