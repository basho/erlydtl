ERL=erl
ERLC=erlc
REBAR=./rebar3 $(REBAR_ARGS)

all: compile

compile: get-deps
	@$(REBAR) compile

get-deps:
	@$(REBAR) get-deps

update-deps:
	@$(REBAR) upgrade

.PHONY: tests
tests: src/erlydtl_parser.erl
	@$(REBAR) eunit

check: tests dialyze

## dialyzer
PLT_FILE = ./erlydtl.plt
PLT_APPS ?= kernel stdlib compiler erts eunit syntax_tools crypto
DIALYZER_OPTS ?= -Werror_handling -Wrace_conditions -Wunmatched_returns \
		-Wunderspecs --verbose --fullpath
.PHONY: dialyze
dialyze: compile
	@[ -f $(PLT_FILE) ] || $(MAKE) plt
	@dialyzer --plt $(PLT_FILE) $(DIALYZER_OPTS) _build/default/lib/erlydtl/ebin || [ $$? -eq 2 ];

DEPS_PATH = _build/default/lib

## In case you are missing a plt file for dialyzer,
## you can run/adapt this command
.PHONY: plt
plt: compile
# we need to remove second copy of file
	rm -f $(DEPS_PATH)/merl/priv/merl_transform.beam
	@echo "Building PLT, may take a few minutes"
	@dialyzer --build_plt --output_plt $(PLT_FILE) --apps \
		$(PLT_APPS) $(DEPS_PATH)/* || [ $$? -eq 2 ];

clean:
	@[ ! -d $(DEPS_PATH)/merl ] || { echo "Clean merl..." ; $(MAKE) -C $(DEPS_PATH)/merl clean ;}
	@$(REBAR) clean
	rm -fv erl_crash.dump

really-clean: clean
	rm -f $(PLT_FILE)

shell:
	@$(REBAR) shell


# this file must exist for rebar eunit to work
# but is only built when running rebar compile
src/erlydtl_parser.erl: compile

committed:
	@git diff --no-ext-diff --quiet --exit-code || { echo "there are uncommitted changes in the repo." ; false ;}

release: committed check
	@{														      \
		V0=$$(grep vsn src/erlydtl.app.src | sed -e 's/.*vsn,.*"\(.*\)".*/\1/')					   && \
		V1=$$(grep '##' -m 1 NEWS.md | sed -e 's/##[^0-9]*\([0-9.-]*\).*/\1/')					   && \
		read -e -p "OK, all tests passed, current version is $$V0, which version should we release now? ($$V1)" V2 && \
		: $${V2:=$$V1}												   && \
		echo "$$V2 it is..."											   && \
		sed -i -e 's/vsn,.*}/vsn, "'$$V2'"}/' src/erlydtl.app.src						   && \
		git ci -m "release v$$V2" src/erlydtl.app.src								   && \
		git tag $$V2												   && \
		echo 'Updated src/erlydtl.app.src and tagged, run `git push origin master --tags` when ready'                 \
	;}
