#!/bin/bash

# Check new patch:
get_date() {
	local json=""
	local max_retries=3
	local retry_count=0
	
	while [[ $retry_count -lt $max_retries ]]; do
		if [[ -n "$GITHUB_TOKEN" ]]; then
			json=$(wget -qO- --header="Authorization: token $GITHUB_TOKEN" --header="User-Agent: ReVanced-Builder" "https://api.github.com/repos/$1/releases" 2>/dev/null)
		else
			json=$(wget -qO- --header="User-Agent: ReVanced-Builder" "https://api.github.com/repos/$1/releases" 2>/dev/null)
		fi
		
		if [[ -n "$json" ]] && [[ "$json" != *"API rate limit exceeded"* ]]; then
			break
		fi
		
		((retry_count++))
		echo -e "\e[33mAPI request failed, retrying in 3 seconds... (attempt $retry_count/$max_retries)\e[0m"
		sleep 3
	done
	
	if [[ -z "$json" ]] || [[ "$json" == *"API rate limit exceeded"* ]]; then
		echo ""
		return 1
	fi
	
	case "$2" in
		latest)
			updated_at=$(echo "$json" | jq -r 'first(.[] | select(.prerelease == false) | .assets[] | select(.name | test("'$3'")) | .updated_at) // empty')
			;;
		prerelease)
			updated_at=$(echo "$json" | jq -r 'first(.[] | select(.prerelease == true) | .assets[] | select(.name | test("'$3'")) | .updated_at) // empty')
			;;
		*)
			updated_at=$(echo "$json" | jq -r 'first(.[] | select(.tag_name == "'$2'") | .assets[] | select(.name | test("'$3'")) | .updated_at) // empty')
			;;
	esac
	echo "$updated_at"
}

checker(){
	local date1 date2 date1_sec date2_sec repo=$1 ur_repo=$repository check=$3
	
	# Get dates with error handling
	date1=$(get_date "$repo" "$2" "^(.*\\\.jar|.*\\\.rvp)$") || {
		echo -e "\e[31mFailed to get date from $repo\e[0m"
		echo "new_patch=0" >> $GITHUB_OUTPUT
		return 1
	}
	
	date2=$(get_date "$ur_repo" "all" "$check") || {
		echo -e "\e[31mFailed to get date from $ur_repo\e[0m"
		echo "new_patch=1" >> $GITHUB_OUTPUT
		echo -e "\e[32mAssuming new patch due to missing local data...\e[0m"
		return 0
	}
	
	# Handle empty dates
	if [ -z "$date1" ]; then
		echo -e "\e[31mNo patch date found for $repo\e[0m"
		echo "new_patch=0" >> $GITHUB_OUTPUT
		return 1
	fi
	
	if [ -z "$date2" ]; then
		echo -e "\e[32mNo local release found, building...\e[0m"
		echo "new_patch=1" >> $GITHUB_OUTPUT
		return 0
	fi
	
	date1_sec=$(date -d "$date1" +%s 2>/dev/null) || {
		echo -e "\e[31mInvalid date format: $date1\e[0m"
		echo "new_patch=0" >> $GITHUB_OUTPUT
		return 1
	}
	
	date2_sec=$(date -d "$date2" +%s 2>/dev/null) || {
		echo -e "\e[31mInvalid date format: $date2\e[0m"
		echo "new_patch=1" >> $GITHUB_OUTPUT
		return 0
	}
	
	if [ "$date1_sec" -gt "$date2_sec" ]; then
		echo "new_patch=1" >> $GITHUB_OUTPUT
		echo -e "\e[32mNew patch, building...\e[0m"
	elif [ "$date1_sec" -lt "$date2_sec" ]; then
		echo "new_patch=0" >> $GITHUB_OUTPUT
		echo -e "\e[32mOld patch, not build.\e[0m"
	else
		echo "new_patch=0" >> $GITHUB_OUTPUT
		echo -e "\e[32mSame patch version, not build.\e[0m"
	fi
}
checker $1 $2 $3