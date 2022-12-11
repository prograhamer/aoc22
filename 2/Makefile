.PHONY:
all: clean build

clean:
	rm -f *.o rocks rocks2

build:
	gcc -no-pie -o rocks rocks.s
	gcc -no-pie -o rocks2 rocks2.s
