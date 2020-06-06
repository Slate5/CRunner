# Usage:
# make           # install cr
# make clean     # remove symbolic link and previously installed directory, if any
# make remove    # uninstall cr

cr_path := $(abspath $(dir $(MAKEFILE_LIST)))
old_cr_chk := $(shell readlink -fn /usr/local/bin/cr | sed -E 's/(.*)\/cr/\1/')

define remove_old_files =
	if test "$(old_cr_chk)" != "/usr/local/bin"; then\
		sudo rm /usr/local/bin/cr;\
		sudo rm /usr/share/bash-completion/completions/cr;\
		echo "Symbolic links removed";\
		if test "$(old_cr_chk)" != "$(cr_path)"; then\
			rm -rf "$(old_cr_chk)";\
		echo "\e[4mOld CRunner directory removed: $(old_cr_chk)\e[24m";\
		fi\
	fi
endef

install: configure clean
	$(info Installing...)
	sudo ln -s "$(cr_path)/cr" /usr/local/bin/
	sudo ln -s "$(cr_path)/etc/cr" /usr/share/bash-completion/completions/

remove: clean
	$(info Removing...)
	rm -rf "$(cr_path)"

configure:
	$(info Configuring...)
	chmod 755 "$(cr_path)/cr"

clean:
	$(info Cleaning up...)
	@$(remove_old_files)
