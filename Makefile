ifneq ($(strip $(spec)),)
	spec_file = $(spec)_spec.lua
endif

test:
	echo $(spec_file)
	nvim --headless --clean --noplugin \
		-u "tests/minimal_init.vim" \
		-c "PlenaryBustedDirectory tests/spec/$(spec_file) { minimal_init = 'tests/minimal_init.vim' }"
