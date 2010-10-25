/*
 * Trivial performance test for ioctl I/O
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


struct rr_iocmd iocmd = {
	.address = __RR_SET_BAR(4) | 0xa08,
	.datasize = 4,
};

int main(int argc, char **argv)
{
	int fd, count, count0, usec;
	struct timeval tv1, tv2;

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

	gettimeofday(&tv1, NULL);
	while (count--) {
		static int values[] = {
			/* These make a pwm signal on the leds */
			0xf000, 0xf000, 0xf000, 0xf000,
			0xe000, 0xc000, 0x8000, 0x0000
		};
		iocmd.data32 = values[ count % ARRAY_SIZE(values) ];
		if (ioctl(fd, RR_WRITE, &iocmd) < 0) {
			fprintf(stderr, "%s: %s: ioctl: %s\n", argv[0], DEVNAME,
				strerror(errno));
			exit(1);
		}
	}
	gettimeofday(&tv2, NULL);
	usec = (tv2.tv_sec - tv1.tv_sec) * 1000 * 1000
		+ tv2.tv_usec - tv1.tv_usec;
	printf("%i ioctls in %i usecs\n", count0, usec);
	printf("%i ioctls per second\n",
	       (int)(count0 * 1000LL * 1000LL / usec));
	exit(0);
}
