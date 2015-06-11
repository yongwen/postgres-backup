# Notes:
# 1. Backups are stored in the /wattdepot-backups directory.
#    They are .tar.gz archives that contain:
#    - A plain text dump of the wattdepot database
#    - $WATTDEPOT_USER_HOMEDIR/.wattdepot/
#    - $WATTDEPOT_USER_HOMEDIR/wattdepot-$WATTDEPOT_VERSION
# 2. Backup names are timestamped to the second.
# 3. Backups taken on the first day of the month are copied to 
#    a new monthly backup in the /wattdepot-backups/monthly/ directory.
# 4. The script deletes any daily backups more than 7 days 
#    (604800 seconds) old. It asks the user before doing this. 
# 5. Run the script with --delete-auto to delete the old backups 
#    automatically.
# 6. The PGPASSWORD environment variable must be set to the password of 
#    PostgreSQL's "wattdepot" user for this script to work correctly.
#    If PGPASSWORD is not set, the user will be prompted for a password
#    when it runs.

cd /wattdepot-backups
# Set WATTDEPOT_VERSION to your current version
export WATTDEPOT_VERSION="2.2.1"
# Set location of pg_dump executable
export PG_DUMP_PATH="/usr/pgsql-9.1/bin"
# Set location of wattdepot user's home directory (where .wattdepot and wattdepot-$WATTDEPOT_VERSION are)
export WATTDEPOT_USER_HOMEDIR="/home/wattdepot"
export BACKUPTIME=$(date +"%Y-%m-%d_%H_%M_%S")
export NEW_DAILY_BACKUP="wattdepot_backup_$BACKUPTIME"
echo "Creating backup: /wattdepot-backups/$NEW_DAILY_BACKUP"
mkdir $NEW_DAILY_BACKUP
cd $NEW_DAILY_BACKUP
touch plaintext_backup.dump
$PG_DUMP_PATH/pg_dump -Fp --no-acl --no-owner -h localhost -U wattdepot wattdepot > plaintext_backup.dump
cp -R $WATTDEPOT_USER_HOMEDIR/.wattdepot /wattdepot-backups/$NEW_DAILY_BACKUP/.wattdepot
cp -R $WATTDEPOT_USER_HOMEDIR/wattdepot-$WATTDEPOT_VERSION /wattdepot-backups/$NEW_DAILY_BACKUP/wattdepot-$WATTDEPOT_VERSION
cd ../
tar -czf $NEW_DAILY_BACKUP.tar.gz ./$NEW_DAILY_BACKUP/
rm -rf $NEW_DAILY_BACKUP
echo "Backup compressed and stored at /wattdepot-backups/$NEW_DAILY_BACKUP.tar.gz"

# If it is the first day of the month, copy the backup to /wattdepot-backups/monthly/
if [ $(date +"%d") = "01" ];
    then
        export NEW_MONTHLY_BACKUP="wattdepot_monthly_backup_$BACKUPTIME.tar.gz"
        cp $NEW_DAILY_BACKUP.tar.gz /wattdepot-backups/monthly/$NEW_MONTHLY_BACKUP
        echo "Monthly backup created at /wattdepot-backups/monthly/$NEW_MONTHLY_BACKUP"
        unset NEW_MONTHLY_BACKUP
fi

# Environment variables cleanup
unset WATTDEPOT_VERSION
unset PG_DUMP_LOCATION
unset BACKUP_WATTDEPOT_USER_HOME
unset BACKUPTIME
unset NEW_DAILY_BACKUP

# Remove old daily backups
cd /wattdepot-backups
export CURRENT_TIME=$(date +%s)
export OLD_BACKUP_COUNT=0
echo "Removing daily backups more than 7 days (604800 seconds) old."
echo "The following backups will be deleted:"
for FILE in $(find ./*.tar.gz -maxdepth 1 -type f); do
    export CURRENT_FILE_TIME=$(stat -c %Z $FILE)
    export CURRENT_FILE_AGE=$(expr $CURRENT_TIME - $CURRENT_FILE_TIME)
    if [ $CURRENT_FILE_AGE -gt 604800 ];
        then
            export OLD_BACKUP_COUNT=$(expr $OLD_BACKUP_COUNT + 1)
            echo "$FILE"
    fi
    unset CURRENT_FILE_TIME
    unset CURRENT_FILE_AGE
done

if [ $OLD_BACKUP_COUNT -eq 0 ];
    then
        echo "No old backups to delete."
        echo "Script completed successfully."
        unset OLD_BACKUP_COUNT
        exit
fi

# If the --delete-auto flag is set, don't ask the user. 
# Just delete the old backups automatically. 
if [ "$1" = "--delete-auto" ];
    then
        export DO_DELETE_BACKUPS="Yes"
    else
        # Use junk value for initial value
        export DO_DELETE_BACKUPS="Foo"
fi

while [ $DO_DELETE_BACKUPS != "Yes" ] && [ $DO_DELETE_BACKUPS != "No" ];
do
    echo "Delete these backups? This operation cannot be undone. [Yes/No]"
    read DO_DELETE_BACKUPS
    if [ $DO_DELETE_BACKUPS = "Yes" ];
        then
            echo "Continuing..."
        else
            if [ $DO_DELETE_BACKUPS = "No" ];
                then
                    echo "Backup process completed without removing old backups."
                    echo "Script completed successfully."
                    unset DO_DELETE_BACKUPS
                    exit
            fi
    fi
done
unset DO_DELETE_BACKUPS

echo "Removing daily backups more than 7 days (604800 seconds) old."
for FILE in $(find ./*.tar.gz -maxdepth 1 -type f); do
    CURRENT_FILE_TIME=$(stat -c %Z $FILE)
    CURRENT_FILE_AGE=$(expr $CURRENT_TIME - $CURRENT_FILE_TIME)
    if [ $CURRENT_FILE_AGE -gt 604800 ];
        then
            rm $FILE
            echo "Deleted daily backup archive $FILE."
    fi
    unset CURRENT_FILE_TIME
    unset CURRENT_FILE_AGE
done 
echo "Removal of old daily backups is complete."
