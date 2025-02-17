#!/bin/bash
#
# Yala is just Yet Another Log Analyzer.  It focuses on 
# providing quick JBoss EAP 7+ server log summaries,
# highlighting known critical ERRORs, and counts of
# other general errors at a glance.
#
# Usage: sh ./yala.sh <SERVER_LOG>

VALID_UPDATE_MODES=(force ask never)

YALA_SH="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
YALA_ERRORS="yala-errors.tar.xz"

usage() {
    if [ ! "x$1" = "x" ]; then
        echo
        echo -e "$1"
        echo
    fi
    echo "Usage:"
    echo " sh ./$YALA_SH <options> <SERVER_LOG>"
    echo
    echo "Yala is just Yet Another Log Analyzer. It focuses on "
    echo "providing quick JBoss EAP 7+ server log summaries,"
    echo "highlighting known critical ERRORs, and counts of"
    echo "other general errors at a glance."
    echo
    echo "Options:"
    echo " -l, --last              analyse the last started JBoss only"
    echo " -c, --config            use a custom config file located in the '\$HOME/.yala/' folder. Values"
    echo "                         in the provided file take precedence over the default '\$HOME/.yala/config'"
    echo "                         file and are superseeded by command line options"
    echo " -u, --updateMode        the update mode to use, one of [${VALID_UPDATE_MODES[*]}], default: force"
    echo " -t, --threadSplit       split messages to a separate log file for each thread"
    echo " -h, --help              show this help" 
}

# is_valid_option <argument> <array> <option>
is_valid_option() {
    ARGUMENT=$1
    ARRAY=$2
    OPTION=$3
    
    if [[ ! " ${ARRAY[*]} " =~ " ${ARGUMENT} " ]]; then
        echo "${YALA_SH}: invalid argument '$ARGUMENT' for option '$OPTION', must be one of [${ARRAY[*]}]"
        return 22 # -> Invalid Argument
    else
        return 0  # -> Success
    fi
}

# source a global $HOME/.yala/config if available
if [ -d $HOME/.yala ] && [ -f $HOME/.yala/config ]; then
    source $HOME/.yala/config 
fi

# set required variables with default values, if not set in $HOME/.yala/config
[ -z $UPDATE_MODE ] && UPDATE_MODE="force"
[ -z $MD5 ] && MD5="https://raw.githubusercontent.com/aogburn/yala/main/md5"
[ -z $TAR_MD5 ] && TAR_MD5="https://raw.githubusercontent.com/aogburn/yala/main/tarmd5"
[ -z $REMOTE_YALA_SH ] && REMOTE_YALA_SH="https://raw.githubusercontent.com/aogburn/yala/main/yala.sh"
[ -z $REMOTE_YALA_ERRORS ] && REMOTE_YALA_ERRORS="https://raw.githubusercontent.com/aogburn/yala/main/yala-errors.tar.xz"

# parse the cli options
OPTS=$(getopt -o 'h,l,t,c:,u:' --long 'help,last,threadSplit,config:,updateMode:' -n "${YALA_SH}" -- "$@")

# if getopt has a returned an error, exit with the return code of getopt
res=$?; [ $res -gt 0 ] && exit $res

eval set -- "$OPTS"
unset OPTS

while true; do
    case "$1" in
        '-h'|'--help')
            usage; exit 0; shift
            ;;
        '-l'|'--last')
            LAST_STARTED_ONLY="true"; shift
            ;;
        '-t'|'--threadSplit')
            THREAD_SPLIT="true"; shift
            ;;
        '-c'|'--config')
            if [ -f $HOME/.yala/$2 ]; then
                source $HOME/.yala/$2
                shift 2
            else
                echo "config file '$2' does not exist in '$HOME/.yala/'"
                exit 1
            fi
            ;;
        '-u'|'--updateMode')
            is_valid_option "$2" "${VALID_UPDATE_MODES[*]}" "-u, --update"
            result=$?
            if [ $result -gt 0 ]; then
                exit $result
            fi
            UPDATE_MODE=$2
            shift 2
            ;;
        '--') shift; break;;
        * )
            echo "Invalid Option: $1"
            echo ""
            usage; exit; shift
            ;;
    esac
done

# check if filename is given
if [ $# -eq 0 ]; then
    echo "${YALA_SH}: <SERVER_LOG> argument missing."
    exit 22
fi

# after parsing the options, '$1' is the file name
FILE_NAME=$1
FILE_PREFIX="file://"
FULL_FILE_NAME=$FILE_PREFIX`readlink -f $FILE_NAME`

EXT=".yala"
TRIM_FILE="$FILE_NAME$EXT-trim"
FULL_STUCK_FILE="$FILE_NAME$EXT-full-stuck"
STUCK_FILE="$FILE_NAME$EXT-stuck"
STUCK_TIME_FILE="$STUCK_FILE-time"
COMPLETED_STUCK_FILE="$STUCK_FILE-completed"
TMP_FILE="$FILE_NAME$EXT-tmp"
TMP_FILE2="$FILE_NAME$EXT-tmp2"
DEST=$1$EXT
FULL_DEST=$FULL_FILE_NAME$EXT
ERROR_EXT="$EXT-errors"
LAST_FILE="$FILE_NAME.lastOnly"

export ERROR_DEST=$1$ERROR_EXT
FULL_ERROR_DEST=$FULL_FILE_NAME$ERROR_EXT
DIR=`dirname "$(readlink -f "$0")"`
ERRORS_DIR="$DIR/yala-errors/"
SCRIPTS_DIR="$DIR/condition-scripts/"

export RED='\033[0;31m'
export BLUE='\033[0;34m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export NC='\033[0m'

# Check for a new yala.sh and yala-errors.tar.xz if UPDATE_MODE is not 'never'
if [ "$UPDATE_MODE" != "never" ]; then
    echo "Checking script update. Use option '-u never' to skip the update check"

    SUM=`md5sum $DIR/$YALA_SH | awk '{ print $1 }'`
    NEWSUM=$(curl -s $MD5)

    if [ "x$NEWSUM" != "x" ]; then
        if [ $SUM != $NEWSUM ]; then

            echo
            echo "$YALA_SH - $SUM - local"
            echo "$YALA_SH - $NEWSUM - remote"

            if [ "$UPDATE_MODE" = "ask" ]; then
                while true; do
                    echo
                    read -p "A new version of $YALA_SH is available, do you want to update?" yn
                    case $yn in
                        [Yy]* ) UPDATE="true"; break;;
                        [Nn]* ) UPDATE="false"; break;;
                        * ) echo "Choose yes or no.";;
                    esac
                done
            else
                UPDATE="true"
            fi

            if [ "$UPDATE" = "true" ]; then
                echo "Downloading new version. Please re-run $YALA_SH."
                curl -s $REMOTE_YALA_SH -o $DIR/$YALA_SH
                exit
            fi
        fi
    fi

    echo
    echo "Checking known errors tar update."

    SUM=$(md5sum $DIR/$YALA_ERRORS | awk '{ print $1 }')
    NEWSUM=$(curl -s $TAR_MD5)

    if [ "x$NEWSUM" != "x" ]; then
        if [ "x$SUM" == "x" ]; then
            SUM=0
        fi
        if [ $SUM != $NEWSUM ]; then

            echo
            echo "$YALA_ERRORS - $SUM - local"
            echo "$YALA_ERRORS - $NEWSUM - remote"

            if [ "$UPDATE_MODE" = "ask" ]; then
                while true; do
                    echo
                    read -p "A version difference for $YALA_ERRORS was detected, do you want to update?" yn
                    case $yn in
                        [Yy]* ) UPDATE="true"; break;;
                        [Nn]* ) UPDATE="false"; break;;
                        * ) echo "Choose yes or no.";;
                    esac
                done
            else
                UPDATE="true"
            fi

            if [ "$UPDATE" = "true" ]; then
                curl -s $REMOTE_YALA_ERRORS -o $DIR/$YALA_ERRORS
                rm -r $ERRORS_DIR
                tar -xf $YALA_ERRORS
                chmod -R 755 $SCRIPTS_DIR
            fi
        fi
    fi
    echo
    echo "Checks complete."
fi

if [ "x$FILE_NAME" = "x" ]; then
    usage "${RED}No <SERVER_LOG> provided.${NC}"
    exit
elif [ ! -f "$FILE_NAME" ]; then
    usage "${YELLOW}<SERVER_LOG> '$FILE_NAME' does not exist.${NC}"
    exit
fi


#Summarize info
echo
echo -e "${RED}### Summarizing $FULL_FILE_NAME - see $FULL_DEST for more info and $FULL_ERROR_DEST for critical error suggestions ###${NC}"
echo "### Summary of $FULL_FILE_NAME ###" > $DEST

if [ ! -z $LAST_STARTED_ONLY ]; then

    echo
    echo -e "${YELLOW}Analysing the last server start only!${NC}"

    # extract the last server start only...
    sed -n '/WFLYSRV0049/h;//!H;$!d;x;//p' $FILE_NAME > $LAST_FILE
    
    # trim file of unneeded exception stack trace lines and empty lines, last server start only
    grep -E -v " at .*\(.*\)$|	at .*\(.*\)|^$" $LAST_FILE > $TRIM_FILE
else
    #trim file of unneeded exception stack trace lines and empty lines
    grep -E -v " at .*\(.*\)$|	at .*\(.*\)|^$" $FILE_NAME > $TRIM_FILE
fi

{
echo
echo "### Overview ###" 
echo
}  | tee -a $DEST

echo -en "${BLUE}"
echo -e "*** First and last timestamped lines of $FULL_FILE_NAME ***" | tee -a $DEST
echo -en "${NC}"
{
head -n 1000 "$TRIM_FILE" | grep -E "^20[0-9][0-9]\-|^[0-2][0-9]:[0-5][0-9]:[0-5][0-9]" | head -n 1
tail -n 1000 "$TRIM_FILE" | grep -E "^20[0-9][0-9]\-|^[0-2][0-9]:[0-5][0-9]:[0-5][0-9]" | tail -n 1
echo
}  | tee -a $DEST


echo -en "${BLUE}"
echo -e "*** VM args and info of $FULL_FILE_NAME ***" | tee -a $DEST
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
echo -e "*** Start and stop events of $FULL_FILE_NAME ***" | tee -a $DEST
echo -en "${NC}"

# WFLYSRV0025 - started
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
grep -E "WFLYSRV0025|WFLYSRV0026|WFLYSRV0049|WFLYSRV0050|WFLYSRV0211|WFLYSRV0212|WFLYSRV0215|WFLYSRV0220|WFLYSRV0236|WFLYSRV0239|WFLYSRV0240|WFLYSRV0241|WFLYSRV0260|WFLYSRV0272|WFLYSRV0282|WFLYSRV0283" $TRIM_FILE
echo
} | tee -a $DEST

echo -en "${BLUE}"
echo "*** Notable ports of $FULL_FILE_NAME ***" | tee -a $DEST
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
echo "*** Patch information of $FULL_FILE_NAME ***" | tee -a $DEST
echo -en "${NC}"
# WFLYPAT0050 - patch information
{
grep -E "WFLYPAT0050" $TRIM_FILE
echo
} | tee -a $DEST


echo -en "${BLUE}"
echo "*** Deployment activity of $FULL_FILE_NAME ***" | tee -a $DEST
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
echo "*** Application context registrations of $FULL_FILE_NAME ***" | tee -a $DEST
echo -en "${NC}"
# WFLYUT0021 - register
# WFLYUT0022 - unregister
{
grep "WFLYUT002[1-2]" $TRIM_FILE
echo
} | tee -a $DEST



#Summarize ERRORS
echo -en "${RED}"
echo "### ERROR Summary of $FULL_FILE_NAME ###" | tee $ERROR_DEST
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


# Summarize stuck threads
# UT005072 - stuck thread
# UT005073 - stuck thread complete
grep UT005072 -A 30 $FILE_NAME > $FULL_STUCK_FILE
grep UT005072 $FULL_STUCK_FILE > $STUCK_FILE
STUCK_COUNT=`cat $STUCK_FILE | wc -l`
echo -en "${BLUE}"
echo "*** Stuck thread summary ***" | tee -a $DEST
echo -en "${RED}"
echo " * Stuck request occurrences: $STUCK_COUNT" | tee -a $DEST
if [ $STUCK_COUNT -gt 0 ]; then
    grep UT005073 $TRIM_FILE > $COMPLETED_STUCK_FILE
    COMPLETED_STUCK_COUNT=`cat $COMPLETED_STUCK_FILE | wc -l`
    {
    echo " * Stuck requests that completed: $COMPLETED_STUCK_COUNT"
    echo " * Likely remaining incomplete request count: $(( $STUCK_COUNT-$COMPLETED_STUCK_COUNT < 0? 0 : $STUCK_COUNT-$COMPLETED_STUCK_COUNT ))"

    PEAK_STUCK_COUNT=`cat $STUCK_FILE | sed -E 's/.*are (.*) thread.*/\1/g' | sort -nr | head -n1`
    echo " * Peak stuck request count: $PEAK_STUCK_COUNT stuck requests"
    PEAK_STUCK_COUNT_STRING="are $PEAK_STUCK_COUNT thread"
    grep "$PEAK_STUCK_COUNT_STRING" $STUCK_FILE | head -n 5

    cat $COMPLETED_STUCK_FILE | sed -E 's/.*active for approximately (.*) milliseconds.*/\1/g' > $STUCK_TIME_FILE
    AVG_STUCK_TIME=`cat $STUCK_TIME_FILE | awk '{sum += $1; n++} END {print sum / n}'`
    echo " * Average request stuck time: $AVG_STUCK_TIME ms"

    PEAK_STUCK_TIME=`cat $STUCK_TIME_FILE | sort -nr | head -n 1`
    echo " * Longest request stuck time: $PEAK_STUCK_TIME ms"
    grep "$PEAK_STUCK_TIME" $COMPLETED_STUCK_FILE

    echo " * First and last stuck request occurrence:"
    head -n 1 $STUCK_FILE
    tail -n 1 $STUCK_FILE

    echo " * First and last stuck reqeust completion:"
    head -n 1 $COMPLETED_STUCK_FILE
    tail -n 1 $COMPLETED_STUCK_FILE

    echo " * Stuck request URIs:"
    cat $STUCK_FILE | sed -E 's/.*same request for (.*) and may be stuck \(.*/\1/g' | sort | uniq -c | sort -nr | head -n 20

    echo " * Stuck request top line:"
    grep "UT005072" -A 1 $FULL_STUCK_FILE | grep $'\tat' | sed -E 's/.*\tat (.*)/\1/g' | sort | uniq -c | sort -nr

    echo " * Stuck request stack summary of top 30 lines:"
    grep $'\tat' $FULL_STUCK_FILE | sed -E 's/.*\tat (.*)/\1/g' | sort | uniq -c | sort -nr | head -n 45
    } | tee -a $DEST
fi
echo -en "${NC}"
echo | tee -a $DEST

# parse out ERROR strings stripped of categories and threads
#grep " ERROR \[" $TRIM_FILE | sed 's/^.* ERROR \[.*\] ([^)]*) //g' | sed 's/^.* ERROR \[.*] //g' > $TMP_FILE
grep " ERROR \[" $TRIM_FILE | sed -E 's/^.* ERROR \[(.*)\] \([^)]*\) /[\1] /g' | sed -E 's/^.* ERROR \[(.*)] /[\1] /g' > $TMP_FILE
#count total
ERROR_COUNT=`cat $TMP_FILE | wc -l`
#sort and count uniques
cat $TMP_FILE | sort | uniq -c -w 150 | sort -nr > $TMP_FILE2
UNIQUE_COUNT=`cat $TMP_FILE2 | wc -l`
echo -en "${BLUE}"
echo "*** Counts of other errors in $FULL_FILE_NAME - $ERROR_COUNT total error occurrences of $UNIQUE_COUNT unique error types ***" | tee -a $ERROR_DEST
echo "*** top 20 - see $FULL_ERROR_DEST for more ***"
echo -en "${NC}"
head -n 20 $TMP_FILE2
cat $TMP_FILE2 >> $ERROR_DEST
#grep " ERROR \[" $TRIM_FILE | sed 's/^.* ERROR \[.*\] ([^)]*) //g' | sed 's/^.* ERROR \[.*] //g' | sort | uniq -c -w 150 | sort -nr | tee -a $ERROR_DEST


#split thread output to separate files
if [ "$THREAD_SPLIT" == "true" ]; then
  echo
  echo "splitting threads to separate log files in $FILE_NAME-yala-threads"
  rm -r ./$FILE_NAME-yala-threads/ 2> /dev/null
  mkdir ./$FILE_NAME-yala-threads
  while IFS= read -r line
  do
    # take action on $line #
    THREAD_NAME=`echo $line | sed -nE 's/^.* [A-Z]+ \[.*\] \(([^)]*)\) .*/\1/p'`
    if [ "x$THREAD_NAME" != x ]; then
      THREAD_NAME=`echo $THREAD_NAME | sed -E 's/\///g'`
      if [ "x$OLD_THREAD_NAME" == "x" ] || [ "$OLD_THREAD_NAME" != "$THREAD_NAME" ]; then
          OLD_THREAD_NAME="$THREAD_NAME"
      fi
    fi
    echo $line >> "./$FILE_NAME-yala-threads/$OLD_THREAD_NAME.log"
  done < $TRIM_FILE
fi


#clean up extras
rm -rf $TRIM_FILE
rm -rf $TMP_FILE
rm -rf $TMP_FILE2
rm -rf $FULL_STUCK_FILE
rm -rf $STUCK_FILE
rm -rf $STUCK_TIME_FILE
rm -rf $COMPLETED_STUCK_FILE
