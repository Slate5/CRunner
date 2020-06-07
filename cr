#!/bin/bash

error_msgs=$(mktemp)
exec 3> "$error_msgs"
exec 4< "$error_msgs"
rm "$error_msgs"
exec 2>&3

run_file() {
	[[ "$1" != "a.out" ]] && local comp_file=" $1"
	echo -e "\e[1;35mRunning$comp_file...\e[1;0m"
	if [[ $C_BENCHMARK ]]; then command time -f "$TIME" "./$1"
	else "./$1"
	fi
}

check_runtime() {
	if [[ $? != 0 ]]; then
		tput setaf 1
		sed -E "s/\/.*[0-9]+ (.+) .*/Runtime Error: \1/" <&4 >&2
		calc_usr_sys
		tput sgr0
		[[ $output_file ]] && rm -v "$output_file" || rm a.out
		exit 1
	elif [[ $C_BENCHMARK ]]; then calc_usr_sys
	fi
}

remove_files() {
	local file
	for file in $(ls -F | grep "$1"); do
		readelf -p .comment "./$file" | grep -Eq '(GCC|clang)' && rm -v "./$file"
	done
}

calc_usr_sys() {
	local desc_4=$(cat <&4)
	sed "s/....+..../$(grep -o '....+....' <<< "$desc_4" | bc)/" <<< "$desc_4"
}

TIME="\nBenchmark data:\nreal\t%E\nuser\t%U\nsys\t%S\nusr+sys\t%U+%S\nCPU\t%P\nRSS\t%M KB"
readonly VALID_EXTENSIONS='\b\.(c(c?|pp?|[x+]{2})|C(PP)?|go|ii?)($| )'
[[ "$@" =~ (^| )-b($| ) ]] && export C_BENCHMARK='yes'

if [[ "$@" =~ (^| )-h($| ) ]]; then set -- "-h"
elif [[ "$@" =~ (^| )(comp|rm[ta])($| ) ]]; then set -- "${BASH_REMATCH[2]}"
else
	for arg do
		shift
		case "$arg" in
			-b) ;;
			+*) output_file="${arg:1}"; set -- "$@" "-o" "$output_file";;
			-o) output_file="$1";&
			*) set -- "$@" "$arg";;
		esac
	done
fi

if [[ -x $1 && -z $2 ]]; then
	if readelf -p .comment "./$1" |& grep -Eq '(GCC|clang)'; then
		run_file "$1"
		check_runtime
	else echo "Not a GCC compiled file: $1"
	fi
elif [[ "$1" == "comp" ]]; then
	for file in $(ls -Ft | grep '*$'); do
		if readelf -p .comment "./$file" |& grep -Eq '(GCC|clang)'; then
			run_file "$file"
			check_runtime
			exit 0
		fi
	done
	echo "There are no GCC compiled files here"
elif [[ "$1" == "-h" ]]; then
	cat <<- EOF
		Compiles and runs programs written in C/C++/Go using GCC.

		Default: cr (runs last modified <file.c>)
		Usage: cr [file.c|compiled_file] [+output_file_name]
		Examples: cr file.c || cr +output_file_name file.c || cr +output_file_name

		  -b                  Show benchmark data.
		  -h                  Display this information.
		  --help[=]           Display GCC's information.
		  rmt                 Remove compiled "test(n)" files.
		  rma                 Remove all compiled (GCC) files.
		  comp                Run the most recently compiled file.
		  +output_file_name   Place the output into "output_file_name".

		Explanation:
		  This program will compile a file and run it as well. If compiling lasts
		  for more than 0.5 sec, after a runtime, a compiled file will be saved as
		  a "test(n)". Else, a.out will be removed if [+output_file_name] is omitted.
	EOF
elif [[ "$1" == "rmt" ]]; then
	remove_files "^test[0-9]\+\*$"
elif [[ "$1" == "rma" ]]; then
	remove_files "*$"
else
	trap 'if [[ -z $output_file ]]; then rm a.out; fi && exit 130' SIGINT
	if ! [[ "$@" =~ $VALID_EXTENSIONS ]]; then
		if gcc "$@"; then exit 0
		elif grep -q -- '--completion=' <&4; then exit 1
		fi
		last_file=$(ls -t | grep -Em 1 "$VALID_EXTENSIONS")
		if [[ -f $last_file && "$last_file" =~ $VALID_EXTENSIONS ]]; then
			set -- "$last_file" "$@"
			last_file=" $last_file"
		else
			echo "There are no C/C++/Go files here"
			exit 2
		fi
	fi
	case "${BASH_REMATCH[1]}" in
		c|i) compiler='gcc';;
		go) command -v gccgo &>/dev/null && compiler='gccgo' || compiler='gcc';;
		*) command -v g++ &>/dev/null && compiler='g++' || compiler='gcc';;
	esac
	echo -e "\e[1;35mCompiling ($compiler)$last_file...\e[0;1m"
	shm=$(mktemp)
	(
		loading='━╲┃╱'
		while [[ -f $shm ]]; do
			printf "${loading:i++%4:1}\e[2D"
			sleep .08
		done
	) &
	start=$(date +%s%N)
	"$compiler" "$@" 2>&1
	[[ $? != 0 ]] && rm "$shm" && exit 1
	end=$(date +%s%N)
	rm "$shm"
	[[ $C_BENCHMARK ]] && echo "Time: $(bc <<< "scale=2; ($end-$start)/1000000000")s"
	if [[ "$output_file" =~ \.ii?$ ]]; then
		cr "$output_file"
	elif [[ -f $output_file ]]; then
		run_file "$output_file"
		check_runtime
	elif [[ -f ./a.out ]]; then
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
