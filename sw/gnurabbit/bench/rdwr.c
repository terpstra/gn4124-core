/*
 * Trivial performance test for read(2)/write(2) I/O
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
#include <stdint.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "rawrabbit.h"

#define DEVNAME "/dev/rawrabbit"

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

	/* write */
	lseek(fd, __RR_SET_BAR(4) | 0xa08, SEEK_SET);
	gettimeofday(&tv1, NULL);
	while (count--) {
		static uint32_t values[] = {0x0000, 0xf000};

		write(fd, values + (count & 1), sizeof(values[0]));
		lseek(fd, -sizeof(values[0]), SEEK_CUR);
	}
	gettimeofday(&tv2, NULL);
	usec = (tv2.tv_sec - tv1.tv_sec) * 1000 * 1000
		+ tv2.tv_usec - tv1.tv_usec;
	printf("%i writes in %i usecs\n", count0, usec);
	printf("%i writes per second\n",
	       (int)(count0 * 1000LL * 1000LL / usec));

	/* read: we cut and paste the code, oh so lazy */
	count = count0;
	lseek(fd, __RR_SET_BAR(4) | 0xa08, SEEK_SET);
	gettimeofday(&tv1, NULL);
	while (count--) {
		static uint32_t value;

		read(fd, &value, sizeof(value));
		lseek(fd, -sizeof(value), SEEK_CUR);
	}
	gettimeofday(&tv2, NULL);
	usec = (tv2.tv_sec - tv1.tv_sec) * 1000 * 1000
		+ tv2.tv_usec - tv1.tv_usec;
	printf("%i reads in %i usecs\n", count0, usec);
	printf("%i reads per second\n",
	       (int)(count0 * 1000LL * 1000LL / usec));

	exit(0);
}
