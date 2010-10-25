
#LINUX ?= /lib/modules/$(shell uname -r)/build


CPU=L865
KVER=2.6.24.7-rt27
LINUX=/acc/sys/$(CPU)/usr/src/kernels/$(KVER)/

obj-m = rawrabbit.o

all modules:
	$(MAKE) -C $(LINUX) M=$(shell /bin/pwd) modules

clean:
	rm -rf *.o *~  .*.cmd *.ko *.mod.c .tmp_versions Module.symvers \
		Module.markers modules.order
