#!  /usr/bin/env python
#   :vi:ts=4 sw=4 et

from ctypes import *
import os, errno, re, sys, struct

# python 2.4 kludge
if not 'SEEK_SET' in dir(os):
    os.SEEK_SET = 0

# unsigned formats to unpack words
fmt = { 1: 'B', 2: 'H', 4: 'I', 8: 'L' }

# some defaults from rawrabbit.h
RR_DEVSEL_UNUSED    = 0xffff
RR_DEFAULT_VENDOR 	= 0x1a39
RR_DEFAULT_DEVICE 	= 0x0004

RR_BAR_0  	= 0x00000000
RR_BAR_2  	= 0x20000000
RR_BAR_4  	= 0x40000000
RR_BAR_BUF	= 0xc0000000

bar_map = {
    0 : RR_BAR_0,
	2: RR_BAR_2,
	4: RR_BAR_4,
	0xc: RR_BAR_BUF }

# classes to interface with the driver via ctypes

Plist = c_int * 256

class RR_Devsel(Structure):
    _fields_ = [
        ("vendor", 	c_ushort),
        ("device", 	c_ushort),
        ("subvendor", 	c_ushort),
        ("subdevice", 	c_ushort),
        ("bus", 	c_ushort),
        ("devfn", 	c_ushort),
    ]

class RR_U(Union):
    _fields_ = [
        ("data8", 	c_ubyte),
        ("data16", 	c_ushort),
        ("data32", 	c_uint),
        ("data64", 	c_ulonglong),
    ]

class RR_Iocmd(Structure):
    _anonymous_ = [ "data", ]
    _fields_ = [
        ("address",	c_uint),
        ("datasize",	c_uint),
        ("data", 	RR_U),
    ]

class Gennum(object):
    device = '/dev/rawrabbit'
    rrlib = './rrlib.so'

    def __init__(self):
        """get a file descriptor for the Gennum device"""
        self.lib = CDLL(Gennum.rrlib)
        self.fd = os.open(Gennum.device, os.O_RDWR)
        self.errno = 0
        if self.fd < 0:
            self.errno = self.fd

    def iread(self, bar, offset, width):
        """do a read by means of the ioctl interface

            bar = 0, 2, 4 (or c for DMA buffer access
            offset = address within bar
            width = data size (1, 2, 4 or 8 bytes)
        """
        address = bar_map[bar] + offset
        ds = RR_Iocmd(address=address, datasize=width)
        self.errno = self.lib.rr_iread(self.fd, byref(ds))
        return ds.data32

    def read(self, bar, offset, width):
        """do a read by means of lseek+read

            bar = 0, 2, 4 (or c for DMA buffer access
            offset = address within bar
            width = data size (1, 2, 4 or 8 bytes)
        """
        address = bar_map[bar] + offset
        self.errno = os.lseek(self.fd, address, os.SEEK_SET)
        buf = os.read(self.fd, width)
        return struct.unpack(fmt[width], buf)[0]

    def iwrite(self, bar, offset, width, datum):
        """do a write by means of the ioctl interface

            bar = 0, 2, 4 (or c for DMA buffer access
            offset = address within bar
            width = data size (1, 2, 4 or 8 bytes)
            datum = value to be written
        """
        address = bar_map[bar] + offset
        ds = RR_Iocmd(address=address, datasize=width, data32=datum)
        self.errno = self.lib.rr_iwrite(self.fd, byref(ds))
        return ds.data32

    def write(self, bar, offset, width, datum):
        """do a write by means of lseek+write

            bar = 0, 2, 4 (or c for DMA buffer access
            offset = address within bar
            width = data size (1, 2, 4 or 8 bytes)
            datum = value to be written
        """
        address = bar_map[bar] + offset
        self.errno = os.lseek(self.fd, address, os.SEEK_SET)
        return os.write(self.fd, struct.pack(fmt[width], datum))

    def irqwait(self):
        """wait for an interrupt"""
        return self.lib.rr_irqwait(self.fd);

    def irqena(self):
        """enable the interrupt line"""
        return self.lib.rr_irqena(self.fd);

    def getdmasize(self):
        """return the size of the allocated DMA buffer (in bytes)"""
        return self.lib.rr_getdmasize(self.fd);

    def getplist(self):
        """get a list of pages for DMA access

        The addresses returned, shifted by 12 bits, give the physical
        addresses of the allocated pages
        """
        plist = Plist()
        self.lib.rr_getplist(self.fd, plist);
        return plist

    def info(self):
        """get a string describing the interface the driver is bound to

        The syntax of the string is
            vendor:device/dubvendor:subdevice@bus:devfn
        """
        ds = RR_Devsel()
        self.errno = self.lib.rr_devget(self.fd, byref(ds))
        for key in RR_Devsel._fields_:
            setattr(self, key[0], getattr(ds, key[0], RR_DEVSEL_UNUSED))
        return '%04x:%04x/%04x:%04x@%04x:%04x' % (
                ds.vendor, ds.device,
                ds.subvendor, ds.subdevice,
                ds.bus, ds.devfn)

    def parse_addr(self, addr):
        """take a string of the form
               vendor:device[/subvendor:subdevice][@bus:devfn]
        and return a dictionary object with the corresponding values,
        initialized to RR_DEVSEL_UNUSED when absent
        """
        # address format
        reg = ( r'(?i)^'
                r'(?P<vendor>[a-f0-9]{1,4}):(?P<device>[a-f0-9]{1,4})'
                r'(/(?P<subvendor>[a-f0-9]{1,4}):(?P<subdevice>[a-f0-9]{1,4}))?'
                r'(@(?P<bus>[a-f0-9]{1,4}):(?P<devfn>[a-f0-9]{1,4}))?$' )
        match = re.match(reg, addr).groupdict()
        if not 'sub' in match:
            match['subvendor'] = match['subdevice'] = RR_DEVSEL_UNUSED
        if not 'geo' in match:
            match['bus'] = match['devfn'] = RR_DEVSEL_UNUSED
        for k, v in match.items():
            if type(v) is str:
                match[k] = int(v, 16)
        return match

    def bind(self, device):
        """bind the rawrabbit driver to a device

        The device is specified with a syntax described in parse_addr
        """
        d = self.parse_addr(device)
        ds = RR_Devsel(**d)
        self.errno = self.lib.rr_devsel(self.fd, byref(ds))
        return self.errno

if __name__ == '__main__':
    g = Gennum()
    print g.parse_addr('1a39:0004/1a39:0004@0020:0000')
    print g.bind('1a39:0004/1a39:0004@0020:0000')
    print '%x' % g.write(bar=RR_BAR_4, offset=0xa08, width=4, datum=0xdeadface)
    print '%x' % g.read(bar=RR_BAR_4, offset=0xa08, width=4)
    print g.getdmasize()
    for page in g.getplist():
        print '%08x ' % (page<<12),
