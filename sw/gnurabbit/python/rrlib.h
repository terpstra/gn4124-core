
#include <rawrabbit.h>

int rr_devsel(int fd, struct rr_devsel *ds);
int rr_devget(int fd, struct rr_devsel *ds);
int rr_read(int fd, struct rr_iocmd *iocmd);
int rr_write(int fd, struct rr_iocmd *iocmd);
int rr_irqwait(int fd);
int rr_irqena(int fd);
