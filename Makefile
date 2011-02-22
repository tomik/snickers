
all:
	dmd *d -gc -unittest -ofsnickers
	./snickers

dbg:
	dmd *d -gc -debug -unittest -ofsnickers
	./snickers

prof:
	dmd *d -O -ofsnickers
	./snickers

clean:
	rm *o snickers *log
