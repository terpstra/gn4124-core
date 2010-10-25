#include <sys/ioctl.h>
#include <errno.h>
#include <stdint.h>
#include <fcntl.h>
#include <rawrabbit.h>
#include <stdio.h>

int rr_devsel(int fd, struct rr_devsel *ds)
{
	if (ioctl(fd, RR_DEVSEL, ds) < 0)
		return -errno;
	return 0;
}

int rr_devget(int fd, struct rr_devsel *ds)
{
	if (ioctl(fd, RR_DEVGET, ds) < 0)
		return -errno;
	return 0;
}

int rr_iread(int fd, struct rr_iocmd *iocmd)
{
	if (ioctl(fd, RR_READ, iocmd) < 0)
		return -errno;
	return 0;
}

int rr_iwrite(int fd, struct rr_iocmd *iocmd)
{
	if (ioctl(fd, RR_WRITE, iocmd) < 0)
		return -errno;
	return 0;
}

int rr_irqwait(int fd)
{
	if (ioctl(fd, RR_IRQWAIT) < 0)
		return -errno;
	return 0;
}

int rr_irqena(int fd)
{
	if (ioctl(fd, RR_IRQENA) < 0)
		return -errno;
	return 0;
}

int rr_getdmasize(int fd)
{
	return ioctl(fd, RR_GETDMASIZE);
}

int rr_getplist(int fd, uintptr_t *plist)
{
	int i, size;

	size = ioctl(fd, RR_GETDMASIZE);
	if (size < 0)
		return -errno;
	i = ioctl(fd, RR_GETPLIST, plist);
	if (i < 0)
		return -errno;
	return 0;
}

int main(int argc, char *argv[])
{
	struct rr_iocmd cmd, *cmdp = &cmd;
	int ret;
	int fd = open("/dev/rawrabbit", O_RDWR);
	printf("fd = %d\n", fd);
	cmdp->address = 0x40000a08;
	cmdp->datasize = 4;
	cmdp->data32 = 0xdeadface;
	cmdp->data32 = 0x00000000;
	ret = rr_iread(fd, cmdp);
	printf("ret = %d, errno = %d\n", ret, errno);
	printf("0x%08x 0x%08x 0x%08x\n", cmdp->address, cmdp->datasize, cmdp->data32);
	return 0;
}

