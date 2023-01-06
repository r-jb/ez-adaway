#!/bin/sh

HOST_SOURCES='
# Steven Black Unified hosts
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts

# OISD
https://hosts.oisd.nl
'

hosts_file='/etc/hosts'
hosts_backup='/etc/hosts.bak'
TMP_WORK_PATH="$(mktemp -d -q --suffix=.adaway)"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NOCOLOR='\033[0m'

log_success() {
	echo "${GREEN}${*}${NOCOLOR}"
}

log_info() {
	printf "${BLUE}[i] - ${*}${NOCOLOR}"
}

log_warning() {
	echo "${ORANGE}/!\ - ${*}${NOCOLOR}"
}

log_error() {
	echo "${RED}${*}${NOCOLOR}"
}

strip_comments_and_newlines() {
	echo "$@" | sed '/^[[:blank:]]*#/d;s/#.*//' | sed '/^[[:space:]]*$/d'
}

command_exist() {
	type "$1" >/dev/null 2>/dev/null
}

flush_dns_cache() {
	out=1

	if command_exist 'systemd-resolve' && \
	sudo systemd-resolve --flush-caches >/dev/null 2>/dev/null; then
		out=0
		log_success "systemd-resolved cache cleared"

	elif command_exist 'rndc' && \
	sudo rndc flush >/dev/null 2>/dev/null; then
		out=0
		log_success "BIND cache cleared"

	elif command_exist 'nscd' && \
	sudo nscd --invalidate=hosts >/dev/null 2>/dev/null; then
		out=0
		log_success "nscd cache cleared"

	# systemd services
	elif command_exist 'systemctl'; then

		if sudo systemctl is-active dnsmasq >/dev/null 2>/dev/null && \
		sudo systemctl restart dnsmasq >/dev/null 2>/dev/null; then
			out=0
			log_success "dnsmasq service restarted"

		elif sudo systemctl is-active network-manager >/dev/null 2>/dev/null && \
		sudo service network-manager restart >/dev/null 2>/dev/null; then
			out=0
			log_success "network-manager service restarted"
		fi
	fi

	return $out
}

backup_exist_and_not_empty() {
	[ -s "$hosts_backup" ]
}

backup() {

	# If backup does not exist or is empty
	if ! backup_exist_and_not_empty; then
		if sudo cp '/etc/hosts' "$hosts_backup"; then
			log_success 'Created backup'
		else
			log_error 'Error creating backup'
		fi
	fi

	backup_exist_and_not_empty
	return $?
}

restore() {

	# If backup exist and is not empty
	if backup_exist_and_not_empty; then
		if sudo mv "$hosts_backup" "$hosts_file"; then
			log_success "Hosts file restored"
			flush_dns_cache
		else
			log_error "Error restoring backup to hosts file"
		fi
	else
		log_error "Can't restore backup, no backup found or file empty"
	fi
}

download_lists() {
	success_count=0
	total_count=0
	out=1

	strip_comments_and_newlines "$HOST_SOURCES" | {
		while IFS= read -r line || [ -n "$line" ]; do
			log_info "Downloading $line..."
			total_count=$((total_count + 1))

			if wget -q "$line" -O "list${success_count}"; then
				success_count=$((success_count + 1))
				log_success ' Done'
			else
				log_error ' Error'
			fi
		done

		log_info "Downloaded: "

		if [ "$success_count" -gt '0' ]; then
			out=0
			log_success "$success_count/$total_count"
		else
			log_error "$success_count/$total_count"
		fi
		return $out
	}
}

parse_lists() {
	out=1

	log_info 'Parsing lists...'

	# If any list is downloaded
	if ls -A1q "$TMP_WORK_PATH" | grep --quiet .; then
		echo '' > "$TMP_WORK_PATH/merge_file"

		# Remove comments and merge downloaded lists
		strip_comments_and_newlines "$(cat "$TMP_WORK_PATH"/list?)" | \

		# Remove ip addresses
		# In order to keep the hostnames not present in the hosts file
		awk '{for (j=2; j<=NF; j++) print $j}' | \

		# Only keep domain names
		awk '/^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$/ {print $0}' | \

		# Strip more local routing entries from the lists
		sed '/localhost.localdomain/d' | \

		# Sort domain names alphabetically
		# Remove duplicates
		# Save pipe to merge file
		sort --dictionary-order --unique >> "$TMP_WORK_PATH/merge_file"

		# Retrieve domains/localhost entries from the existing hosts file in place into a copy
		strip_comments_and_newlines "$(cat $hosts_backup)" | \
		awk '{for (j=2; j<=NF; j++) print $j}' \
		> hosts_file_domains_only.tmp

		# Only keep domains not present in the existing host file
		grep -Fvxf hosts_file_domains_only.tmp "$TMP_WORK_PATH/merge_file" | \

		# Strip newlines
		sed '/^[[:space:]]*$/d' | \

		# Add prefix 0.0.0.0 address for faster response time
		sed 's/^/0.0.0.0 /' > "$TMP_WORK_PATH/final_blocklist"

		# Add hosts file entries to the final hosts file
		# Use the backup as base hosts file if existing
		cat "$hosts_backup" > "$TMP_WORK_PATH/final_hosts"

		# Add blocklist banner
		printf "\n# BLOCKLIST STARTS HERE\n" >> "$TMP_WORK_PATH/final_hosts"

		# Add final blocklist
		cat "$TMP_WORK_PATH/final_blocklist" >> "$TMP_WORK_PATH/final_hosts"

		# If the new hosts file exist and is not empty
		if [ -s "$TMP_WORK_PATH/final_hosts" ]; then
			log_success ' Done'
			out=0
		fi
	else
		log_error 'No downloaded list found'
	fi

	return $out
}

apply_hosts() {
	if download_lists && backup && parse_lists && backup_exist_and_not_empty; then

		# Replace the hosts file
		log_info 'Applying hosts file...'
		if sudo mv "$TMP_WORK_PATH/final_hosts" "$hosts_file"; then
			log_success ' Done'

			log_info 'Flashing DNS cache...'
			if flush_dns_cache; then
				log_success ' Done'
			else
				log_error ' Error'
			fi

		else
			log_error ' Error'
		fi
	fi
	rm -rf "$TMP_WORK_PATH"
}

# Add a custom host to the blocklist
add_host() {

	# Choose the backup file if existing, else the hosts file
	add_to_file="$hosts_file"
	if backup_exist_and_not_empty; then
		add_to_file="$hosts_backup"
	fi

	# If input is a domain
	if is_domain "$1"; then

		# If the domain is not already present
		if ! grep --quiet "$1" "$add_to_file"; then

			# Add it and apply
			printf "\n# BLOCK %s\n0.0.0.0 %s\n" "$1" "$1" | sudo tee -a "$add_to_file" && \
			apply_hosts && \
			log_success "$1 added to hosts file"

		else
			log_warning "$1 is already in hosts file, skipping"
		fi
	else
		log_warning "$1 is not a domain"
	fi
}

# Remove a custom host from the blocklist
rm_host() {

	# Choose the backup file if existing, else the hosts file
	rm_from_file="$hosts_file"
	if backup_exist_and_not_empty; then
		rm_from_file="$hosts_backup"
	fi

	# If input is a domain
	if is_domain "$1"; then

		# If the domain is present
		if grep --quiet "$1" "$rm_from_file"; then

			# Remove it and apply
			sed "/0.0.0.0 $1/d" "$rm_from_file" | sudo tee "$rm_from_file" && \
			apply_hosts && \
			log_success "$1 removed from hosts file"

		else
			log_warning "Can't remove $1, it is not in hosts file"
		fi
	else
		log_warning "$1 is not a domain"
	fi
}

menu() {
	echo "${BLUE}=========================="
	echo "${BLUE}|        ${NOCOLOR}EZ AdAway${BLUE}       |"
	echo "${BLUE}=========================="
	echo "${BLUE}|        ${NOCOLOR}1. Apply${BLUE}        |"
	echo "${BLUE}|       ${NOCOLOR}2. Restore${BLUE}       |"
	echo "${BLUE}|       ${NOCOLOR}3. Add host${BLUE}      |"
	echo "${BLUE}|     ${NOCOLOR}4. Remove host${BLUE}     |"
	echo "${BLUE}==========================${NOCOLOR}"
	printf "${GREEN}>${NOCOLOR} "
	read -r choice
	case "$choice" in
		1) apply_hosts;;
		2) restore;;
		3)
			printf '[?] Enter host: '
			read -r host
			[ -n "$host" ] && add_host "$host"
			;;
		4)
			printf '[?] Enter host: '
			read -r host
			[ -n "$host" ] && rm_host "$host"
	esac
}

cd "$TMP_WORK_PATH" || exit 1
clear
if [ "$#" -eq '0' ]; then
	menu
else
	case "$1" in
		update | apply) apply_hosts;;
		restore) restore;;
		*)
			printf "Usage: %s <${GREEN}apply${NOCOLOR}|${ORANGE}restore${NOCOLOR}>" "$(basename "$0")"
			echo
	esac
fi