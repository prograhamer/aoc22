.PHONY:
all: clean build

clean:
	rm -f *.o rucksack

build:
	as -o rucksack.o rucksack.s
	ld -o rucksack rucksack.o -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2
