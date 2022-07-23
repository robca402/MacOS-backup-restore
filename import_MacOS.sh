#!/bin/bash
# import_MacOS.sh
# 12-6-2022: v1.2 Added use of APFS sparseimage to copy files into. This prevents issues related to extended attributes and resource forks on exfat and speeds up transfers. Also improved OneDrive backup
# 25-5-2022: v1.1 Added Apple Mail signatures
# 22-5-2022: v1.0 Initial script to import the data exported using export_MacOS.sh script
# This script should be placed and run from the root directory of the external drive e.g. /Volumes/$DRIVE/import_MacOS.sh
# All output is logged to a file called MacOS.Import.$(date +%d.%m.%Y.%H.%M.%S).log in the same location as the script

## When running as a .command file that can be double clicked it defaults the script path to ~/ rather than the external drive. The below command changes directory to the external drive.
cd $(dirname "$0")

## Check for log folder and create if non existent
if [ -d ./Script\ logs ]; then
echo "Log path exists"
else
mkdir ./Script\ logs
echo "Created Script logs folder"
fi 

## I want a timer at the end of the script, so create a variable with the date in seconds I can subtract from the end
scriptstart=$(date +%s)

(

## Create some variables to make the text bold as required
bold=$(tput bold)
normal=$(tput sgr0)

## Without full disk access the script will fail to copy anything into the Library folder (and this won't even prompt at all unlike the User folders)
echo "${bold}To successfully restore all files the terminal should be given full disk access."
echo "To allow this, open system preferences, select Security & Privacy, select the Privacy tab along the top, then ensure the Terminal is ticked under Full Disk Access.${normal}"
echo -ne "Has the terminal got full disk access?\n 1: Yes (continue)\n 2: No (Stop the script)\n : "
read diskaccess

if [[ $diskaccess -eq 1 ]]; then

## Run caffeinate to prevent the computer from going to sleep during backup
echo ""
echo "Running caffeinate to prevent computer from locking or suspending"
caffeinate -disu -t 9999999999999 &

## First prompt which folder to backup from
printf "Please select folder you would like to restore from:\n"
select d in */; do test -n "$d" && break; echo ">>> Invalid Selection"; done
cd "$d" && SOURCEDIR=$(pwd)
echo "The backup source directory is $SOURCEDIR"
echo -ne "Is this the correct backup source?\n 1: Yes\n 2: No\n : "
read PROCEED

## If the correct backup location was chosen then continue...
if [[ PROCEED -eq 1 ]]; then

## hdiutil won't attach if the start of the path is within a variable... So this line extracts the foldername chosen
#FOLDER=$(echo "$SOURCEDIR" | rev | cut -d / -f -1 | rev)
#echo "the name of the folder is $FOLDER"

hdiutil attach $SOURCEDIR/backup_drive.sparseimage

SOURCE=/Volumes/backup

## If OneDrive is present on the new computer, then calculate the size of both the OneDrive and the normal user files into the filesize variable. Otherwise just calculate the normal user files.
if [ -d "$SOURCE/OneDrive" ]; then
    echo ""
    echo -ne "OneDrive backup is found on external drive. Do you want to restore OneDrive?\n 1: Yes\n 2: No\n : "
    read restoreonedrive 
    else
    echo ""
fi

if [ -d "$SOURCE/OneDrive" ] && [[ $restoreonedrive -eq 1 ]]; then
    onedrivesize=$(du -sm "$SOURCE/OneDrive/" | cut -f1)
    filesize1=$(du -sm "$SOURCE/Files/" | cut -f1)
    filesize=$(( $onedrivesize + $filesize1 ))
else
    filesize=$(du -sm "$SOURCE/Files/" | cut -f1)
fi

## Print onto the console the total size of the files to transfer
echo ""
echo "The total size to restore from the external drive is $filesize MB"

## Put the total free space (in MB) into a variable for direct comparison
echo ""
freespace=$(df -m / | grep "/" | awk '{print $4}')
echo "The total free space on the internal drive is $freespace MB"

## Free diskspace check and exit if not enough space
if [ $freespace -gt $filesize ]; then

## Restore Chrome Bookmarks
echo "Opening chrome to create bookmarks file.."
open -a /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome
sleep 15
pkill Google\ Chrome
echo "Replacing Bookmarks from backup..."
cp -av "$SOURCE/Bookmarks/Chrome/Bookmarks" "/Users/$USER/Library/Application Support/Google/Chrome/Default/"
echo "Chrome Bookmarks restored"

## Restore Safari Bookmarks
echo "Opening Safari to create bookmarks file"
open -a /Applications/Safari.app/Contents/MacOS/Safari
sleep 15
pkill Safari
echo "Replacing Bookmarks from Backup"
cp -av "$SOURCE/Bookmarks/Safari/Bookmarks.plist" "/Users/$USER/Library/Safari/"
echo "Safari Bookmarks restored"

## Restore Firefox Bookmarks
echo "Opening Firefox to create a default profile"
open -a /Applications/Firefox.app/Contents/MacOS/firefox
sleep 15
pkill firefox
echo "Copying Firefox bookmarks"
cp -av "/$SOURCE/Bookmarks/Firefox/" "/Users/$USER/Library/Application Support/Firefox/Profiles/"*default-release/
echo "Firefox bookmarks restored"

## Restore Outlook Signatures
open -a /Applications/Microsoft\ Outlook.app/Contents/MacOS/Microsoft\ Outlook
sleep 25
pkill Microsoft\ Outlook
echo "Restoring Outlook signatures..."
cp -av "$SOURCE/Office/Outlook/" "/Users/$USER/Library/Group Containers/UBF8T346G9.Office/Outlook/"*Profiles"/Main Profile/Data/"
echo "Outlook signatures restored"

## Restore Mail signatures if they are present
if [ -d "$SOURCE/Mail" ]; then
open -a /System/Applications/Mail.app/Contents/MacOS/Mail
sleep 15
pkill Mail
echo "Restoring Mail signatures..."
mailver=$(ls /Users/$USER/Library/Mail/ | grep "V")
mkdir "/Users/$USER/Library/Mail/$mailver/MailData/Signatures/"
cp -av "$SOURCE/Mail/" "/Users/$USER/Library/Mail/$mailver/MailData/Signatures/"
echo "Mail signatures restored"
else
echo ""
fi

## Restore Office autocorrect files
echo "Restoring Office Autocorrect files..."
cp -av "$SOURCE/Office/Autocorrects/" "/Users/$USER/Library/Group Containers/UBF8T346G9.Office/"
echo "Office autocorrects restored"

## Restore Network configuration
echo "Restoring Network storage favourites..."
cp -av "$SOURCE/Network_Locations/" "/Users/$USER/Library/Application Support/com.apple.sharedfilelist/"
echo "Restored Network storage favourites"

## Restore the main User files
USER=$(id -un)
cp -av "$SOURCE/Files/Users/"*"/" /Users/$USER/

## Restore OneDrive Files if present
if [[ $restoreonedrive -eq 1 ]]; then

if [ -d /Users/$USER/Library/CloudStorage/*OneDrive* ]; then
    echo ""
    echo "Copying OneDrive files..."
    cp -av "$SOURCE/OneDrive/" "/Users/$USER/Library/CloudStorage/"*OneDrive*/
    echo ""
    echo "${bold}OneDrive files copied${normal}"
else
    echo ""
    echo ""
    echo "${bold}The OneDrive directory doesn't yet exist, OneDrive must be running and set up before restoring OneDrive files."
    echo "Minimise the terminal and log into OneDrive and set up the folder sync, once the initial sync is complete, return here and type 1 to continue"
    echo -ne "Do you want to try again copying OneDrive files?\n 1. Yes\n 2. No\n : ${normal}"
    read retryonedrive
    if [ -d /Users/$USER/Library/CloudStorage/*OneDrive* ] && [[ $retryonedrive -eq 1 ]]; then
        echo ""
        echo "Copying OneDrive files..."
        cp -av "$SOURCE/OneDrive/" "/Users/$USER/Library/CloudStorage/"*OneDrive*/
        echo "OneDrive files copied"
    else
        echo ""
        echo "${bold}Either OneDrive files were chosen not to be copied, or the directory still does not exist"
        echo "Skipping OneDrive restore. You can fix this manually later if desired. ${normal}"
        echo ""
    fi

fi

else
echo ""
fi
echo ""
# Detach the disk image
echo "Detaching the backup disk image"
hdiutil detach /Volumes/backup

scriptend=$(date +%s)
timetotalsecs=$(($scriptend - $scriptstart))


echo "${bold}The script is now complete. Check all files transferred correctly and there were no errors in the script."
echo "The total time of the script was $timetotalsecs seconds${normal}"

echo "You must log out and back in for the favourite servers list to populate${normal}"
echo ""
else
    echo "${bold}There is not enough space for all files. This will have to be manually managed."
fi

else
echo "${bold}The script was aborted as requested. The incorrect Backup location was chosen."
fi

## Kill caffeinate once the script completes
echo "Closing caffeinate so that the computer can sleep again!"
pkill caffeinate &

else
echo "${bold}Script has ended as the terminal does not have full disk access yet. Allow access then run the script again${normal}"
fi

) 2>&1 | tee ./Script\ logs/MacOS.Import.$(date +%d.%m.%Y.%H.%M.%S).log
