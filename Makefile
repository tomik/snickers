
all:
	dmd *d -gc -unittest -ofsnickers
	./snickers

clean:
	rm *o snickers *log
