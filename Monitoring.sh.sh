#!/bin/bash

set -e #Stop the script if it fails
#set -x #Enable debug mode

#echo "Iniciando Script"

# Main variables
DATE_HOUR=$(date +%Y_%m_%d_%H-%M); 
DATE_DAY=$(date +%Y_%m_%d);
HOSTNAME=$(hostname);
VM_IP=$(hostname -I);
end=$((SECONDS+3600));
ALERT_INTERVAL=300

#Variables for directory paths
MONITOR_PATH="/data/shells/monitor_alerts"
LOGS_PATH="/data/shells/logs/out_logs"
LOGS_PATH_GRAPH="/data/shells/logs/graph_logs"
LOGS_PATH_SHELL="/data/shells/logs/shell_logs"
LAST_ALERT_FILE="/data/shells/skip_alerts"
ALERT_FILE=$LAST_ALERT_FILE/alert.txt
LOG_FILE_TEMPORARY="$LOGS_PATH_SHELL/shell-${DATE_DAY}.log"
FILE_LOG_HOME="/home/initial-${DATE_DAY}.txt"

if [[ ! -f "$FILE_LOG_HOME" ]]; then 
    touch "$FILE_LOG_HOME" && chmod -R 755 "$FILE_LOG_HOME" 2>&1
else
    echo "$DATE_HOUR INFO: $FILE_LOG_HOME already exists"
fi

# Writing the alert file to be sent by email
write_file(){

	# Creating the file used as the email template
	echo -e "Subject: \U0001F6A8 ALERTA \U000026A0 SOBRECARGA DE "$2 $3"%" $4  $6 > $MONITOR_PATH/Alerta-$1.txt
	echo "##############################################" >> $MONITOR_PATH/Alerta-$1.txt
	echo -e "# \U0001F6A8 HARDWARE RESOURCE MONITORING \U0001F6A8 #" >> $MONITOR_PATH/Alerta-$1.txt
	echo "##############################################" >> $MONITOR_PATH/Alerta-$1.txt
	echo "----------------------------------------------" >> $MONITOR_PATH/Alerta-$1.txt
	echo -e "\U0001F5A5 Server: "$HOSTNAME >> $MONITOR_PATH/Alerta-$1.txt
	echo -e "\U0001F310 IP: "$VM_IP >> $MONITOR_PATH/Alerta-$1.txt
	echo -e "\U0001F4C5 Event date: "$1 >> $MONITOR_PATH/Alerta-$1.txt
	echo "----------------------------------------------" >> $MONITOR_PATH/Alerta-$1.txt
	echo $2": "$3"%" >> $MONITOR_PATH/Alerta-$1.txt
	echo $4": "$5"%" >> $MONITOR_PATH/Alerta-$1.txt
	echo $6": "$7"%" >> $MONITOR_PATH/Alerta-$1.txt
}

#Create directories if they don't exist
validate_directories() {

#Validate if $LOG_FILE_TEMPORARY exists to save the Logs for the funtion

if [[ ! -f "$LOG_FILE_TEMPORARY" ]]; then
    local lfpd="$FILE_LOG_HOME"
    echo "$DATE_HOUR INFO: $FILE_LOG_HOME will be used" >> $lfpd
elif [[ -f "$LOG_FILE_TEMPORARY" ]]; then 
    local lfpd="$LOG_FILE_TEMPORARY"
    echo "$DATE_HOUR INFO:" $LOG_FILE already exist >> $lfpd
else 
    echo "$DATE_HOUR ERROR: No log files found"
    exit 1
fi

# Log error output to file

    for dir_path in "$@"; do 
    
        if [[ ! -d "$dir_path" ]]; then
		    local error_shell
            error_shell=$(mkdir -p "$dir_path" && chmod -R 755 "$dir_path" 2>&1)
		    if [[ $? -eq 0 ]]; then
		        echo "$DATE_HOUR INFO: Directory $dir_path created successfully" >> "$lfpd"
            else 
                echo "$DATE_HOUR ERROR: $error_shell" >> "$lfpd" 
                exit 1  #Stop the script if it fails to create the log directory.
            fi
        else 

            echo "$DATE_HOUR INFO: Directory $dir_path already exists" >> "$lfpd"
        fi
    done
}

#Log files are created
logs_validation(){

local log_names=("shell" "log" "graph")
local log_paths=("$LOGS_PATH_SHELL" "$LOGS_PATH" "$LOGS_PATH_GRAPH")
local log_file=$(ls $LOGS_PATH | sort -rn | head -1);
local log_file_graph=$(ls $LOGS_PATH_GRAPH | sort -rn | head -1);
local log_file_shell=$(ls $LOGS_PATH_SHELL | sort -rn | head -1);
	
    for i in "${!log_names[@]}"; do 

        local name="${log_names[$i]}"
        local path="${log_paths[$i]}"
        local full_file="$path/${name}-${DATE_DAY}.log" #A log file will be created each day

        if [[ ! -f "$full_file" ]]; then #If any of the files don't exist at the specified path, new ones will be created.
        local error_shell
        error_shell=$(touch "$full_file" 2>&1)
            if [[ $? -eq 0 ]]; then
                echo "$DATE_HOUR INFO: File $name created successfully" >> "$LOG_FILE_TEMPORARY"
            else 
                echo "$DATE_HOUR ERROR: $error_shell" >> "$LOG_FILE_TEMPORARY" 
                exit 1  #Stop the script if it fails to create the log directory.
            fi    
            if [[ "$name" == "graph" ]]; then
                printf "Memory\t\tDisk\t\tCPU\n" >> "$full_file"
            fi
        else 

            echo "$DATE_HOUR INFO: File $name already exists" >> "$LOG_FILE_TEMPORARY"

        fi
    
        case "$name" in
            log)
                LOG_FILE="$full_file" ;;
            graph)
                LOG_FILE_GRAPH="$full_file" ;;
            shell)
                LOG_FILE_SHELL="$full_file" ;;
        esac
    done

}

check_send_alert() {

# Check if it's time to send alert files by mail 

local ALERT_TIME="$1";
local EPOCH_NOW=$(date +%s)

if [[ ! -f "$ALERT_FILE" ]];  then 
    local error_shell
    error_shell=$(touch "$ALERT_FILE" 2>&1)
        if [[ $? -eq 0 ]]; then
            echo "$DATE_HOUR INFO: File $ALERT_FILE created successfully" >> "$LOG_FILE_SHELL"
        else 
            echo "$DATE_HOUR ERROR: $error_shell" >> "$LOG_FILE_SHELL" 
            exit 1  #Stop the script if it fails to create the log directory.
        fi
    echo "$ALERT_TIME" > "$ALERT_FILE"
    echo "$DATE_HOUR INFO: First alert sent" >> "$LOG_FILE_SHELL"
    send_mail "$2"

else
    
    local LAST_ALERT_TIME=$(cat "$ALERT_FILE")

    if [[ -z "$LAST_ALERT_TIME" ]]; then
        echo "$ALERT_TIME" > "$ALERT_FILE"
        echo "$DATE_HOUR INFO: Alert sent" >> "$LOG_FILE_SHELL"
        send_mail "$2"

    else

        local SEC_LAST_ALERT_FILE=$(date -d "$LAST_ALERT_TIME" +%s)

        if [[ -z "$SEC_LAST_ALERT_FILE" ]]; then
        echo "$ALERT_TIME" > "$ALERT_FILE"
        echo "$DATE_HOUR WARN: Invalid previous alert time, sending alert now" >> "$LOG_FILE_SHELL"
        send_mail "$2"
    
        else  
            local DIFF_TIME=$((EPOCH_NOW - SEC_LAST_ALERT_FILE))
            if [[ $DIFF_TIME -ge $ALERT_INTERVAL ]]; then 
                echo "$ALERT_TIME" > "$ALERT_FILE"
                echo "$DATE_HOUR INFO: Alert sent (diff $DIFF_TIME sec)" >> "$LOG_FILE_SHELL"
                send_mail "$2"
        
            else 
                echo "$DATE_HOUR WARN: Alert not sent (only $DIFF_TIME sec since last)" >> "$LOG_FILE_SHELL"
            fi
        fi
    fi
fi

}

# Send email if system alerts occur and the time condition is met

send_mail(){

	# The template is attached and the email is sent
	echo "Enviando correo " $MONITOR_PATH/Alerta-$1.txt;

	error=$(timeout 40s curl --url 'smtps://smtp.gmail.com:465' \
	--ssl-reqd --mail-from 'devethosjsg.5@gmail.com' \
       	--mail-rcpt 'devethosjsg.5@gmail.com' \
       	--upload-file $MONITOR_PATH/Alerta-$1.txt \
	--user 'devethosjsg.5@gmail.com:idjrmnrvsgguogqr' \
	--insecure \
	--connect-timeout 10 \
	--max-time 30 \ 
	2>&1 1>/dev/null);

	if [ $? -eq 0  ]; then
		echo "INFO: The email was sent successfully" >> $LOG_FILE_SHELL
	else
   		echo "ERROR: Failed to send mail: $error" >> $LOG_FILE_SHELL
	fi
}

#Variable declaration to store RAM, DISK, and CPU usage

DATE_COM=$(date +%Y-%m-%d\ %H:%M:%S)
DATE_FILE=$(date +%Y_%m_%d_%H-%M-%S)
CPU_CORES=$(nproc)
MEMORY=$(free -m | awk 'NR==2{printf "%.f\t\t", $3*100/$2 }')
DISK=$(df -k | sed '1d' | awk '{ (size+=$2) } { (used+=$3) } END {printf "%.f\t\t", (used*100)/size}')
CPU=$(top -bn1 | grep load | awk -v cores="$CPU_CORES" '{printf "%.f\t\t\n", (($(NF-2)/cores)*100)}')
		
		
validate_directories "$LOGS_PATH_SHELL" "$LOGS_PATH" "$MONITOR_PATH" "$LOGS_PATH_GRAPH"; #Directory creation

logs_validation; #Log validation
	
printf "$MEMORY$DISK$CPU\n" >> $LOG_FILE_GRAPH

# The logs generated by the commands are recorded
printf "[$DATE_COM]\n" >> $LOG_FILE
printf "%%Memory\t\t%%Disk\t\t%%CPU\n" >> $LOG_FILE
printf "$MEMORY$DISK$CPU\n" >> $LOG_FILE
echo "-------------------------------------------------------------" >> $LOG_FILE
echo "|" >> $LOG_FILE

# Checks if conditions are met to trigger an alert

	if [ $MEMORY -ge 80 ] && [ $DISK -ge 80 ] && [ $CPU -ge 70 ] ;then
	   
	   write_file $DATE_FILE "RAM" $MEMORY "DISCO DURO" $DISK "CPU" $CPU;
	   echo "ALERTA" "$DATE_COM";
	   check_send_alert "$DATE_COM" "$DATE_FILE"

	elif [ $MEMORY -ge 80 ] ;then
	   write_file $DATE_FILE "RAM" $MEMORY
	   echo "ALERTA" "$DATE_COM";
	   check_send_alert "$DATE_COM" "$DATA_FILE"

	elif [ $DISK -ge 80 ] ;then
		write_file $DATE_FILE "DISCO DURO" $DISK
		echo "ALERTA" "$DATE_COM";
		check_send_alert "$DATE_COM" "$DATE_FILE"

	elif [ $CPU -ge 70 ] ;then
		write_file $DATE_FILE "CPU"  $CPU
		echo "ALERTA" "$DATE_COM";
		check_send_alert "$DATE_COM" "$DATE_FILE"
	fi
