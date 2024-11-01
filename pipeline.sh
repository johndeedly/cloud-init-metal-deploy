#!/usr/bin/env bash

# error handling
set -E -o functrace
err_report() {
  echo "errexit command '${1}' returned ${2} on line $(caller)" 1>&2
  exit "${2}"
}
trap 'err_report "${BASH_COMMAND}" "${?}"' ERR

packer_buildappliance() {
	local _longopts="search,filter,args"
	local _opts="s:f:a:"
	local _parsed=$(getopt --options=$_opts --longoptions=$_longopts --name "$0" -- "$@")
	# read getopt’s output this way to handle the quoting right:
	eval set -- "$_parsed"
	local _search=""
	local _filter=""
	local _args=()
	while true; do
		case "$1" in
			-s|--search)
				_search="$2"
				shift 2
				;;
			-f|--filter)
				_filter="$2"
				shift 2
				;;
			-a|--args)
				_args=( $2 )
				shift 2
				;;
			--)
				shift
				break
				;;
			*)
				echo "usage: packer_buildappliance [[-s|-f|-a] ...]+" 1>&2
				exit 1
				;;
		esac
	done
	
	local _runit="YES"
	if [ -n "$_search" ]; then
		local _params=( -type f -name "$_search" )
		if [ -n "$_filter" ]; then
			_params+=( -wholename "$_filter" )
		fi
		find output "${_params[@]}" | while read -r line; do
			echo "$line"
			_runit=""
		done
	fi
	if [ -n "$_runit" ]; then
		case $VIRTENV in
			wsl)
				# windows
				env PACKER_LOG=1 PACKER_LOG_PATH=output/cloud.ready-packerlog.txt \
					PKR_VAR_sound_driver=dsound PKR_VAR_accel_graphics=off /bin/packer "${_args[@]}"
				return $?
				;;
			*)
				# others, including linux
				env PACKER_LOG=1 PACKER_LOG_PATH=output/cloud.ready-packerlog.txt \
					PKR_VAR_sound_driver=pulse PKR_VAR_accel_graphics=on /bin/packer "${_args[@]}"
				return $?
				;;
		esac
	fi
	return -1
}

mkdir -p output
VIRTENV=$(systemd-detect-virt || true)
case $VIRTENV in
	wsl)
		# windows
		packer_buildappliance -s "*cloud.ready*.ova" -a "build -force -on-error=ask -only=virtualbox-iso.default cloud.ready.pkr.hcl"
		;;
	*)
		# others, including linux
		packer_buildappliance -s "*cloud.ready*.qcow2" -a "build -force -on-error=ask -only=qemu.default cloud.ready.pkr.hcl"
		;;
esac
