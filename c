#!/bin/bash

error_msgs=$(mktemp)
exec 3> "$error_msgs"
exec 4< "$error_msgs"
rm "$error_msgs"
exec 2>&3

run_file() {
	if [[ "$C_BENCHMARK" ]]; then /usr/bin/time -f "$TIME" "./$1"
	else "./$1"
	fi
}

check_runtime() {
	if [[ $? != 0 ]]; then
		tput setaf 1
		sed -E "s/\/.*[0-9]+ (.+) .*/Runtime Error: \1/" <&4
		tput sgr0
		[[ "$output_file" ]] && rm -v "$output_file" || rm a.out
		exit 1
	else
		desc_4=$(cat <&4)
		sed "s/....+..../$(grep -o '....+....' <<< "$desc_4" | bc)/" <<< "$desc_4"
	fi
}

remove_files() {
	for file in $(ls -F | grep "$1"); do
		readelf -p .comment "./$file" | grep -Eq '(GCC|clang)' && rm -v "./$file"
	done
}

TIME="\nBenchmark data:\nreal\t%E\nuser\t%U\nsys\t%S\nusr+sys\t%U+%S\nCPU\t%P\nRSS\t%M KB"
readonly VALID_EXTENSIONS='\b\.(c(c?|pp?|[x+]{2})|C(PP)?)($| )'

if [[ "$@" =~ (^| )-h($| ) ]]; then set -- "-h"
else
	[[ "$@" =~ (^| )-b($| ) ]] && C_BENCHMARK='yes'
	for arg do
		shift
		case $arg in
			comp|rmt|rmc) set -- "$arg"; break;;
			-b) ;;
			+*) output_file="${arg:1}"; set -- "$@" "-o" "$output_file";;
			-o) output_file="$1";&
			*) set -- "$@" "$arg";;
		esac
	done
fi

if [[ -x "$1" && -z "$2" ]]; then
	if (readelf -p .comment "./$1" | grep -Eq '(GCC|clang)'); then
		run_file "$1"
		check_runtime
	else echo "Not a GCC compiled file: $1"
	fi
elif [[ "$1" == "comp" ]]; then
	for file in $(ls -Ft | grep '*$'); do
		if (readelf -p .comment "./$file" | grep -Eq '(GCC|clang)'); then
			echo -e "Running $file...\n"
			run_file "$file"
			check_runtime
			exit 0
		fi
	done
	echo "There are no GCC compiled files here"
elif [[ "$1" == "-h" ]]; then
	cat <<- EOF
		Compiles and runs programs written in C/C++ using GCC.

		Default: c (runs last modified <file.c>)
		Usage: c [file.c|compiled_file] [+output_file_name]
		Examples: c file.c || c +output_file_name file.c || c +output_file_name

		  -b                  Benchmark test
		  -h                  Display this help text
		  --help[=]           Generic or specific GCC help text
		  comp                Run the most recently compiled file
		  +output_file_name   Place the output into 'output_file_name'
		  rmt                 Remove comp test(n) files from the current directory
		  rmc                 Remove every compiled file from the current directory

		Explanation:
		  This program will compile a file and run it as well. If compiling lasts
		  for more than 0.5 sec, after a runtime, a compiled file will be saved as
		  a "test(n)". Else, a.out will be removed if [+output_file_name] is omitted.
	EOF
elif [[ "$1" == "rmt" ]]; then
	remove_files "^test[0-9]\+\*$"
elif [[ "$1" == "rmc" ]]; then
	remove_files "*$"
else
	trap 'if [[ -z "$output_file" ]]; then rm a.out; fi && exit 130' SIGINT
	if ! [[ $(gcc -fsyntax-only "$@" 2> /dev/null) || "$@" =~ $VALID_EXTENSIONS ]]; then
		last_c_file=$(ls -t | grep -Em 1 "$VALID_EXTENSIONS")
		if [[ "$last_c_file" ]]; then
			echo -e "Compiling and running $last_c_file...\n"
			set -- "$@" "$last_c_file"
		else
			echo "There are no C/C++ files here"
			exit 2
		fi
	fi
	start=$(date +%s%N)
	gcc "$@" 2>&1 || exit
	end=$(date +%s%N)
	if [[ -f "$output_file" ]]; then
		run_file "$output_file"
		check_runtime
	elif [[ -f "./a.out" ]]; then
		run_file a.out
		check_runtime
		if [[ $(( end - start )) -lt 500000000 ]]; then
			rm a.out
		else
			name=test$(( $(ls -rv test* | grep -om 1 '[0-9]\+') + 1 ))
			mv a.out "$name"
		fi
	fi
fi
