# MacOS-backup-restore
Bash scripts written to backup and restore user data from old MacOS to new MacOS computer for situations where migration assistant can't be used.

The MacOS export and restore scripts can be used to backup and restore all user data and key settings from an old computer to a new one during a migration. Or for a backup to be taken to be later restored on another MacOS. These scripts are written using Bash as the interpreter.

The MacOS backup and restore scripts do the following…

1. Checks for OneDrive, asks if you want to backup OneDrive or not (sync errors are common on MacOS particularly due to illegal filenames, so unsynced files may want to be copied to the new computer then fix the sync errors there)
2. Checks space on external drive and stops if there is not enough free space
3. Runs caffeinate to prevent computer from going to sleep
4. Creates folder named “$username_$date”
5. Creates APFS disk image to copy data into (this copies extended attributes and resource forks even if external drive is formatted as ExFAT)
6. Backs up following data into disk image
7. List of printers installed
8. Chrome, Safari and Firefox Bookmarks
9. Office autocorrect files
10. Outlook signatures
11. Apple Mail signatures
12. Favourite servers list (i.e. saved smb shares)
13. ALL DATA in the user directory except Library, Applications, Public, Sites, Dropbox, Syncplicity, Onedrive or any hidden folders starting with “.”
14. Closes caffeinate
15. Summarises the script output including total size backed up and total time taken.
16. Logs all output to \Volume\$externaldrive\Script logs\

Instructions of use
1. Put scripts on external drive to copy data onto
2. Run export_MacOS.command on computer to backup user data
3. Run import_MacOS.command on computer to restore user data

IMPORTANT NOTE: Terminal must have full disk access on both the old and the new computer to function correctly
