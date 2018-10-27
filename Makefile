SRCS=$(wildcard *.d)

d9cc: $(SRCS)
	dmd -of=d9cc $(SRCS)
debug: $(SRCS)
	dmd -of=d9cc -debug $(SRCS)
test: d9cc
	./test.sh
clean:
	rm d9cc *o *s tmp*