#!/bin/bash
#
# Enable TRIM support for 3rd Party SSDs. Works for Mountain Lion, should work on earlier OSes too.
# Tested on 10.8.2, 10.8.3, 10.8.5, 10.9.0-10.9.5, 10.10.0
#
# Run this script at your own risk, whether on 10.10 or earlier.
#
# This script works on MacOS 10.10 (Yosemite) but it has significant system security repercussions.
# To use it you must disable kext signing on your machine. This makes it easier for
# malware to infect your machine by disabling the feature which would detect unsigned
# (presumably rogue) kexts and refuse to load them.
#
# You may have to re-apply the fix after some system updates, including but not limited to those below:
# 10.9.X to another 10.9.X
# 10.8.X to 10.8.3
#
# Checked for proper operation on 10.8.0, but never booted 10.8.0 with the modified kext.
#
# Original source: http://digitaldj.net/2011/07/21/trim-enabler-for-lion/
#
# To use this, put the contents of this into a file called enable_trim.sh in your home directory
# Then, open a Terminal window. In this window, type 'bash enable_trim.sh' (omitting the quotes)
# and press return. It will ask for your administrator password. Type this and it will patch the file.
# Then simply reboot.
#
# You can verify that this worked (or if it hasn't been run that it is unneeded) by
# selecting "About This Mac" from the Apple menu, then clicking the "More Info..." button,
# in the new window click the "System Report" button. In the System Information that
# opens, select "Serial-ATA" or "SATA/SATA Express" under "Hardware" in the list on the
# left. Then click on the item which is your SSD. You will see an item "TRIM Support:"
# in the text in the lower right part of the window. If it says "Yes", then TRIM is
# working.
#

set -e
#set -x

if [[ `uname -r | sed -n -E -e 's/^([0-9]+).*$/\1/p'` -ge 14 ]]; then 
    if [[ -f /tmp/youstillmustreboot.txt ]] ; then
        echo "You MUST reboot after disabling driver signing. Run this script again"
        echo "after rebooting."
        exit 3
    fi
    if [[ ! ( `nvram boot-args 2>/dev/null` =~ kext-dev-mode=1$ ) ]] ; then
        echo "This script does not work on Yosemite (10.10) or later unless you disable"
        echo "driver signing. Disabling kext signing defeats one of the security features"
        echo "of Yosemite which helps to prevent malware installing itself on your machine."
        echo "For more information see https://www.cindori.org/trim-enabler-and-yosemite/"
        echo ""
        echo "If you would like to disable kext signing."
        echo "Enter an administrator password below."
        echo "Otherwise press control-C to cancel."
        sudo -k
        sudo nvram boot-args=kext-dev-mode=1
        echo "still" >/tmp/youstillmustreboot.txt
        echo "Now reboot to disable kext signing. Then run this script again."
        exit 4
    fi
fi

if [[ -f /System/Library/Extensions/IOAHCIFamily.kext/Contents/PlugIns/IOAHCIBlockStorage.kext/Contents/MacOS/IOAHCIBlockStorage.original
      && ( "`md5 -q /System/Library/Extensions/IOAHCIFamily.kext/Contents/PlugIns/IOAHCIBlockStorage.kext/Contents/MacOS/IOAHCIBlockStorage`" != \
           "`md5 -q /System/Library/Extensions/IOAHCIFamily.kext/Contents/PlugIns/IOAHCIBlockStorage.kext/Contents/MacOS/IOAHCIBlockStorage.original`" ) ]]; then
    echo "You seem to have already patched the kext in question. Patching again will"
    echo "destroy your unmodified backup. If you are sure you want to patch again,"
    echo "delete your backup with the following command:"
    echo "sudo rm -f /System/Library/Extensions/IOAHCIFamily.kext/Contents/PlugIns/IOAHCIBlockStorage.kext/Contents/MacOS/IOAHCIBlockStorage.original"
    echo "Then run this script again."
    exit 5
fi

# Back up the file we are patching
echo "Your root password is required to modify your Serial-ATA driver to enable TRIM."
sudo cp \
  /System/Library/Extensions/IOAHCIFamily.kext/Contents/PlugIns/IOAHCIBlockStorage.kext/Contents/MacOS/IOAHCIBlockStorage \
  /System/Library/Extensions/IOAHCIFamily.kext/Contents/PlugIns/IOAHCIBlockStorage.kext/Contents/MacOS/IOAHCIBlockStorage.original

# Patch the file to enable TRIM support
# This nulls out the string "APPLE SSD" so that string compares will always pass.
# on 10.9.4 to 10.9.5 and 10.10.0 the sequence is WakeKey\x0a\0APPLE SSD\0Time To Ready\0
# on 10.8.3 to 10.8.5 and 10.9.0 to 10.9.3, the sequence is Rotational\0APPLE SSD\0Time To Ready\0
# on 10.8.2, the sequence is Rotational\0APPLE SSD\0MacBook5,1\0
# on 10.8.0, the sequence is Rotational\0\0APPLE SSD\0\0\0Queue Depth\0
# The APPLE SSD is to be replaced with a list of nulls of equal length (9).
sudo perl -p0777i -e 's@((?:Rotational|WakeKey\x0a)\x00{1,20})APPLE SSD(\x00{1,20}[QMT])@$1\x00\x00\x00\x00\x00\x00\x00\x00\x00$2@' \
  /System/Library/Extensions/IOAHCIFamily.kext/Contents/PlugIns/IOAHCIBlockStorage.kext/Contents/MacOS/IOAHCIBlockStorage

if [[ "`md5 -q /System/Library/Extensions/IOAHCIFamily.kext/Contents/PlugIns/IOAHCIBlockStorage.kext/Contents/MacOS/IOAHCIBlockStorage`" == \
      "`md5 -q /System/Library/Extensions/IOAHCIFamily.kext/Contents/PlugIns/IOAHCIBlockStorage.kext/Contents/MacOS/IOAHCIBlockStorage.original`" ]]; then
    echo "Patching FAILED. Your IOAHCIBlockStorage kext is unmodified."
    exit 1
else
    # Force a reboot of the system's kernel extension cache
    sudo touch /System/Library/Extensions/

    echo "Now reboot!"
fi
