DLINT=../dlint

SOURCES=$(shell find ../source -name '*.d')
TESTS=$(shell find . -name '*.d')
TESTS_OUT=$(addsuffix .out, $(TESTS))

all : $(TESTS_OUT)

$(DLINT) : $(SOURCES)
	env -C .. dub

%.out : % $(DLINT)
	$(DLINT) $< &> $@

.PHONY: all
.SUFFIXES:
.DELETE_ON_ERROR:
