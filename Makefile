SRCS=$(wildcard *.d)

d9cc: $(SRCS)
	dmd -of=d9cc $(SRCS)
debug: $(SRCS)
	dmd -of=d9cc -debug -g $(SRCS)
test: d9cc
	@./d9cc "$$(gcc -E -P test/test.c)" > tmp-test.s
	@echo 'int global_arr[1] = {5};' | gcc -xc -c -o tmp-test2.o -
	@gcc -static -o tmp-test tmp-test.s tmp-test2.o
	@./tmp-test
clean:
	rm -f d9cc *o *s tmp*

.PHONY: test clean debug