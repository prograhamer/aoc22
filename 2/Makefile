.PHONY:
all: clean build

clean:
	rm -f *.o rocks rocks2

build:
	as -o rocks.o rocks.s
	ld -o rocks rocks.o -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2

	as -o rocks2.o rocks2.s
	ld -o rocks2 rocks2.o -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2
