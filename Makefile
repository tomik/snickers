
FLAGS=-Ix_logger/
EXTERNALS=x_logger/*d
LOC_SNICKERS=snickers/*d common/*d $(EXTERNALS)
LOC_MATCH=match/*d common/*d $(EXTERNALS)

all:
	dmd $(FLAGS) $(LOC_SNICKERS) -gc -debug -unittest -ofbin/snickers
	dmd $(FLAGS) $(LOC_MATCH) -gc -debug -unittest -ofbin/match
	#./bin/snickers

dbg:
	dmd $(FLAGS) $(LOC_SNICKERS) -gc -debug -unittest -ofbin/snickers
	#./bin/snickers

prof:
	dmd $(FLAGS) $(LOC_SNICKERS) -O -ofbin/snickers
	#./bin/snickers

clean:
	rm *o bin/* *log 2> /dev/null
