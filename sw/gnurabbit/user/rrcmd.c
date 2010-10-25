/*
 * User space frontend (command line) for the raw I/O interface
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
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include "rawrabbit.h"

#define DEVNAME "/dev/rawrabbit"

char *prgname;

void help(void)
{
	fprintf(stderr, "%s: use like this (all numbers are hex):\n"
		"   %s [<vendor:device>[/<subvendor>:<subdev>]"
		"[@<bus>:<devfn>]] <cmd>\n", prgname, prgname);
	fprintf(stderr, "   <cmd> = info\n");
	fprintf(stderr, "   <cmd> = irqwait\n");
	fprintf(stderr, "   <cmd> = irqena\n");
	fprintf(stderr, "   <cmd> = getdmasize\n");
	fprintf(stderr, "   <cmd> = getplist\n");
	fprintf(stderr, "   <cmd> = r[<sz>] <bar>:<addr>\n");
	fprintf(stderr, "   <cmd> = w[<sz>] <bar>:<addr> <val>\n");
	fprintf(stderr, "      <sz> = 1, 2, 4, 8 (default = 4)\n");
	fprintf(stderr, "      <bar> = 0, 2, 4, c (c == dma buffer)\n");
	exit(1);
}

int parse_devsel(int fd, char *arg)
{
	struct rr_devsel devsel;
	int n;

	devsel.subvendor = RR_DEVSEL_UNUSED;
	devsel.bus = RR_DEVSEL_UNUSED;

	if (strlen(arg) > 32) /* to prevent overflow with strtol */
		return -EINVAL;

	n = sscanf(arg, "%hx:%hx/%hx:%hx@%hx:%hx",
		   &devsel.vendor, &devsel.device,
		   &devsel.subvendor, &devsel.subdevice,
		   &devsel.bus, &devsel.devfn);
	switch(n) {
	case 6: /* all info */
	case 4: /* id/subid but no busdev */
		break;
	case 2:
		/* check if bus/dev is there */
		n = sscanf(arg, "%hx:%hx@%hx:%hx",
			   &devsel.vendor, &devsel.device,
			   &devsel.bus, &devsel.devfn);
		if (n == 4 || n == 2)
			break;
		/* fall through */
	default:
		printf("%s: can't parse \"%s\"\n", prgname, arg);
		return -EINVAL;
	}

	/* Now try to do the change */
	if (ioctl(fd, RR_DEVSEL, &devsel) < 0) {
		fprintf(stderr, "%s: %s: ioctl(DEVSEL): %s\n", prgname, DEVNAME,
			strerror(errno));
		return -EIO;
	}

	return 0;
}

int do_iocmd(int fd, char *cmdname, char *addr, char *datum)
{
	char rest[32];
	struct rr_iocmd iocmd;
	int i, ret;
	unsigned bar;
	__u64 d;
	char cmd;

	if (strlen(cmdname) >= sizeof(rest))
		return -EINVAL;
	if (strlen(addr) >= sizeof(rest))
		return -EINVAL;
	if (datum && strlen(addr) >= sizeof(rest))
		return -EINVAL;

	/* parse command and size */
	i = sscanf(cmdname, "%c%i%s\n", &cmd, &iocmd.datasize, rest);
	if (cmd != 'r' && cmd != 'w')
		return -EINVAL;
	if (i == 3)
		return -EINVAL;
	if (i == 1)
		iocmd.datasize = 4;

	/* parse address */
	i = sscanf(addr, "%x:%x%s", &bar, &iocmd.address, rest);
	if (i != 2)
		return -EINVAL;
	iocmd.address |= __RR_SET_BAR(bar);
	if (!rr_is_valid_bar(iocmd.address))
		return -EINVAL;

	/* parse datum */
	if (datum) {
		i = sscanf(datum, "%llx%s", &d, rest);
		if (i == 2)
			return -EINVAL;
		switch(iocmd.datasize) {
		case 1:
			iocmd.data8 = d;
			break;
		case 2:
			iocmd.data16 = d;
			break;
		case 4:
			iocmd.data32 = d;
			break;
		case 8:
			iocmd.data64 = d;
			break;
		default:
			return -EINVAL;
		}
	}

	if (datum)
		ret = ioctl(fd, RR_WRITE, &iocmd);
	else
		ret = ioctl(fd, RR_READ, &iocmd);

	if (ret < 0)
		return -errno;

	if (!datum && !ret) {
		switch(iocmd.datasize) {
		case 1:
			printf("0x%02x\n", (unsigned int)iocmd.data8);
			break;
		case 2:
			printf("0x%04x\n", (unsigned int)iocmd.data16);
			break;
		case 4:
			printf("0x%08lx\n", (unsigned long)iocmd.data32);
			break;
		case 8:
			printf("0x%016llx\n", (unsigned long long)iocmd.data64);
			break;
		default:
			return -EINVAL;
		}
	}
	return ret;
}

int do_getplist(int fd)
{
	uintptr_t plist[RR_PLIST_LEN];
	int i, size;

	size = ioctl(fd, RR_GETDMASIZE);
	if (size < 0)
		return -errno;
	i = ioctl(fd, RR_GETPLIST, plist);
	if (i < 0)
		return -errno;

	for (i = 0; i < size/RR_PLIST_SIZE; i++)
		printf("buf 0x%08x: pfn 0x%08x, addr 0x%016llx\n",
		       i * RR_PLIST_SIZE, plist[i],
		       (unsigned long long)plist[i] << 12);
	return 0;
}


int main(int argc, char **argv)
{
	struct rr_devsel devsel;
	int fd, ret = -EINVAL;

	prgname = argv[0];

	fd = open(DEVNAME, O_RDWR);
	if (fd < 0) {
		fprintf(stderr, "%s: %s: %s\n", prgname, DEVNAME,
			strerror(errno));
		exit(1);
	}

	/* parse argv[1] for devsel */
	if (argc > 1 && strchr(argv[1], ':')) {
		ret = parse_devsel(fd, argv[1]);
		if (!ret) {
			argc--, argv++;
		}
	}

	if (argc > 1 && !strcmp(argv[1], "info")) {
		if (ioctl(fd, RR_DEVGET, &devsel) < 0) {
			if (errno == ENODEV) {
				printf("%s: not bound\n", DEVNAME);
				exit(0);
			}
			fprintf(stderr, "%s: %s: ioctl(DEVGET): %s\n", prgname,
				DEVNAME, strerror(errno));
			exit(1);
		}
		printf("%s: bound to %04x:%04x/%04x:%04x@%04x:%04x\n", DEVNAME,
		       devsel.vendor, devsel.device,
		       devsel.subvendor, devsel.subdevice,
		       devsel.bus, devsel.devfn);
		ret = 0;
	} else if (argc > 1 && !strcmp(argv[1], "irqwait")) {
		ret = ioctl(fd, RR_IRQWAIT);
		if (ret < 0)
			fprintf(stderr, "%s: ioctl(IRQWAIT): %s\n", argv[0],
				strerror(errno));
	} else if (argc > 1 && !strcmp(argv[1], "irqena")) {
		ret = ioctl(fd, RR_IRQENA);
		if (ret < 0) {
			fprintf(stderr, "%s: ioctl(IRQENA): %s\n", argv[0],
				strerror(errno));
		} else {
			printf("delay: %i ns\n", ret);
			ret = 0;
		}
	} else if (argc > 1 && !strcmp(argv[1], "getdmasize")) {
		ret = ioctl(fd, RR_GETDMASIZE);
		printf("dmasize: %i (0x%x -- %g MB)\n", ret, ret,
		       ret / (double)(1024*1024));
		ret = 0;
	} else if (argc > 1 && !strcmp(argv[1], "getplist")) {
		ret = do_getplist(fd);
	} else if (argc == 3 || argc == 4) {
		ret = do_iocmd(fd, argv[1], argv[2], argv[3] /* may be NULL */);
	} else if (argc > 4) {
		ret = -EINVAL;
	}

	/* subroutines return "invalid argument" to ask for help */
	if (ret == -EINVAL)
		help();
	if (ret) {
		fprintf(stderr, "%s: command returned \"%s\"\n", prgname,
			strerror(errno));
		exit(1);
	}

	return 0;
}
