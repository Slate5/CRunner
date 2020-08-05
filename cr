#!/bin/bash
#
# This script is a GCC wrapper

# Checks if configuration file exists
if ! [ -r /etc/CRunner.conf ]; then
	echo -e "\e[1;31mConfiguration missing, run \e[3mmake\e[23m from CRunner directory.\e[0m" >&2
	exit 1
fi

# Checks validity of argv option which takes arguments
for arg do
	if [[ "${arg}" =~ ^argv=$ ]]; then
		echo -e "\e[1;31mOption \e[3margv\e[23m requires argument: argv='<arguments>'\e[0m"
		exit 22
	fi
done

# Opens two more file descriptor and forwards STDERR to it throughout the script
error_msgs="$(mktemp)"
exec 3>"${error_msgs}"
exec 4<"${error_msgs}"
rm "${error_msgs}"
unset error_msgs
exec 2>&3

# Fills associative array with key/value from configuration file
declare -A CONF
while IFS='= ' read key value; do
	[[ "${key}" =~ ^(#|$) ]] || CONF["${key}"]="${value}"
done < /etc/CRunner.conf

# Runs a file after compilation, taking care of benchmark and arguments passed to file
run_file() {
	[[ "${1}" != "a.out" ]] && local comp_file=" ${1}"
	echo -e "\e[1;35mRunning\e[3m${comp_file}\e[23m...\e[39m"
	[[ "${1}" == */* ]] || path='./'
	if [[ ${BENCHMARK} ]]; then command time -f "${TIME}" "${path}${1}" ${argv}
	else "${path}${1}" ${argv}
	fi
}

# After execution of compiled file exit status will be checked to properly parse
# error message (lefting out Bash error component). If benchmarked calc_usr_sys
# function will be called to summarize USR and SYS CPU time.
check_runtime() {
	if [[ $? != 0 ]]; then
		sed -E 's/\/.*[0-9]+ (.+) "\$\{path.*/Runtime Error: \1/' <&4 >&2
		tput setaf 1
		calc_usr_sys
		tput sgr0
		[[ ${CONF[rm_aout],,} == true ]] && rm -f "${path}a.out"
		exit 1
	elif [[ ${BENCHMARK} ]]; then calc_usr_sys
	fi
}

# Function used by rmt and rma options, deletes files compiled using GCC or Clang
remove_files() {
	local file
	for file in $(ls -F | grep "$1"); do
		readelf -p .comment "./${file}" | grep -Eq '(GCC|clang)' && rm -v "./${file}"
	done
}

# Calculate USR + SYS CPU time when benchmark option is ON and output it to STDOUT
calc_usr_sys() {
	local desc_4="$(cat <&4)"
	sed "s/....+..../$(grep -o '....+....' <<< "${desc_4}" | bc)/" <<< "${desc_4}"
}

# Global variables
TIME="\nBenchmark data:\nreal\t%E\nuser\t%U\nsys\t%S\nusr+sys\t%U+%S\nCPU\t%P\nRSS\t%M KB"
readonly VALID_EXTENSIONS='\b\.(c(c?|pp?|[x+]{2})|C(PP)?|go|ii?)($| )'
export LC_ALL=C

# Separates GCC's options from CRunner's options. Applying underling logic for
# CRunner's options and appends GCC's options to "$@" which will be passed to GCC
for arg do
	shift
	case "${arg}" in
		-h|rmt|rma|flush)
			set -- "${arg}"
			break
			;;
		benchmark)
			export BENCHMARK=true
			;;
		argv=*)
			export argv+="${arg:5} "
			;;
		only-compile)
			only_compile=true
			;;
		+*)
			output_file="${arg:1}"
			set -- "$@" "-o" "${output_file}"
			;;
		-o)
			output_file="${1}"
			;&
		*)
			set -- "${@}" "${arg}"
			;;
	esac
done

if [[ -x ${1} && -z ${2} && ! "${1}" =~ ${VALID_EXTENSIONS} ]]; then
	if readelf -p .comment "${1}" |& grep -Eq '(GCC|clang)'; then
		run_file "${1}"
		check_runtime
	else echo -e "Not a GCC compiled file: \e[3m${1}\e[23m"
	fi
	exit 1
fi

case "${1}" in
	comp)
		for file in $(ls -Ft | grep '*$'); do
			if readelf -p .comment "./${file}" |& grep -Eq '(GCC|clang)'; then
				run_file "${file}"
				check_runtime
				exit 0
			fi
		done
		echo "There are no GCC compiled files here"
		;;
	-h)
		cat <<- EOF
			Compiles and runs programs written in C, C++ or Go using GCC.

			Configuration: /etc/CRunner.conf
			Default: cr (runs last modified <file.c>)
			Usage: cr [file.c|compiled_file] [+output_file_name]
			Examples: cr file.c || cr +output_file_name file.c || cr +output_file_name

				-h                  Display this information.
				--help[=]           Display GCC's information.
				rmt                 Remove compiled "test(n)" files.
				rma                 Remove all compiled (GCC) files.
				comp                Run the most recently compiled file.
				exec='<cmd>'        Cmd passed in as a string is executed.
				argv='args'         Pass the arguments to the compiled file.
				+output_file_name   Place the output into "output_file_name".
				only-compile        Compile but do not run the compiled file.
				benchmark           Show benchmark data (time, CPU, memory...).
				flush               Flush Page Cache only and show memory state.

			Explanation:
				This program will compile a file and run it as well. If compiling lasts
				for more than 0.5 sec, after a runtime, a compiled file will be saved as
				a "test(n)". Else, a.out will be removed if [+output_file_name] is omitted.
		EOF
		;;
	rmt)
		remove_files "^test[0-9]\+\*$"
		;;
	rma)
		remove_files "*$"
		;;
	flush)
		echo -e "\e[1;31mMemory state before:\n$(free -h 2>/dev/null || free -m)\n"
		sudo sh -c 'sync; echo 1 > /proc/sys/vm/drop_caches'
		echo -e "\e[1;32mMemory state now:\n$(free -h 2>/dev/null || free -m))\e[0m"
		;;
	*)
		if ! [[ "${@}" =~ ${VALID_EXTENSIONS} ]]; then
			gcc "${@}" && exit 0
			desc_4="$(cat <&4)"
			case "${desc_4}" in
				*--completion=*) exit 1 ;;
				*No\ such\ file\ or\ directory*)
					echo -e "$(sed -E 's/gcc:(.*error:)/gcc:\\e[31m\1\\e[39m/' <<< "${desc_4}")"
					exit 1
					;;
				*undefined\ reference*main*|*file\ format\ not\ recognized*)
					echo "${desc_4}"
					exit 1
					;;
			esac
			last_file="$(ls -t | grep -Em 1 "${VALID_EXTENSIONS}")"
			if [[ "${last_file}" =~ ${VALID_EXTENSIONS} ]]; then
				set -- "./${last_file}" "$@"
				last_file=" ${last_file}"
			else
				echo "There are no C, C++ nor Go source files here"
				exit 2
			fi
		fi
		trap '{
						[ -f "${shm}" ] && rm "${shm}"
						printf "\e[?25h"
						stty echo
					}' 0
		case "${BASH_REMATCH[1]}" in
			c|i) compiler='gcc';;
			go) command -v gccgo &>/dev/null && compiler='gccgo' || compiler='gcc';;
			*) command -v g++ &>/dev/null && compiler='g++' || compiler='gcc';;
		esac
		echo -e "\e[1;35mCompiling (${compiler})\e[3m${last_file}\e[23m...\e[39m"
		shm="$(mktemp)"
		stty -echo
		(
			loading='━╲┃╱'
			printf "\e[?25l"
			while [[ -f ${shm} ]]; do
				printf "${loading:i++%4:1}\e[2D"
				sleep .08
			done
			printf ' \e[1D\e[?25h'
		) &
		start=$(date +%s%N)
		"${compiler}" "${@}" 2>&1
		[[ $? != 0 ]] && rm "${shm}" && exit 1
		end=$(date +%s%N)
		rm "${shm}"
		stty echo
		[[ ${BENCHMARK} ]] && echo "Time: $(bc <<< "scale=2; (${end}-${start})/1000000000")s"
		if [[ ${only_compile} ]]; then
			output_file="${output_file:-a.out}"
			echo -e "\e[1;35mCompiled file \e[3m${output_file}\e[23m is ready...\e[0m"
		elif [[ "${output_file}" =~ \.ii?$ ]]; then
			for arg do [[ "$arg" =~ --?..+ ]] && flags+="$arg "; done
			cr "${output_file}" $flags
		elif [[ -f ${output_file} ]]; then
			run_file "${output_file}"
			check_runtime
		elif [[ -f a.out ]]; then
			run_file a.out
			check_runtime
			if [[ ${CONF[cp_test],,} == true && $(bc <<< "${end}-${start} > ${CONF[time]}*1000000000") == 1 ]]; then
				mv a.out "test$(( $(ls -rv test* | grep -om 1 '[0-9]\+') + 1 ))"
			elif [[ ${CONF[rm_aout],,} == true ]]; then
				rm -f a.out
			fi
		fi
		;;
esac
