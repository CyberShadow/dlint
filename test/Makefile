DLINT=../dlint

SOURCES=$(shell find ../source -name '*.d')
TESTS=$(shell find . -name '*.d')
TESTS_OK=$(addsuffix .ok, $(TESTS))

all : $(TESTS_OK)

$(DLINT) : $(SOURCES)
	env -C .. dub

%.out : % $(DLINT)
	$(DLINT) $< &> $@

%.ok : %.out %.exp
	diff -u $< $*.exp
	touch $@

.SECONDARY: $(addsuffix .out, $(TESTS))
.PHONY: all
.SUFFIXES:
.DELETE_ON_ERROR:
