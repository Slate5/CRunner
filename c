#!/bin/bash

error_msgs=$(mktemp)
exec 3> "$error_msgs"
exec 4< "$error_msgs"
rm "$error_msgs"
exec 2>&3

runtime_error_chk(){
  if [[ $? != 0 ]]; then
    tput setaf 1
    sed -E "s/\/.*[0-9]+ (.+) .*/Runtime Error: \1/" <&4
    tput sgr0
  fi
}

readonly VALID_EXTENSIONS='\.(c(c?|pp?|[x+]{2})|C(PP)?)$'

if [[ -z "$1" ]]; then
  last_c_file=$(ls -t | grep -Em 1 "$VALID_EXTENSIONS")
  if [[ -n "$last_c_file" ]]; then
    echo "Running $last_c_file..."
    c "./$last_c_file"
  else echo "There are no C/C++ files"
  fi
elif [[ "$1" =~ ^(-c|comp)$ ]]; then
  for i in {1..20}; do
    last_compiled_file=$(ls -tF | grep -m "$i" '*$' | tail -1 | sed 's/.$//')
    if (readelf -p .comment "$last_compiled_file" | grep -q 'GCC'); then
      echo "Running $last_compiled_file..."
      "./$last_compiled_file"
      exit
    fi
  done
  echo "There are no C/C++ compiled files"
elif [[ "$1" =~ ^(-h|--help)$ ]]; then
	cat <<- EOF
		Compile and run programs written in C/C++.

		Default: c (runs last modified file.c)
		Usage: c <file.c|compiled_file> [output_file_name]
		Example: c file.c || c file.c output_file_name || c test1

		  -h, --help            display this help text
		  -c, comp              runs the most recently compiled file
		  rm, clear             remove all test files from current directory

		Explanation:
		  This program will compile a file and run it as well. If compiling lasts
		  for more than 0.5 sec, after a runtime, a compiled file will be saved as
		  a "test(n)". Else, a.out will be removed if [output_file_name] is omitted.
	EOF
elif [[ "$1" =~ ^(rm|clear)$ ]]; then
  rm test* || echo 'There are no test files'
elif [[ -x "$1" && -z "$2" ]]; then
  if (readelf -p .comment "$1" | grep -q 'GCC'); then
    "./$1"
    runtime_error_chk
  else echo "Not a C/C++ compiled file"
  fi
elif [[ -f "$1" || -f "$2" ]]; then
  trap 'if [[ -z "$2" ]]; then rm a.out; fi && exit' SIGINT
  if grep -Eq "$VALID_EXTENSIONS" <<< "$2"; then
    source_file="$2"
    comp_file="$1"
  else
    source_file="$1"
    comp_file="$2"
  fi
  if [[ -n "$2" ]]; then outfile="-o $comp_file"; fi
  start=$(date +%s%N)
  gcc "$source_file" $outfile 2>&1 || exit
  end=$(date +%s%N)
  if [[ -n "$2" ]]; then
    "./$comp_file"
    runtime_error_chk
    exit
  fi
  ./a.out
  runtime_error_chk
  if [[ $(( end - start )) -lt 500000000 ]]; then
    rm a.out
  else
    name=test$(( $(ls -rv test* | grep -om 1 '[0-9]*') + 1 ))
    mv a.out "$name"
  fi
else echo "That file doesn't exist"
fi
