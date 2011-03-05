
FLAGS=-Ix_logger/
LOCATIONS=snickers/*d x_logger/*d

all:
	dmd $(FLAGS) $(LOCATIONS) -gc -debug -unittest -ofbin/snickers
	./bin/snickers

dbg:
	dmd $(FLAGS) $(LOCATIONS) -gc -debug -unittest -ofbin/snickers
	./bin/snickers

prof:
	dmd $(FLAGS) $(LOCATIONS) -O -ofbin/snickers
	./bin/snickers

clean:
	rm *o bin/* *log 2> /dev/null
