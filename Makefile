d9cc: d9cc.d
	dmd -of=d9cc d9cc.d
test: d9cc
	./test.sh
clean:
	rm d9cc *o *s tmp*