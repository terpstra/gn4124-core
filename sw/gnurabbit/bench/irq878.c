/*
 * Trivial performance test for irq management
 *
 * Copyright (C) 2010 Alessandro Rubini <rubini@gnudd.com>
 * Released according to the GNU GPL, version 2 or any later version.
 *
 * This work is part of the White Rabbit project and has been sponsored
 * by CERN, the European Institute for Nuclear Research.
 */
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include "rawrabbit.h"

#define DEVNAME "/dev/rawrabbit"
#define ARRAY_SIZE(arr) (sizeof(arr) / sizeof((arr)[0]))


struct rr_devsel devsel = {
	.vendor = 0x109e,
	.device = 0x036e,
	.subvendor = RR_DEVSEL_UNUSED,
	.bus = RR_DEVSEL_UNUSED,
};

#define ENA_VAL  0x02
#define ENA_REG (__RR_SET_BAR(0) | 0x104)
#define ACK_REG (__RR_SET_BAR(0) | 0x100)


struct rr_iocmd iocmd = {
	.datasize = 4,
};

int main(int argc, char **argv)
{
	int fd, count, count0, nsec;
	unsigned long long total = 0LL;

	if (argc != 2) {
		fprintf(stderr, "%s: use \"%s <count>\"\n", argv[0], argv[0]);
		exit(1);
	}
	count0 = count = atoi(argv[1]);
	if (!count) {
		fprintf(stderr, "%s: not a number \"%s\"\n", argv[0], argv[1]);
		exit(1);
	}

	fd = open(DEVNAME, O_RDWR);
	if (fd < 0) {
		fprintf(stderr, "%s: %s: %s\n", argv[0], DEVNAME,
			strerror(errno));
		exit(1);
	}

	/* choose the 878 device */
	if (ioctl(fd, RR_DEVSEL, &devsel) < 0) {
		fprintf(stderr, "%s: %s: ioctl: %s\n", argv[0], DEVNAME,
			strerror(errno));
		exit(1);
	}

	/* enable */
	iocmd.address = ENA_REG;
	iocmd.data32 = ENA_VAL;
	if (ioctl(fd, RR_WRITE, &iocmd) < 0) {
		fprintf(stderr, "%s: %s: ioctl: %s\n", argv[0], DEVNAME,
			strerror(errno));
		exit(1);
	}
	iocmd.address = ACK_REG;

	while (count) {
		nsec = ioctl(fd, RR_IRQWAIT);
		if (nsec < 0) {
			if (errno == EAGAIN) {
				ioctl(fd, RR_IRQENA);
				continue;
			}
			fprintf(stderr, "%s: %s: ioctl: %s\n", argv[0], DEVNAME,
				strerror(errno));
			exit(1); /* Argh! */
		}
		count--;

		/* ack: this must work */
		ioctl(fd, RR_WRITE, &iocmd);

		nsec = ioctl(fd, RR_IRQENA, &iocmd);
		if (nsec < 0) {
			fprintf(stderr, "%s: %s: ioctl: %s\n", argv[0], DEVNAME,
				strerror(errno));
			/* Hmm... */
		} else {
			total += nsec;
		}
	}
	/* now disable and then acknowledge */
	iocmd.address = ENA_REG;
	iocmd.data32 = 0;
	ioctl(fd, RR_WRITE, &iocmd);
	iocmd.address = ACK_REG;
	iocmd.data32 = ~0;
	ioctl(fd, RR_WRITE, &iocmd);

	printf("got %i interrupts, average delay %lins\n", count0,
	       (long)(total / count0));
	exit(0);

}
