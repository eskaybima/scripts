#!/bin/sh
# jtlmin.sh :
#   JMeter log processing script 
#   Collects & Averages throughput data using 1-minute increments
#   Requires CSV-formatted log from JMeter "Simple Data Writer".
#

#set -x  #debug

USAGE="Usage: jtlmin.sh <filename> \nSummarizes JMeter JTL output into 1-minute blocks"
[ $1 ] || { echo -e $USAGE; exit 1 ; }
echo -e "Processing \c"
ls $1 || { exit 1 ; }

main()
{
  WORKFILE=$1.jtlmin.$$.WORKING
  OUTFILE=$1.jtlmin.$$.OUT
  STEP=60       # <-- can modify this value for larger time increments

  # Workfile: Chop milliseconds, Round timestamps to nearest Minute
  sed -n '2,$ p' $1 | cut -c -10,14- | sort | awk -F',' -v step=$STEP '{print $1-$1%step,$2}' > $WORKFILE

  echo "Outputting data to $OUTFILE .."
  echo "$PWD/$1" > $OUTFILE
  echo -e "unixtime \tdate \ttime \tthruput(tpm) \tresponse(ms) " >> $OUTFILE
  awk_routine | sort >> $OUTFILE

  rm $WORKFILE
}  

awk_routine()
{
  awk '
    NR!=1 {minute[$1]++; rsum[$1]=rsum[$1]+$2}
    END {
      for (i in minute) {
        printf("%d\t", i);
        printf("%s\t", strftime("%Y.%b.%d",i));
        printf("%s\t", strftime("%H:%M",i));
        printf("%d\t", minute[i]);
        printf("%d\n", rsum[i]/minute[i])
      }
    }' $WORKFILE 
}

main $*

