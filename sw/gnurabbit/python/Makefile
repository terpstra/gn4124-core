
CFLAGS = -Wall -ggdb -I../kernel

AS		= $(CROSS_COMPILE)as
LD		= $(CROSS_COMPILE)ld
CC		= $(CROSS_COMPILE)gcc
CPP		= $(CC) -E
AR		= $(CROSS_COMPILE)ar
NM		= $(CROSS_COMPILE)nm
STRIP		= $(CROSS_COMPILE)strip
OBJCOPY		= $(CROSS_COMPILE)objcopy
OBJDUMP		= $(CROSS_COMPILE)objdump

ALL = rrlib.so

all: $(ALL)

rrlib.so: rrlib.o
	$(CC) $(CFLAGS) -o $@ -shared $^

clean:
	rm -f $(ALL) *.o *~ *.so  *.pyc
