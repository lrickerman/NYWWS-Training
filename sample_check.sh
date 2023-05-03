#!/bin/bash

date=`date`
dt=`date +%Y%m%d`
ssh_path=$1
instr_ip=$2
facility=$3

export dt


ssh -i $ssh_path $instr_ip -l ionadmin <<-EOF > samples.txt
		find /data/IR/data/analysis_output/ -type f -name "*.ptrim.bam" -not -path "*block*" -print
	EOF
ssh -i $ssh_path $instr_ip -l ionadmin <<-EOF > report.txt
		find /data/IR/data/analysis_output/ -type f -path "*generateConsensus*" -name "*.bc_summary.xls" -not -path "*block*" -print
	EOF
COUNT=$(wc -l < report.txt)
mkdir -p /tmp/$dt
# QC CHECK
while IFS= read -r line || [[ -n "$line" ]]; do
	s=$(echo $line | sed "s/.*generateConsensus.*\/.*\/\(.*\).xls/\1/");
	scp -q -i $ssh_path ionadmin@$instr_ip:"$line" /tmp/$dt/$s.tsv;
done < report.txt
mv samples.txt /tmp/$dt/
cd /tmp/$dt
while IFS= read -r line || [[ -n "$line" ]]; do
	s=$(echo $line | sed "s/.*ChipLane.*\/\(.*\)_LibPrep.*/\1/");
	echo "$s" >> ${facility}_samples.txt;
done < samples.txt
for t in *summary.tsv; do
	cat $t >> ${facility}_reports.tsv
done
rm *_summary.tsv samples.txt
cd ../
gcloud storage cp $dt/* gs://su_nywws_test_bucket/test
rm -rf $dt