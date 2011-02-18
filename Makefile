
all:
	dmd *d -gc -debug -unittest -ofsnickers
	./snickers

clean:
	rm *o snickers *log
