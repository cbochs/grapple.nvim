test:
	printf "\n======\n\n" ; \
	nvim --version | head -n 1 && echo '' ; \
	nvim --headless \
		-u "tests/minimal_init.lua" \
		-c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua', sequential = true }"

test_file:
	printf "\n======\n\n" ; \
	nvim --version | head -n 1 && echo '' ; \
	nvim --headless \
		-u "tests/minimal_init.lua" \
		-c "PlenaryBustedDirectory $(FILE) { minimal_init = 'tests/minimal_init.lua', sequential = true }"

clean:
	rm -rf .tests
