#!/bin/bash -e
PROCESS_NAME=$1
OUTPUT_DIR=$2

function get-process-id() {
    PROCESS_ID=`pidof $PROCESS_NAME` || unset PROCESS_ID
    if [ -z "$STORED_PROCESS_ID" ] && [ -n "$PROCESS_ID" ]; then
        STORED_PROCESS_ID=$PROCESS_ID
        echo "Process '$PROCESS_NAME' is running"
        if [ -z "$OUTPUT_DIR"]; then
            get-time
            OUTPUT_DIR="$TIME-$PROCESS_ID"
            echo "Setting output directory to: $OUTPUT_DIR"
            mkdir $OUTPUT_DIR
        fi
    fi

    if [ -n "$STORED_PROCESS_ID" ] && [ -z "$PROCESS_ID" ]; then     
        echo "Process '$PROCESS_NAME' has been terminated"
        exit 1
    fi
}

function get-time() {
    TIME=`date '+%Y-%m-%d-%H:%M:%S'`
}

while true; do
    get-time

    if [ "$TIME" != "$CURRENT_TIME" ]; then
        CURRENT_TIME=$TIME
        get-process-id
    
        if [ -n "$PROCESS_ID" ]; then
            PMAP_FILENAME="pmap-report-$TIME"
            PMAP_RAW=$OUTPUT_DIR/$PMAP_FILENAME.raw
            PMAP_TMP=$OUTPUT_DIR/$PMAP_FILENAME.tmp
            PMAP_REPORT=$OUTPUT_DIR/$PMAP_FILENAME.report
            MEMORY_SUMMARY=$OUTPUT_DIR/summary.live

            # get raw pmap output
            pmap -x $PROCESS_ID > $PMAP_TMP
            dos2unix $PMAP_TMP &> /dev/null
            mv $PMAP_TMP $PMAP_RAW

            # generate report
            FILTERED_PMAP=`grep -vE "$PROCESS_NAME|pidof|pmap|runsv|Address|total kB|----------------" $PMAP_RAW | sed "s/[[]//g"| sed "s/[]]//g"`
            KEYS=`echo -e "$FILTERED_PMAP" | sort -n | awk '{print $6}'`
            VALUES=`echo -e "$FILTERED_PMAP" | sort -n | awk '{print $3}'`
            SUMMARY=`paste <(echo -e "$KEYS") <(echo -e "$VALUES") | column -s $'\t' -t | grep -v " 0" | awk '{a[$1] += $2} END{for (i in a) print i, a[i]}' | sort -k1 -n`
            MEM_SUM=`echo -e "$VALUES" | paste -s -d+ - | bc`
            echo -e "$TIME\t$MEM_SUM" >> $MEMORY_SUMMARY
            echo -e "$SUMMARY" > $PMAP_REPORT
        fi
    fi
done
