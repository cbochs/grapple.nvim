nvim \
	--headless \
	--noplugin \
	-u "test/minimal_init.vim" \
	-c "PlenaryBustedDirectory test/spec/ { minimal_init = 'test/minimal_init.vim' }"
