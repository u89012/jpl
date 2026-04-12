LUA ?= lua
JPL := ./jpl

.PHONY: help repl run test ast lua luac clean

help:
	@echo "Jaya commands:"
	@echo "  make repl              Start the Jaya REPL"
	@echo "  make test              Run the Jaya test suite"
	@echo "  make run FILE=path     Compile and run a Jaya file"
	@echo "  make ast FILE=path     Print the AST for a Jaya file"
	@echo "  make lua FILE=path     Print generated Lua for a Jaya file"
	@echo "  make luac FILE=path    Write Lua bytecode (default: luac.out)"

repl:
	$(JPL)

test:
	$(JPL) --t

run:
	@test -n "$(FILE)" || (echo "usage: make run FILE=path/to/file.jpl" && exit 1)
	$(JPL) $(FILE)

ast:
	@test -n "$(FILE)" || (echo "usage: make ast FILE=path/to/file.jpl" && exit 1)
	$(JPL) --ast $(FILE)

lua:
	@test -n "$(FILE)" || (echo "usage: make lua FILE=path/to/file.jpl" && exit 1)
	$(JPL) --lua $(FILE)

luac:
	@test -n "$(FILE)" || (echo "usage: make luac FILE=path/to/file.jpl [OUT=path]" && exit 1)
	$(JPL) --luac $(FILE) $(if $(OUT),$(OUT),luac.out)

clean:
	rm -f luac.out
