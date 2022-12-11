.PHONY:
all: clean build

clean:
	rm -f *.o shelves

build:
	as -o shelves.o shelves.s
	ld -o shelves -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2 shelves.o

	as -o shelves2.o shelves2.s
	ld -o shelves2 shelves2.o -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2
