.PHONY:
all: clean build

clean:
	rm -f *.o calories

build:
	as -o calories.o calories.s
	ld -o calories calories.o
