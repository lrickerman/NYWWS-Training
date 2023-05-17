#!/bin/bash

LOG_FILE=$PWD/genexus.log
date=`date`
dt=`date +%Y%m%d`

export dt
echo "--begin">> $LOG_FILE
echo $date >> $LOG_FILE

if test -f "genexus_default.txt" ;
then
	ssh_path=$(awk -F= '/ssh/{print $2}' genexus_default.txt)
	instrIP=$(awk -F= '/instr/{print $2}' genexus_default.txt)
	facility=$(awk -F= '/facility/{print $2}' genexus_default.txt)
fi

ssh -i $ssh_path $instrIP -l ionadmin <<-EOF > tmp.txt 2>> $LOG_FILE
		find /data/IR/data/analysis_output/ -type f -ctime "$1" -name "*.ptrim.bam" -not -path "*block*" -print
	EOF
	grep -F '/data/IR' tmp.txt > tmp2.txt
	grep -F 'NY' tmp2.txt > tmp3.txt
	cat tmp3.txt >> $LOG_FILE
	rm tmp.txt tmp2.txt
	if [ -s tmp3.txt ];
	then
		COUNT=$(wc -l < tmp3.txt)
		echo "$COUNT files downloaded." >> $LOG_FILE
		mkdir -p /tmp/nywws
		while IFS= read -r line || [[ -n "$line" ]]; do
			s=$(echo $line | sed "s/.*ChipLane.*\/\(.*\)_LibPrep.*/\1/");
			scp -q -i $ssh_path ionadmin@$instrIP:"$line" /tmp/nywws/$s.ptrim.bam;
		done < tmp3.txt
		pushd /tmp/
		DAYSAGO=$(date --date="$days days ago" +%m-%d-%Y)
		gcloud storage cp nywws/* $facility >> $LOG_FILE 2>&1
		rm /tmp/nywws/*
		popd
		TOTAL=$((COUNT-NOUP))
		echo "$COUNT samples uploaded to GCP from $DAYSAGO." >> $LOG_FILE
	else
		echo "No results." >> $LOG_FILE
	fi
