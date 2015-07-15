ERLFLAGS= -pa $(CURDIR)/.eunit -pa $(CURDIR)/ebin -pa $(CURDIR)/deps/*/ebin

EUNIT_INDEX=./.eunit/index.html
DEPS_PLT=$(CURDIR)/.deps_plt
DEPS=erts kernel stdlib compiler crypto eunit
DIALYZER_OPTS=-Wunmatched_returns -Werror_handling -Wrace_conditions -Wunderspecs

# =============================================================================
# Verify that the programs we need to run are installed on this system
# =============================================================================
ERL = $(shell which erl)

ifeq ($(ERL),)
$(error "Erlang not available on this system")
endif

REBAR=$(shell which rebar)

ifeq ($(REBAR),)
$(error "Rebar not available on this system")
endif

.PHONY: all compile doc clean test dialyzer typer shell distclean pdf \
  update-deps clean-common-test-data rebuild pages publish


all: deps compile dialyzer test
sure: compile dialyzer test assert_full_coverage

# =============================================================================
# Rules to build the system
# =============================================================================

deps:
	$(REBAR) get-deps
	$(REBAR) compile

update-deps:
	$(REBAR) update-deps
	$(REBAR) compile

compile:
	$(REBAR) skip_deps=true compile

assert_full_coverage:
	@grep --quiet "<tr><td><a href='x.COVER.html'>x</a></td><td>100%</td>" $(EUNIT_INDEX)

doc:
	-rm -rf doc
	$(REBAR) skip_deps=true doc

eunit: compile clean-common-test-data
	-@rm -rf $(EUNIT_INDEX)
	@if [ $$SUITE ]; then $(REBAR) skip_deps=true eunit suite=$$SUITE; \
                         else $(REBAR) skip_deps=true eunit; fi

test: compile eunit

$(DEPS_PLT):
	@echo Building local plt at $(DEPS_PLT)
	@echo
	dialyzer --output_plt $(DEPS_PLT) --build_plt \
	   --apps $(DEPS) -r deps

dialyzer: $(DEPS_PLT)
	dialyzer --fullpath --plt $(DEPS_PLT) $(DIALYZER_OPTS) -r ./ebin

typer:
	typer --plt $(DEPS_PLT) -r ./src

shell: deps compile
# You often want *rebuilt* rebar tests to be available to the
# shell you have to call eunit (to get the tests
# rebuilt). However, eunit runs the tests, which probably
# fails (thats probably why You want them in the shell). This
# runs eunit but tells make to ignore the result.
	- @$(REBAR) skip_deps=true eunit
	@$(ERL) $(ERLFLAGS)

pdf:
	pandoc README.md -o README.pdf

clean:
	- rm -rf $(CURDIR)/test/*.beam
	- rm -rf $(CURDIR)/logs
	- rm -rf $(CURDIR)/ebin
	$(REBAR) skip_deps=true clean

distclean: clean
	- rm -rf $(DEPS_PLT)
	- rm -rvf $(CURDIR)/deps

rebuild: distclean deps compile escript dialyzer test

pages:
	@(git branch -v | grep -q gh-pages || (echo local gh-pages branch missing; false))
	@echo
	@git branch -av | grep gh-pages
	@echo
	@(echo 'Is the branch up to date? Press enter to continue.'; read dummy)
	git clone -b gh-pages . pages

publish: doc pages
	rm -rf pages/*
	cp -r doc/. pages/.
	(cd pages; git add -A)
	-(cd pages; git commit -m "Update $(date +%Y%m%d%H%M%S)")
	(cd pages; git push origin gh-pages)
	rm -rf pages
	git push origin gh-pages
