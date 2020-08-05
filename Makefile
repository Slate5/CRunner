# Usage:
# make           # install cr
# make clean     # remove symbolic link and previously installed directory, if any
# make remove    # uninstall cr

cr_path := $(abspath $(dir $(MAKEFILE_LIST)))
old_cr_chk := $(shell readlink -fn /usr/local/bin/cr | sed -E 's/(.*)\/cr/\1/')

define configuration_prompt
	read value;\
	value=$${value:-$(2)};\
	sed -i "s/^$(1) =.*/$(1) = $${value}/" "$(cr_path)/etc/CRunner.conf";\
	printf '\e[34mApplied\e[39m: ';\
	grep "$(1) =.*" "$(cr_path)/etc/CRunner.conf";
endef

define remove_old_files
	if test "$(old_cr_chk)" != "/usr/local/bin"; then\
		sudo rm /usr/local/bin/cr;\
		sudo rm /etc/CRunner.conf;\
		sudo rm /usr/share/bash-completion/completions/cr;\
		echo "Everything's cleaned up";\
		if test "$(old_cr_chk)" != "$(cr_path)"; then\
			rm -rf "$(old_cr_chk)";\
			printf "\e[4mOld CRunner directory removed: $(old_cr_chk)\e[24m\n";\
		fi\
	else\
		printf "Nothing to clean...\n";\
	fi
endef

install: configure
	$(info Installing...)
	sudo ln -sf "$(cr_path)/cr" /usr/local/bin/
	sudo cp -n "$(cr_path)/etc/CRunner.conf" /etc/
	sudo ln -sf "$(cr_path)/etc/cr" /usr/share/bash-completion/completions/

remove: clean
	$(info Removing...)
	rm -rf "$(cr_path)"

configure:
	$(info Configuring...)
	chmod 755 "$(cr_path)/cr"
	chmod 644 "$(cr_path)/etc/CRunner.conf"
	chmod 644 "$(cr_path)/etc/cr"
ifeq (,$(wildcard /etc/CRunner.conf))
	@printf '\e[31mEdit the configuration file. UPPERCASE values are defaults:\e[39m\n'
	@printf '\e[33mAfter the cr command finishes, remove a.out: (TRUE|false) \e[39m'
	@$(call configuration_prompt,rm_aout,true)
	@printf '\e[33mCopy \e[3ma.out\e[23m to \e[3mtest(++i)\e[23m when compilation'\
	' lasts longer than a specific time: (TRUE|false) \e[39m'
	@$(call configuration_prompt,cp_test,true)
	@printf '\e[33mHow long does compiling have to last before renaming '\
	'\e[3ma.out\e[23m to \e[3mtest(++i)\e[23m: (in seconds, default 0.5) \e[39m'
	@$(call configuration_prompt,time,0.5)
	@printf '\e[31mFor future modification, edit \e[3m/etc/CRunner.conf\e[23m'\
	' configuration file.\e[39m\n'
else
	@printf '\e[33mLeaving old configuration file intact... '\
	'(\e[3m`make clean`\e[23m to remove the old configuration)\e[39m\n'
endif

clean:
	$(info Cleaning up...)
	@$(remove_old_files)
