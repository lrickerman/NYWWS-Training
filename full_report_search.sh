#!/bin/bash

LOG_FILE=$PWD/genexus.log
date=`date`
dt=`date +%Y%m%d`
export dt
echo "--begin">> $LOG_FILE
echo $date >> $LOG_FILE
#sudo apt update && sudo apt upgrade

#exec 2>&1 ${LOG_FILE[1]}

#NOTE: bash v4 required - if running macOS with bash v3, conda environment with bash v4 is required

#FUNCTIONS
#FUNCTION: facility name
function facility_name_fx {
	echo "What is the name of your institution?"
	PS3='Please enter your choice: '
	options=("University at Buffalo" "SUNY Upstate" "University of Rochester" "New York Medical Center" "Wadsworth Center NYSDOH")
	select i in "${options[@]}"
	do
		case $i in
			"University at Buffalo")
				echo "Your files will upload to gs://su_nywws_test_bucket/buffalo"
				echo "gs://su_nywws_test_bucket/buffalo" > facility.txt
				;;
			"SUNY Upstate")
				echo "Your files will upload to gs://su_nywws_test_bucket/suny_upstate"
				echo "gs://su_nywws_test_bucket/suny_upstate" > facility.txt
				;;
			"University of Rochester")
				echo "Your files will upload to gs://su_nywws_test_bucket/rochester"
				echo "gs://su_nywws_test_bucket/rochester" > facility.txt
				;;
			"New York Medical Center")
				echo "Your files will upload to gs://su_nywws_test_bucket/nymc"
				echo "gs://su_nywws_test_bucket/nymc" > facility.txt
				;;
			"Wadsworth Center NYSDOH")
				echo "Your files will upload to gs://su_nywws_test_bucket/wadsworth"
				echo "gs://su_nywws_test_bucket/wadsworth" > facility.txt
				;;
			*) echo "invalid option $REPLY";;
		esac
		break
	done
}
#FUNCTION:ask for ssh key path, create ssh key; look for ssh_path.txt, ask for ssh key path
function ssh_key_fx {
	read -p "Do you have an SSH key (y/n)?" -r
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		if test -f "ssh_path.txt" ;
		then
			while IFS= read -r line || [[ -n "$line" ]]; do
				ssh_path="$line"
			done < "ssh_path.txt"
			read -p "Do you wish to connect with $ssh_path (y/n)?" -r
			if [[ $REPLY =~ ^[Nn]$ ]]
			then
				read -p 'Enter path to SSH key: ' ssh_path
				echo $ssh_path > ssh_path.txt
				echo "Using $ssh_path"
			fi
		else
			read -p 'Enter path to SSH key: ' ssh_path
			echo $ssh_path > ssh_path.txt
			echo "Using $ssh_path"
		fi
	else
		mkdir -p $PWD/.ssh
		ssh-keygen -t rsa -b 3072 -N '' -f $PWD/.ssh/id_rsa
		ssh_path=$PWD/.ssh/id_rsa
		echo $ssh_path > ssh_path.txt
		echo "You will need to upload your SSH key to the instrument before you can download files and continue. Your SSH key can be found at $ssh_path."
		exit
	fi
}
#FUNCTION:look for instrIP.txt, ask to connect, enter IP
function instr_IP_fx {
	if test -f "instrIP.txt" ;
	then
		while IFS= read -r line || [[ -n "$line" ]]; do
			instrIP="$line"
		done < "instrIP.txt"
		read -p "Do you wish to connect to $instrIP (y/n)? " -r
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
			echo "Using $instrIP"
		else
			read -p 'Enter instrument IP you wish to connect to: ' instrIP
			echo $instrIP > instrIP.txt
			echo "Using $instrIP"
		fi
	else
		read -p 'Enter instrument IP you wish to connect to: ' instrIP
		echo $instrIP > instrIP.txt
		echo "Using $instrIP"
	fi
}
#FUNCTION:create default profile
function create_default_profile_fx {
	read -p 'Do you wish to create a default profile to use later (y/n)? ' -r
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
			while IFS= read -r line || [[ -n "$line" ]]; do
				ssh_path="$line"
			done < "ssh_path.txt"
			echo "ssh_path=$ssh_path" > ${name}_default.txt
			while IFS= read -r line || [[ -n "$line" ]]; do
				instrIP="$line"
			done < "instrIP.txt"
			while IFS= read -r line || [[ -n "$line" ]]; do
				facility="$line"
			done < "facility.txt"
			echo "ssh_path=$ssh_path" > ${name}_default.txt
			echo "instrIP=$instrIP" >> ${name}_default.txt
			echo "facility=$facility" >> ${name}_default.txt
			echo "${name}_default.txt created"
		fi
}
#FUNCTION:find all files, login
function all_report_search {
	echo "Searching for run results..." | tee -a $LOG_FILE
	ssh -i $ssh_path $instrIP -l ionadmin <<-EOF > tmp2.txt 2>> $LOG_FILE
		find /data/IR/data/analysis_output/ -type f -path "*generateConsensus*" -name "*results.json" -not -path "*block*" -printf "%p\t%AY%Am%Ad\n"
	EOF
	grep -F '/data/IR' tmp2.txt > report.txt
	cat report.txt >> $LOG_FILE
	rm tmp2.txt
	if [ -f report.txt ] && [ -s report.txt ];
	then
		COUNT=$(wc -l < report.txt)
		echo "$COUNT reports found."
		echo "$COUNT files downloaded." >> $LOG_FILE
	else
		echo "There were no results found, let's try something else." | tee -a $LOG_FILE
		echo ""
		echo "Your files may be named different than anticipated."
		echo "Let's login and see."
		echo ""
		echo "You will need your ionadmin password to login to the instrument."
		echo "Please hold while I look at the folder structure..."
		echo "... this may take a bit."
		echo ""
		echo "Username:  ionadmin"
		read -p "Password:  " gnx_pw
		export $gnx_pw
		ssh -t $ssh_path $instrIP -l ionadmin <<-EOF > tree.txt 2>> $LOG_FILE
			echo "${gnx_pw}" | sudo -S apt install -y tree
		EOF
		ssh -i $ssh_path $instrIP -l ionadmin 'ls /data/IR/data/analysis_output/ -t | head -5 | tail -1 | tree' > tmpx.txt 2>> $LOG_FILE
		EOF
		if [ -f tmpx.txt ] && [ -s tmpx.txt ];
		then
			echo "Hopefully that can help."
			echo "Your instrument's file-naming structure will be sent to Lindsey to review." | tee -a $LOG_FILE
			echo "Thanks!"
		fi
	fi
	mkdir -p /tmp/nywws
}
#FUNCTION:upload files
function gcp_upload {
	#storage/parallel_composite_upload_enabled False > /dev/null 2>&1
	echo "Renaming files, please wait..."
	while IFS=$'\t' read -r line res_dt || [[ -n "$line" ]]; do
		scp -q -i $ssh_path ionadmin@$instrIP:"$line" /tmp/nywws/"$res_dt"_results.json;
	done < report.txt
	REPORT=$(wc -l < report.txt)
	echo "Files have been renamed."
	RUN_RESULTS=$(echo $facility | sed 's/\(.*bucket\/\)\(.*\)/\1run_results\/\2/')
	gcloud storage cp /tmp/nywws/* $RUN_RESULTS > /dev/null 2>&1
	rm /tmp/nywws/*
	#gsutil ls $INBOX
	echo "The reports have been uploaded to $RUN_RESULTS."
}





#SCRIPTS
#check for default profile
read -p "What is your name?  " name
export $name
if test -f "${name}_default.txt" ;
then
	ssh_path=$(awk -F= '/ssh/{print $2}' ${name}_default.txt)
	instrIP=$(awk -F= '/instr/{print $2}' ${name}_default.txt)
	facility=$(awk -F= '/facility/{print $2}' ${name}_default.txt)
	echo "$ssh_path"
	echo "$instrIP"
	echo "$facility"
	read -p 'Do you wish to use the above credentials (y/n)? ' -r
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
			echo "Using default profile. Logging into $instrIP with $ssh_path" | tee -a $LOG_FILE
		else
			facility_name_fx
			ssh_key_fx
			instr_IP_fx
			create_default_profile_fx
			echo "Logging into $instrIP with $ssh_path" | tee -a $LOG_FILE
		fi
else
	facility_name_fx
	ssh_key_fx
	instr_IP_fx
	create_default_profile_fx
	echo "Logging into $instrIP with $ssh_path" | tee -a $LOG_FILE
fi

all_report_search
gcp_upload

echo "Goodbye! :)"
echo $date >> $LOG_FILE
echo "end--">> $LOG_FILE
echo >> $LOG_FILE
echo >> $LOG_FILE
exit
