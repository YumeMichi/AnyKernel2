# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# Begin properties
properties() { '
kernel.string=PolarKernel by YumeMichi @ xda-developers
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=dipper
supported.versions=10
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
append_file /vendor/etc/init/hw/init.target.rc "==== PolarKernel ====" init.target.rc;

# Make a backup of msm_irqbalance.conf
restore_file /vendor/etc/msm_irqbalance.conf;
backup_file /vendor/etc/msm_irqbalance.conf;

cp -rf $home/patch/msm_irqbalance.conf /vendor/etc/msm_irqbalance.conf;
chmod 0644 /vendor/etc/msm_irqbalance.conf;

# Make a backup of fstab.qcom
restore_file /vendor/etc/fstab.qcom;
backup_file /vendor/etc/fstab.qcom;

cp -rf $home/patch/fstab.qcom /vendor/etc/fstab.qcom;
chmod 0644 /vendor/etc/fstab.qcom;

# Make a backup of /vendor/etc/thermal-engine*
for files in /vendor/etc/thermal-engine*
do
  restore_file $files;
  backup_file $files;
  $bb cat /dev/null > $files;
done

## AnyKernel install
ui_print " " "Decompressing boot image..."
dump_boot;

# Begin ramdisk changes

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
$bb umount /system
$bb umount /vendor
