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
DEST=$1$EXT
ERROR_EXT="$EXT-errors"
ERROR_DEST=$1$ERROR_EXT
DIR=`dirname "$(readlink -f "$0")"`
ERRORS_DIR="$DIR/yala-errors/*"

RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
    echo "Check complete."
    echo "Checking known errors tar update."
    SUM=`md5sum $DIR/yala-errors.tar.xz | awk '{ print $1 }'`
    NEWSUM=`curl https://raw.githubusercontent.com/aogburn/yala/main/tarmd5`
    echo $DIR
    echo $SUM
    echo $NEWSUM
    if [ "x$NEWSUM" != "x" ]; then
        if [ $SUM != $NEWSUM ]; then
            echo "Version difference detected.  Downloading new tar."
            wget -q https://raw.githubusercontent.com/aogburn/yala/main/yala-errors.tar.xz -O $DIR/yala-errors.tar.xz
            tar -xf yala-errors.tar.xz
        fi
    fi
fi

#Summarize info
echo
echo -e "${RED}### Summarizing $FILE_NAME - see $DEST for more info and $ERROR_DEST for critical error suggestions ###${NC}"
echo "### Summary of $FILE_NAME ###" > $DEST

{
echo
echo "### Overview ###" 
echo
}  | tee -a $DEST

echo -en "${BLUE}"
echo -e "*** First and last lines of $FILE_NAME ***" | tee -a $DEST
echo -en "${NC}"
{
grep "[0-2][0-9]:[0-5][0-9]:[0-5][0-9]" $FILE_NAME | head -n 1
grep "[0-2][0-9]:[0-5][0-9]:[0-5][0-9]" $FILE_NAME | tail -n 1
echo
}  | tee -a $DEST


echo -en "${BLUE}"
echo -e "*** VM args and info of $FILE_NAME ***" | tee -a $DEST
echo -en "${NC}"
{
grep "java.runtime.name =" $FILE_NAME | uniq
grep "java.runtime.version =" $FILE_NAME | uniq
grep "sun.java.command = " $FILE_NAME | uniq
echo
echo -n "	"
grep "DEBUG \[org.jboss.as.config\] (MSC service thread 1-[0-9]) VM Arguments: " $FILE_NAME | sed 's/^.*VM Arguments/VMArguments/g' | uniq
echo
} | tee -a $DEST


echo -en "${BLUE}"
echo -e "*** Start and stop events of $FILE_NAME ***" | tee -a $DEST
echo -en "${NC}"
{
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
egrep "WFLYSRV0026|WFLYSRV0049|WFLYSRV0050|WFLYSRV0211|WFLYSRV0212|WFLYSRV0215|WFLYSRV0220|WFLYSRV0236|WFLYSRV0239|WFLYSRV0240|WFLYSRV0241|WFLYSRV0260|WFLYSRV0272|WFLYSRV0282|WFLYSRV0283" $FILE_NAME
echo
} | tee -a $DEST


{
echo "*** Notable ports of $FILE_NAME ***"
# WFLYSRV005[1-3] - admin console port
# WFLYSRV006[1-3] - http console port
# WFLYUT0006 - UT listener listening
# WFLYUT0007 - UT listener stopped
# WFLYUT0008 - UT listener suspending
egrep "WFLYUT000[6-8]|WFLYSRV005[1-3]" $FILE_NAME
echo


echo "*** Deployment activity of $FILE_NAME ***"
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
egrep "WFLYSRV000[7-9]|WFLYSRV001[0-6]|WFLYSRV002[0-2]|WFLYSRV002[7-8]|WFLYSRV0070|WFLYSRV0087|WFLYSRV0205|WFLYSRV020[7-8]|WFLYSRV0219|WFLYSRV023[3-4]" $FILE_NAME
echo

echo "*** Application context registrations of $FILE_NAME ***"
# WFLYUT0021 - register
# WFLYUT0022 - unregister
grep "WFLYUT002[1-2]" $FILE_NAME
echo
} >> $DEST



#Summarize ERRORS
echo -en "${RED}"
echo "### ERROR Summary of $FILE_NAME ###" | tee $ERROR_DEST
echo | tee -a $ERROR_DEST
echo -en "${NC}"

echo -en "${BLUE}"
echo "*** Known critical errors defined in $ERRORS_DIR - see $ERROR_DEST for more error summaries ***" $ERROR_DEST
echo -en "${NC}"
echo "*** Known critical errors defined in $ERRORS_DIR ***" >> $ERROR_DEST
echo | tee -a $ERROR_DEST
i=1
j=0
for f in $ERRORS_DIR
do
    ERROR_STRING=`head -n 1 $f`
    ERROR_COUNT=`egrep "$ERROR_STRING" $FILE_NAME | wc -l`
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
        echo "        * Occurrences in $FILE_NAME: "
        echo
        grep "$ERROR_STRING" $FILE_NAME | uniq
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
echo "*** $i known ERRORS found of $j checked. ***"
echo
} | tee -a $ERROR_DEST


echo -en "${BLUE}"
echo "*** Counts of other errors in $FILE_NAME:***" | tee -a $ERROR_DEST
echo -en "${NC}"
grep " ERROR \[" $FILE_NAME | sed 's/^.* ERROR \[.*\] ([^)]*) //g' | sed 's/^.* ERROR \[.*] //g' | sort | uniq -c | sort -nr | tee -a $ERROR_DEST
