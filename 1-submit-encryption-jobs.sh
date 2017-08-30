#!/bin/bash

# INFO: if you want to restart the encryption for a file, delete all the corresponding *.md5 and *.gpg files
#
# This script will automatically find the most-recent "filelist*.txt" file and process files therein.
# If you wish to use a different filelist, you can specify this as a command line argument:
#   1-submit-encryption-jobs.sh your-filelist.txt

# find wherever this script is, and load the util library next to it
source ${BASH_SOURCE%/*}/util.sh

# Get default, latest input file, OR whatever the user wants
OVERRIDE_FILE="$1"
FILE_LIST=$(get_default_or_override_filelist "$OVERRIDE_FILE");
verify_filelist "$FILE_LIST"

echo "using file-list: $FILE_LIST"

# Get files from file_list that DON'T have a corresponding .gpg file
# TODO: when adapting FILE_LIST to have non-absolute paths, also adapt this spot
unencryptedFiles=$(\
  comm -23 \
   <(sort "$FILE_LIST") \
   <( \
      find $(pwd) -type f \( -name "*.gpg" -or -name "*.gpg.partial" \) \
      | sed -E "s/\.gpg(.partial)?//g" \
      | sort \
    ) \
)

WORKDIR=$(pwd)
SUBMITLOG="$WORKDIR/_submitted_jobs_"$(date +%Y-%m-%d_%H:%M:%S)
JOBLOGDIR="$WORKDIR/cluster-logs"
if [ ! -d "$JOBLOGDIR" ]; then
  mkdir "$JOBLOGDIR"
fi

for FULL_FILE in $unencryptedFiles; do
  if [ ! -e "$FULL_FILE" ]; then
    echo "WARNING: File not found: $FULL_FILE" | tee -a $SUBMITLOG
  else
    SHORTNAME=$(basename $FULL_FILE)
    # prepend filename before qsub job-id output (intentionally no newline!)
    printf "%-29s\t" $SHORTNAME | tee -a $SUBMITLOG
    # actual job submission, prints job-id
    qsub \
        -v FULL_FILE=$FULL_FILE,WORKDIR=$WORKDIR \
        -N "ega-encryption-$SHORTNAME" \
        -e "$JOBLOGDIR" \
        -o "$JOBLOGDIR" \
        ${BASH_SOURCE%/*}/PBSJOB-ega-encryption.sh | tee -a $SUBMITLOG
  fi
done
