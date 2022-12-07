.PHONY:
all: clean build

clean:
	rm -f *.o rocks

build:
	as -o rocks.o rocks.s
	ld -o rocks rocks.o -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2
