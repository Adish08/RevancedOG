#!/bin/bash

# Check github connection stable or not:
check_connection() {
	local max_retries=3
	local retry_count=0
	
	while [[ $retry_count -lt $max_retries ]]; do
		if [[ -n "$GITHUB_TOKEN" ]]; then
			response=$(curl -s -I -H "Authorization: token $GITHUB_TOKEN" -H "User-Agent: ReVanced-Builder" "https://api.github.com/repos/revanced/revanced-patches/releases/latest" 2>/dev/null)
		else
			response=$(curl -s -I -H "User-Agent: ReVanced-Builder" "https://api.github.com/repos/revanced/revanced-patches/releases/latest" 2>/dev/null)
		fi
		
		if echo "$response" | grep -qE "HTTP/(1\\.1|2) 200"; then
			if [[ -n "$GITHUB_OUTPUT" ]]; then
				echo "internet_error=0" >> $GITHUB_OUTPUT
			fi
			echo -e "\e[32mGithub connection OK\e[0m"
			return 0
		elif echo "$response" | grep -qE "HTTP/(1\\.1|2) 403"; then
			echo -e "\e[33mGitHub API rate limit hit, retrying in 5 seconds...\e[0m"
			sleep 5
			retry_count=$((retry_count + 1))
		else
			echo -e "\e[31mGithub connection failed, retrying in 3 seconds...\e[0m"
			sleep 3
			retry_count=$((retry_count + 1))
		fi
	done
	
	if [[ -n "$GITHUB_OUTPUT" ]]; then
		echo "internet_error=1" >> $GITHUB_OUTPUT
	fi
	echo -e "\e[31mGithub connection not stable after $max_retries attempts!\e[0m"
}
check_connection
