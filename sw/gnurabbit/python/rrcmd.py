#!   /usr/bin/env   python
#    coding: utf8

import rr
import cmd

class RrCmd(cmd.Cmd):

    def preloop(self):
        print 'Initializing...'
        self.gennum = rr.Gennum()
        self.do_info('')
        self.prompt = 'rr> '

    def do_info(self, args):
        print 'bound to ' , self.gennum.info()

    def do_bind(self, args):
        self.gennum.bind(args)
        print 'bound to ' , self.gennum.info()

    def do_irqwait(self, args):
        self.gennum.irqwait()

    def do_read(self, args):
        try:
            size, bar, offset = args.split()
            size = int(size)
            bar  = int(bar)
            offset = int(offset, 16)
        except ValueError:
            print "syntax: read size bar address"
            return
        print hex(self.gennum.read(bar, offset, size))

    def do_write(self, args):
        try:
            size, bar, offset, datum = args.split()
            size = int(size)
            bar  = int(bar)
            offset = int(offset, 16)
            datum = int(datum, 16)
        except ValueError:
            print "syntax: write size bar address datum"
            return
        self.gennum.write(bar, offset, size, datum)

    def do_irqena(self, args):
        self.gennum.irqena()

    def do_getdmasize(self, args):
        print hex(self.gennum.getdmasize())

    def do_getplist(self, args):
        plist = self.gennum.getplist()
        width = 8
        for i, addr in enumerate(plist):
            if i % width == 0:
                print '%08x ' % i,
            addr <<= 12
            print '%08x ' % addr,
            if i % width == width-1:
                print
        else:
            if i % width != width-1:
                print

    def emptyline(self):
        pass

    def do_EOF(self, args):
        return True
    do_quit = do_exit = do_EOF

if __name__ == '__main__':
    gennum = rr.Gennum()
    cmd = RrCmd()
    cmd.cmdloop()

