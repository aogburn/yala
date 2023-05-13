#!/bin/bash
#
# Yala is just Yet Another Log Analyzer.  It focuses on 
# providing quick JBoss EAP 7+ server log summaries,
# highlighting known critical ERRORs, and counts of
# other general errors at a glance.
#
# Usage: sh ./yala.sh <SERVER_LOG>


FILE_NAME=$1
EXT=".yala"
TRIM_FILE="$FILE_NAME$EXT-trim"
TMP_FILE="$FILE_NAME$EXT-tmp"
TMP_FILE2="$FILE_NAME$EXT-tmp2"
DEST=$1$EXT
ERROR_EXT="$EXT-errors"
export ERROR_DEST=$1$ERROR_EXT
DIR=`dirname "$(readlink -f "$0")"`
ERRORS_DIR="$DIR/yala-errors/"
SCRIPTS_DIR="$DIR/condition-scripts/"

export RED='\033[0;31m'
export BLUE='\033[0;34m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export NC='\033[0m'

# Check for a new yala.sh.  Uncomment next line if you want to avoid this check
# CHECK_UPDATE="false"
if [ "x$CHECK_UPDATE" = "x" ]; then
    echo "Checking script update. Uncomment CHECK_UPDATE in script if you wish to skip."
    SUM=`md5sum $DIR/yala.sh | awk '{ print $1 }'`
    NEWSUM=`curl https://raw.githubusercontent.com/aogburn/yala/main/md5`
    echo $DIR
    echo $SUM
    echo $NEWSUM
    if [ "x$NEWSUM" != "x" ]; then
        if [ $SUM != $NEWSUM ]; then
            echo "Version difference detected.  Downloading new version. Please re-run yatda."
            wget -q https://raw.githubusercontent.com/aogburn/yala/main/yala.sh -O $DIR/yala.sh
            exit
        fi
    fi
    echo "Checking known errors tar update."
    SUM=`md5sum $DIR/yala-errors.tar.xz | awk '{ print $1 }'`
    NEWSUM=`curl https://raw.githubusercontent.com/aogburn/yala/main/tarmd5`
    echo $DIR
    echo $SUM
    echo $NEWSUM
    if [ "x$NEWSUM" != "x" ]; then
        if [ "x$SUM" == "x" ]; then
            SUM=0
        fi
        if [ $SUM != $NEWSUM ]; then
            echo "Version difference detected.  Downloading new tar."
            wget -q https://raw.githubusercontent.com/aogburn/yala/main/yala-errors.tar.xz -O $DIR/yala-errors.tar.xz
            tar -xf yala-errors.tar.xz
            chmod -R 755 $SCRIPTS_DIR
        fi
    fi
    echo "Checks complete."
fi


if [ ! -f "$FILE_NAME" ]; then
    echo "$FILE_NAME does not exist."
    exit
fi


#Summarize info
echo
echo -e "${RED}### Summarizing $FILE_NAME - see $DEST for more info and $ERROR_DEST for critical error suggestions ###${NC}"
echo "### Summary of $FILE_NAME ###" > $DEST


#trim file of unneeded exception stack trace lines and empty lines
grep -E -v " at .*(.*)$|	at .*(.*)|^$" $FILE_NAME > $TRIM_FILE

{
echo
echo "### Overview ###" 
echo
}  | tee -a $DEST

echo -en "${BLUE}"
echo -e "*** First and last lines of $FILE_NAME ***" | tee -a $DEST
echo -en "${NC}"
{
head -n 1 "$TRIM_FILE"
tail -n 1 "$TRIM_FILE"
echo
}  | tee -a $DEST


echo -en "${BLUE}"
echo -e "*** VM args and info of $FILE_NAME ***" | tee -a $DEST
echo -en "${NC}"
{
grep "java.runtime.name =" $TRIM_FILE | uniq
grep "java.runtime.version =" $TRIM_FILE | uniq
grep "sun.java.command = " $TRIM_FILE | uniq
echo
echo -n "	"
grep "DEBUG \[org.jboss.as.config\] (MSC service thread 1-[0-9]) VM Arguments: " $TRIM_FILE | sed 's/^.*VM Arguments/VMArguments/g' | uniq
echo
} | tee -a $DEST


echo -en "${BLUE}"
echo -e "*** Start and stop events of $FILE_NAME ***" | tee -a $DEST
echo -en "${NC}"

# WFLYSRV0026 - started
# WFLYSRV0049 - starting
# WFLYSRV0050 - stopped
# WFLYSRV0211 - suspending with timeout
# WFLYSRV0212 - resuming
# WFLYSRV0215 - failed to resume
# WFLYSRV0220 - stopping from OS signal
# WFLYSRV0236 - suspending without timeout
# WFLYSRV0239 - aborting
# WFLYSRV0240 - ProcessController shutdown signal
# WFLYSRV0241 - management op shutdown
# WFLYSRV0260 - starting suspended
# WFLYSRV0282 - startingNonGraceful
# WFLYSRV0283 - disregardingNonGraceful
# WFLYSRV0272 - suspending
{
grep -E "WFLYSRV0026|WFLYSRV0049|WFLYSRV0050|WFLYSRV0211|WFLYSRV0212|WFLYSRV0215|WFLYSRV0220|WFLYSRV0236|WFLYSRV0239|WFLYSRV0240|WFLYSRV0241|WFLYSRV0260|WFLYSRV0272|WFLYSRV0282|WFLYSRV0283" $TRIM_FILE
echo
} | tee -a $DEST

echo -en "${BLUE}"
echo "*** Notable ports of $FILE_NAME ***" | tee -a $DEST
echo -en "${NC}"
# WFLYSRV005[1-3] - admin console port
# WFLYSRV006[1-3] - http console port
# WFLYUT0006 - UT listener listening
# WFLYUT0007 - UT listener stopped
# WFLYUT0008 - UT listener suspending
{
grep -E "WFLYUT000[6-8]|WFLYSRV005[1-3]" $TRIM_FILE
echo
} | tee -a $DEST


echo -en "${BLUE}"
echo "*** Deployment activity of $FILE_NAME ***" | tee -a $DEST
echo -en "${NC}"
# WFLYSRV0007 - undeploy rolled back with failure
# WFLYSRV0008 - undeploy rolled back with no failure
# WFLYSRV0009 - undeployed
# WFLYSRV0010 - deployed
# WFLYSRV0011 - redeploy rolled back with failure
# WFLYSRV0012 - redeploy rolled back with no failure
# WFLYSRV0013 - redeployed
# WFLYSRV0014 - replacement rolled back with failure
# WFLYSRV0015 - replacement rolled back with no failure
# WFLYSRV0016 - replaced
# WFLYSRV0020 - exception removing deployment
# WFLYSRV0021 - deployment rolled back with failure
# WFLYSRV0022 - deployment rolled back with no failure
# WFLYSRV0027 - starting deployment
# WFLYSRV0028 - stopped deployment
# WFLYSRV0070 - Deployment restart detected
# WFLYSRV0087 - Deployment already started
# WFLYSRV0205 - already a deployment
# WFLYSRV0207 - starting subdeployment
# WFLYSRV0208 - stopping subdeployment
# WFLYSRV0219 - has been redeployed
# WFLYSRV0233 - undeployed
# WFLYSRV0234 - deployed
{
grep -E "WFLYSRV000[7-9]|WFLYSRV001[0-6]|WFLYSRV002[0-2]|WFLYSRV002[7-8]|WFLYSRV0070|WFLYSRV0087|WFLYSRV0205|WFLYSRV020[7-8]|WFLYSRV0219|WFLYSRV023[3-4]" $TRIM_FILE
echo
} | tee -a $DEST


echo -en "${BLUE}"
echo "*** Application context registrations of $FILE_NAME ***" | tee -a $DEST
echo -en "${NC}"
# WFLYUT0021 - register
# WFLYUT0022 - unregister
{
grep "WFLYUT002[1-2]" $TRIM_FILE
echo
} | tee -a $DEST



#Summarize ERRORS
echo -en "${RED}"
echo "### ERROR Summary of $FILE_NAME ###" | tee $ERROR_DEST
echo | tee -a $ERROR_DEST
echo -en "${NC}"


if [ ! -d $ERRORS_DIR ]; then
    echo "Not checking known critical errors as $ERRORS_DIR does not exist" | tee -a $ERROR_DEST
    echo
else
    echo -en "${BLUE}"
    echo "*** Known critical errors defined in $ERRORS_DIR ***" | tee -a $ERROR_DEST
    echo -en "${NC}"
    echo | tee -a $ERROR_DEST
    i=1
    j=0
    for f in $ERRORS_DIR*
    do
        ERROR_STRING=`head -n 1 $f`
        grep -E "$ERROR_STRING" $TRIM_FILE > $TMP_FILE
        ERROR_COUNT=`cat $TMP_FILE | wc -l`
        if [ $ERROR_COUNT -gt 0 ]; then
            echo -en "${GREEN}"
            {
            echo "    $i. Occurrences of \"$ERROR_STRING\" in $FILE_NAME: $ERROR_COUNT"
            echo "        * Suggested KCS: `sed -n 2p $f`"
            echo "        * Suggested comment: "
            echo
            } | tee -a $ERROR_DEST

            echo -en "${YELLOW}"
            {
            tail -n +3 $f
            echo
            } | tee -a $ERROR_DEST
            echo -en "${GREEN}"

            {
            echo "        * Sample occurrences in $FILE_NAME: "
            echo
            if [ $ERROR_COUNT -gt 10 ]; then
                head -n 5 $TMP_FILE
                echo "..."
                tail -n 5 $TMP_FILE
            else
                cat $TMP_FILE
            fi
            echo
            } | tee -a $ERROR_DEST
            i=$((i+1))
        fi
    j=$((j+1))
    done
    i=$((i-1))

    echo -en "${RED}"
    {
    echo
    echo "*** $i known ERRORS found of $j checked ***"
    echo
    } | tee -a $ERROR_DEST
fi


# Summarize any more complex known conditions to check
if [ ! -d $SCRIPTS_DIR ]; then
    echo "Not checking other known concerns as $SCRIPTS_DIR does not exist" | tee -a $ERROR_DEST
    echo
else
#reset error counters
    j=0

    echo -en "${BLUE}"
    echo "*** Known concerns defined in $SCRIPTS_DIR ***" | tee -a $ERROR_DEST
    echo -en "${NC}"
    echo | tee -a $ERROR_DEST
    for f in $SCRIPTS_DIR*
    do
        $f $TRIM_FILE
        j=$((j+1))
    done

    echo -en "${RED}"
    {
    echo
    echo "*** $j known concerns checked ***"
    echo
    } | tee -a $ERROR_DEST
fi


# parse out ERROR strings stripped of categories and threads
#grep " ERROR \[" $TRIM_FILE | sed 's/^.* ERROR \[.*\] ([^)]*) //g' | sed 's/^.* ERROR \[.*] //g' > $TMP_FILE
grep " ERROR \[" $TRIM_FILE | sed -E 's/^.* ERROR \[(.*)\] \([^)]*\) /[\1] /g' | sed -E 's/^.* ERROR \[(.*)] /[\1] /g' > $TMP_FILE
#count total
ERROR_COUNT=`cat $TMP_FILE | wc -l`
#sort and count uniques
cat $TMP_FILE | sort | uniq -c -w 150 | sort -nr > $TMP_FILE2
UNIQUE_COUNT=`cat $TMP_FILE2 | wc -l`
echo -en "${BLUE}"
echo "*** Counts of other errors in $FILE_NAME - $ERROR_COUNT total error occurrences of $UNIQUE_COUNT unique error types ***" | tee -a $ERROR_DEST
echo "*** top 20 - see $ERROR_DEST for more ***"
echo -en "${NC}"
head -n 20 $TMP_FILE2
cat $TMP_FILE2 >> $ERROR_DEST
#grep " ERROR \[" $TRIM_FILE | sed 's/^.* ERROR \[.*\] ([^)]*) //g' | sed 's/^.* ERROR \[.*] //g' | sort | uniq -c -w 150 | sort -nr | tee -a $ERROR_DEST

#clean up extras
rm -rf $TRIM_FILE
rm -rf $TMP_FILE
rm -rf $TMP_FILE2
