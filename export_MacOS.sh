#!/bin/bash
# export_MacOS.sh
# 12-6-2022: v1.2 Added use of APFS sparseimage to copy files into. This prevents issues related to extended attributes and resource forks on exfat and speeds up transfers. Also improved OneDrive backup
# 25-5-2022: v1.1 Added Apple Mail signatures
# 21-5-2022: v1.0 Created migration script for MacOS computers, copying all files onto an external drive
# Script should be placed and run from the root directory of the external drive i.e. /Volumes/$drive/export_macos.sh
# This script will run caffeinate to prevent the computer from sleeping, check there is sufficient space for all user data on external drive (and exit if not), create a directory named the current user and the date, then proceed to copy off all user data (minus applications, Library, synced directories etc), will copy OneDrive data if chosen, and then backup config for Office autocorrects, browser bookmarks, Outlook signatures, network shares config, and list printers installed.
# All output of script will be stored beside the script in ./MacOS.Export.$(date +%d.%m.%Y.%H.%M.%S).log

## When running as a .command file that can be double clicked it defaults the script path to ~/ rather than the external drive. The below command changes directory to the external drive.
cd $(dirname "$0")

## Check for log folder and create if non existent
if [ -d ./Script\ logs ]; then
echo "Logs folder exists"
else
mkdir ./Script\ logs
echo "Created Script logs folder"
fi 

(

## I want a timer at the end of the script, so create a variable with the date in seconds I can subtract from the end
scriptstart=$(date +%s)

## Create some variables to make the text bold as required
bold=$(tput bold)
normal=$(tput sgr0)

echo "${bold}To successfully backup all required files the terminal should be given full disk access."
echo "To allow this, open system preferences, select Security & Privacy, select the Privacy tab along the top, then ensure the Terminal is ticked under Full Disk Access.${normal}"
echo -ne "Has the terminal got full disk access?\n 1: Yes (continue)\n 2: No (Stop the script)\n : "
read diskaccess

if [[ $diskaccess -eq 1 ]]; then

## I want the name of the user as a variable as I will reference that a lot
USER=$(id -un)

## Create a ONEDRIVE variable first in case OneDrive isn't detected on their computer
ONEDRIVE=2

## This if statement checks if there is already a OneDrive folder present, and prompts to backup or not. In my experience, if there are sync errors on the old computer then it's faster to copy the OneDrive then fix the naming on the new computer instead and sync there.
if [ -d "/Users/$USER/Library/CloudStorage/"*OneDrive* ]; then
    echo "OneDrive has been detected on this computer. If there are sync errors in the OneDrive client you may want to force this to be copied onto the External drive"
    echo -ne "Do you want to backup the OneDrive files?\n 1: Yes\n 2: No\n : "
    read ONEDRIVE
    else
    echo "No OneDrive Folder was detected."
fi

## Run caffeinate to prevent the computer from going to sleep during backup
echo ""
echo "Running caffeinate to prevent computer from locking or suspending"
caffeinate -disu -t 9999999999999 &
echo ""
echo "The size of the personal folders are"
echo ""

## Output to the console the size of directories in the Home directory minus the ones we don't want to copy
du -mc -d 1 -I "Library" -I "Public" -I ".Trash" -I "Sites" -I "Applications" -I "Syncplicity*" -I "Dropbox" -I "OneDrive" -I ".*" /Users/$USER/
echo ""

## Add logic to calculate Onedrive size if chosen to copy then create a variable of the total amount to transfer in MB and print it to the console

if [[ $ONEDRIVE -eq 1 ]]; then
    onedrivesize=$(du -sm /Users/$USER/Library/CloudStorage/*OneDrive* | cut -f1)
    echo "The size of the OneDrive folder is $onedrivesize MB"
    echo ""
    total1=$(du -cm -d 1 -I "Library" -I "Public" -I ".Trash" -I "Sites" -I "Applications" -I "Syncplicity*" -I "Dropbox" -I "OneDrive" -I ".*" /Users/$USER/ | tail -1 | cut -f1 )
    echo "The size of the Users folders to transfer is $total1"
    total=$(( $total1 + $onedrivesize ))
else
    total=$(du -cm -d 1 -I "Library" -I "Public" -I ".Trash" -I "Sites" -I "Applications" -I "Syncplicity*" -I "Dropbox" -I "OneDrive" -I ".*" /Users/$USER/ | tail -1 | cut -f1 )
fi
echo ""
echo ""
echo "${bold}The total size to transfer is $total MB${normal}"
echo ""
drive=$(pwd)
freespace=$(df -m | grep "$drive" | awk '{print $4}')

echo "${bold}The total free space is on the external drive is $freespace MB${normal}"
echo ""
total_gb=$(($total / 1024))

## Check if there is enough space for the files on the external drive, and exit if not

if [ $freespace -gt $total ]; then
echo ""
echo "${bold}There is sufficient space for the transfer, continuing...${normal}"
echo ""

## Create the destination folder and a variable of its location to easily reference through the script
mkdir ./"$(whoami)_$(date +%Y.%m.%d)"
dest2=$drive/"$(whoami)_$(date +%Y.%m.%d)"
folder=$(whoami)_$(date +%Y.%m.%d)

echo "The destination folder is called $dest2"

## Create a disk image to backup everything into
hdiutil create -type SPARSE -size 1000g -fs apfs -volname "backup" ./$folder/backup_drive
touch ./$folder/"The size of the image should be ~$total_gb GB"

## Mount the disk image
hdiutil attach ./$folder/backup_drive.sparseimage

dest=/Volumes/backup

## List printers and copy printers
echo ""
echo "Copying installed printer information..."
echo ""
lpstat -p > "$dest/printers.txt"
echo "Printer information copied"

## Copy Chrome bookmarks
echo "Copying Chrome bookmarks..."
mkdir -p "$dest/Bookmarks/Chrome"
cp -av "/Users/$USER/Library/Application Support/Google/Chrome/Default/Bookmarks" "$dest/Bookmarks/Chrome/"
echo "Chrome Bookmarks copied"
echo ""

## Copy Safari Bookmarks
echo "Copying Safari Bookmarks"
mkdir "$dest/Bookmarks/Safari"
cp -av "/Users/$USER/Library/Safari/Bookmarks.plist" "$dest/Bookmarks/Safari/"

## Copy Firefox bookmarks
echo "Copying Firefox Bookmarks"
mkdir "$dest/Bookmarks/Firefox"
cp -av "/Users/$USER/Library/Application Support/Firefox/Profiles/"*default-release"/" "$dest/Bookmarks/Firefox/"

## Copy out autocorrect files from old machine
mkdir -p "$dest/Office/Autocorrects"
echo "Copying Office autocorrects"
cp -av "/Users/$USER/Library/Group Containers/UBF8T346G9.Office/"*ACL* "$dest/Office/Autocorrects/"
echo "Office autocorrects copied"

## Copy out Outlook files (signatures)
mkdir "$dest/Office/Outlook"
echo "Copying outlook signatures"
cp -av "/Users/$USER/Library/Group Containers/UBF8T346G9.Office/Outlook/"*Profiles"/Main Profile/Data/Signatures" "$dest/Office/Outlook/"
cp -av "/Users/$USER/Library/Group Containers/UBF8T346G9.Office/Outlook/"*Profiles"/Main Profile/Data/Signature Attachments" "$dest/Office/Outlook/"
cp -av "/Users/$USER/Library/Group Containers/UBF8T346G9.Office/Outlook/"*Profiles"/Main Profile/Data/"*sqlite* "$dest/Office/Outlook/"
echo "Outlook signatures copied"

## Copy Mail signatures
if [ -d "/Users/$USER/Library/Mail/"V*"/MailData/Signatures" ]; then
mkdir "$dest/Mail"
echo "Copying Mail signatures"
cp -av "/Users/$USER/Library/Mail/"V*"/MailData/Signatures/" "$dest/Mail/"
echo "Mail signatures copied"
else
echo "No mail signatures found, skipping..."
fi

## Copy favourite servers list for new machine
mkdir "$dest/Network_Locations"
cp "/Users/$USER/Library/Application Support/com.apple.sharedfilelist/"*FavoriteServers* "$dest/Network_Locations/"

## Copy all files excluding those in syncing directorys such as Dropbox, Syncplicity (including Syncplicity Folders), OneDrive etc...
## Rsync runs first, mopping up any directories that aren't the primary Documents, Desktop, Downloads... as well as any of the syncing folders.
## Rsync is much slower than CP but allows for easy exclusion of folders with its more comprehensive flags
## cp is then used afterwards to transfer the bulk of the data in the common folders Downloads, Desktop etc.
## This should give a good balance of speed and versatility, copying all desired folders without manual input
mkdir "$dest/Files"
rsync -ahWPR --exclude="/Users/$USER/Library" --exclude="/Users/$USER/Downloads" --exclude="/Users/$USER/Documents" --exclude="/Users/$USER/Desktop" --exclude="/Users/$USER/Music" --exclude="/Users/$USER/Pictures" --exclude="/Users/$USER/Movies" --exclude="/Users/$USER/Applications" --exclude="/Users/$USER/Public" --exclude="/Users/$USER/Sites" --exclude="/Users/$USER/Dropbox" --exclude="/Users/$USER/"Syncplicity* --exclude="/Users/$USER/"*OneDrive* --exclude="/Users/$USER/.*" "/Users/$USER/" "$dest/Files/"

cp -av "/Users/$USER/Downloads" "$dest/Files/Users/$USER/"
cp -av "/Users/$USER/Desktop" "$dest/Files/Users/$USER/"
cp -av "/Users/$USER/Documents" "$dest/Files/Users/$USER/"
cp -av "/Users/$USER/Music" "$dest/Files/Users/$USER/"
cp -av "/Users/$USER/Pictures" "$dest/Files/Users/$USER/"
cp -av "/Users/$USER/Movies" "$dest/Files/Users/$USER/"

## Copy the OneDrive files if they were chosen to be copied at the start of the script

if [[ $ONEDRIVE -eq 1 ]]; then
    echo "Copying OneDrive files"
    ## Kill OneDrive to prevent downloading of cloud only files while copying
    pkill OneDrive
    mkdir "$dest/OneDrive"
    cp -av "/Users/$USER/Library/CloudStorage/"*OneDrive*/ "$dest/OneDrive/"

    ## Delete all files of 0 bytes i.e. all files that were unsynced on the local computer
    find "$dest/OneDrive/" -type f -size 0c -exec rm {} \;

    ## Restart OneDrive
    open -a /Applications/OneDrive.app/Contents/MacOS/OneDrive

    else
    echo "OneDrive files will not be copied now as it was not selected at the start of the script"
fi

## Copy Printer configuration and drivers - May be possible? Needed? 
## I have decided not to attempt to copy printer drivers as it may be more hassle than it's worth especially when potentially migrating from older versions of MacOS where drivers may not be supported.

if [[ $ONEDRIVE -eq 1 ]]; then
    transferred1=$(du -sm "$dest/Files" | cut -f1)
    transferred2=$(du -sm "$dest/OneDrive" | cut -f1)
    transferred=$(( $transferred1 + $transferred2 ))
else
    transferred=$(du -sm "$dest/Files" | cut -f1)
fi

## Detach the disk image
echo "Detaching the backup disk image"
hdiutil detach /Volumes/backup

scriptend=$(date +%s)
timetotalsecs=$(($scriptend - $scriptstart))
echo ""
echo ""
echo "${bold}The script is now complete"
echo "A total of $transferred MB was transferred out of $total MB"
echo "The total time of the script was $timetotalsecs seconds${normal}"
else
    echo "${bold}There is insufficient space for the transfer"
    echo "The script will now stop${normal}"
fi


## Kill caffeinate once the script completes
echo "Closing caffeinate so computer can sleep again!"
pkill caffeinate &

else
echo "${bold}Script has ended as the terminal does not have full disk access yet. Allow access then run the script again${normal}"
fi
) 2>&1 | tee ./Script\ logs/MacOS.Export.$(date +%d.%m.%Y.%H.%M.%S).log
## This final line here is the export of the terminal output to the log file