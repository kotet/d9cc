SRCS=$(shell find . -name "*.d" -type f)

d9cc: $(SRCS)
	dub build

test: d9cc
	./test.sh

clean:
	rm -f d9cc tmp*