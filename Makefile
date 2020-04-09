# Usage:
# make           # install c
# make clean     # remove symbolic link and previously installed directory, if any
# make remove    # uninstall c

c_path := $(abspath $(dir $(MAKEFILE_LIST)))
old_c_chk := $(shell readlink -fn /usr/local/bin/c | sed -E 's/(.*)\/c/\1/')

define remove_old_files =
	if test "$(old_c_chk)" != "/usr/local/bin"; then\
		sudo rm /usr/local/bin/c;\
		echo "Symbolic link removed";\
		if test "$(old_c_chk)" != "$(c_path)"; then\
			rm -rf "$(old_c_chk)";\
			echo "\e[4mOld c directory removed: $(old_c_chk)\e[24m";\
		fi\
	fi
endef

install: configure clean
	$(info Installing...)
	sudo ln -s "$(c_path)/c" /usr/local/bin/

remove: clean
	$(info Removing...)
	rm -rf "$(c_path)"

configure:
	$(info Configuring...)
	chmod 755 "$(c_path)/c"

clean:
	$(info Cleaning up...)
	@$(remove_old_files)
