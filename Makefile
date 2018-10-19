SRCS=$(wildcard *.d)

d9cc: $(SRCS)
	dmd -of=d9cc $(SRCS)
test: d9cc tmp-plus.o
	./test.sh
tmp-plus.o:
	echo 'int plus(int x, int y) { return x + y; }' | gcc -xc -c -o tmp-plus.o -
clean:
	rm d9cc *o *s tmp*