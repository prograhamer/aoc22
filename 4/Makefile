.PHONY:
all: clean build

clean:
	rm -f *.o shelves

build:
	as -o shelves.o shelves.s
	ld -o shelves shelves.o -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2
