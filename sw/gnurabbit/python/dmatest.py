#!   /usr/bin/env	python
#    coding: utf8

import sys
import rr

if __name__ == '__main__':

    # bind to the Gennum kit
    card = rr.Gennum()

    # Find the physical addresses of the three first pages of the buffer
    pages = card.getplist()         # get page list
    pages = pages[:3]               # list slicing: get only 0, 1, 2 page
    pages = [ addr << 12 for addr in pages ]    # shift by 12 bit


    # Change local bus frequency to 100MHz
    print 'Set local bus freq to 100MHz'
    card.iwrite(4, 0x0808, 4, 0xe001f07c)

    # Gennum config for interrupt generation from GPIO
    card.iwrite(4, 0x0A04, 4, 0x00000100) # set GPIO8 as input
    card.iwrite(4, 0x0A1C, 4, 0x0000FEFF) # set GPIO interrupt mask
    card.iwrite(4, 0x0A18, 4, 0x00000100) # set GPIO interrupt mask
    card.iwrite(4, 0x0A28, 4, 0x00000100) # set GPIO8 polarity to rising edge
    card.iwrite(4, 0x0820, 4, 0x00008000) # enable GPIO interrupt on INT0 line

    # Get pages 0-2 addresses
    address0 = pages[0]
    address1 = pages[1]
    address2 = pages[2]

    # Write the next item of the DMA chain in the first page (page 0)
    carrier_start1 = 0x0                        # Start address in the carrier
    card.iwrite(0xc, 0x0000, 4, carrier_start1)	# Start address in the carrier
    card.iwrite(0xc, 0x0004, 4, address2)	# Start address (low) in the host
    card.iwrite(0xc, 0x0008, 4, 0x00000000)	# Start address (high) in the host
    card.iwrite(0xc, 0x000c, 4, 0x40)	        # Length
    card.iwrite(0xc, 0x0010, 4, 0x00000000)	# Address (low) of the next item in the host
    card.iwrite(0xc, 0x0014, 4, 0x00000000)	# Address (high) of the next item in the host
    card.iwrite(0xc, 0x0018, 4, 0x00000000)	# Control of the DMA chain

    # Write data to be catched by DMA engine in the second page (page 1)
    wdata = 0xdead0000
    for addr in xrange(0,16,1):
        card.iwrite(0xc, 0x1000 + (addr << 2), 4, wdata)
        wdata += 0x1

    # Configure the first transfer in the DMA controller
    card.iwrite(0, 0x0008, 4, carrier_start1)	# Start address in the carrier
    card.iwrite(0, 0x000c, 4, address1)	        # Start address (low) in the host
    card.iwrite(0, 0x0014, 4, 0x40)	        # Length
    card.iwrite(0, 0x0018, 4, address0)	        # Address (low) of the next item in the host
    card.iwrite(0, 0x0020, 4, 0x3)	        # Control of the DMA chain

    # Enable interrupts in the driver
    print 'Enable interrupts'
    card.irqena()

    # Start the DMA transfer
    print 'Starting transfer'
    card.iwrite(0, 0x0, 4, 1)

    print 'Wait for end DMA interrupt'
    card.irqwait()
    print 'INTERRUPT RECEIVED'

    # Read GN4142 interrupt status registers to clear interrupt
    print 'INT status  : %.8X' % card.iread(4, 0x814, 4)
    print 'GPIO status : %.8X' % card.iread(4, 0xA20, 4)

    # Prints the three pages
    print 'Page 0 - Next transfer - ' + hex(address0)
    for num in xrange(0, 24, 4):
        print '%.8X' % card.iread(0xc, num, 4)

    print 'Page 1 - Data to write to the board - ' + hex(address1)
    for num in xrange(0, 64, 4):
        print '%.8X' % card.iread(0Xc, 0x1000 + num, 4)

    print 'Page 2 - Data read back from the board - ' + hex(address2)
    for num in xrange(0, 64, 4):
        print '%.8X' % card.iread(0Xc, 0x2000 + num, 4)
