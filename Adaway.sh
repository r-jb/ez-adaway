#!/bin/sh
#==================================================
# AdAway implementation in shell
#==================================================
#

TMP_WORK_PATH="/tmp/.AdAway"
count=0
host_sources="http://hosts-file.net/ad_servers.txt
http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext
http://winhelp2002.mvps.org/hosts.txt
https://adaway.org/hosts.txt"

# Download host sources
download() {
    for i in $host_sources
    do
        count=$((count + 1))
        echo "Downloading... $i"
        wget -q "$i" -O hosts${count}.txt
    done
}

parse_sources() {
    available_hosts=$(ls -1 $TMP_WORK_PATH/hosts?.txt)
    
    # create new file 
    echo '' > $TMP_WORK_PATH/merge_file
    for j in $available_hosts; do
        cat $j | grep ^127 >> $TMP_WORK_PATH/merge_file
        cat $j | grep ^0 >> $TMP_WORK_PATH/merge_file
        cat $j | grep ^: >> $TMP_WORK_PATH/merge_file
    done

    # check if backup exist then use it else create backup
    if [ ! -f "/etc/hosts.bak" ]; then
        sudo mv /etc/hosts /etc/hosts.bak
    fi

    echo "Creating hosts file"
    cat /etc/hosts.bak > $TMP_WORK_PATH/final_host_file
    printf "\n#\n# AD SERVERS START HERE\n#\n" >> $TMP_WORK_PATH/final_host_file
    echo "Parsing hosts"
    sort $TMP_WORK_PATH/merge_file | uniq >> $TMP_WORK_PATH/final_host_file
    sed -i 's/0.0.0.0/127.0.0.1/g' $TMP_WORK_PATH/final_host_file
}

# Start
apply_hosts() {
    # create directory if it doesn't exist
    if [ ! -d "$TMP_WORK_PATH" ]; then
        mkdir -p $TMP_WORK_PATH
    fi

    # change work directory path
    cd $TMP_WORK_PATH

    download
    parse_sources

    # backup hosts file before applying new one
    if [ ! -f "/etc/hosts.bak" ]; then
        sudo mv /etc/hosts /etc/hosts.bak
    fi

    # Replace hosts file
    echo "Applying hosts file"
    sudo mv $TMP_WORK_PATH/final_host_file /etc/hosts

    # clean up
    rm -fR $TMP_WORK_PATH
}

# Restore back up hosts file
restore() {
    # check if backup exist then use it else create backup
    if [ -f "/etc/hosts.bak" ]; then
        sudo mv /etc/hosts.bak /etc/hosts
        echo "Restore complete!"
    else
        echo "Restore failed no backup found!"
    fi
}

# Main menu
menu() {
    printf "==================================================\n"
    printf "=                AdAway for Linux                =\n"
    printf "==================================================\n"
    printf "= 1. Apply host sources                          =\n"
    printf "= 2. Restore original hosts file                 =\n"
    printf "==================================================\n"
    printf "choice: "
    read choice
    if [ "$choice" -eq 1 ]; then
        apply_hosts
    elif [ "$choice" -eq 2 ]; then
        restore
    else
        echo 'Bye!'
        exit 0
    fi
}

# clear the screen
clear

# Launch menu
menu