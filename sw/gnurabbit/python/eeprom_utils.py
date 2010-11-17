#!   /usr/bin/env	python
#    coding: utf8

import sys
import rr
import time

if __name__ == '__main__':

    # bind to the Gennum kit
    card = rr.Gennum()

    # Read from I2C
    def i2c_read(gennum, i2c_addr, offset, length, read_data):
        # Shut off EEPROM_INIT state machine if not done so */
        tmp = gennum.iread(4, 0x804, 4)
        #print 'LB_CTL=%.8X' % tmp
        if tmp & 0x10000 == 0:
            tmp |= 0x10000
            #print 'LB_CTL=%.8X' % tmp
            gennum.iwrite(4, 0x804, 4, tmp)
        # Init I2C clock Fpci/(22*Fscl)=(DIV_A+1)*(DIV_B+1)
        # CLR_FIFO=1, SLVMON=0, HOLD=0, ACKEN=1, NEA=1, MS=1, RW=0
        gennum.iwrite(4, 0x900, 4, 0x384E)
        # Read back from register to guarantee the mode change
        tmp = gennum.iread(4, 0x900, 4)
        #print 'TWI_CTRL=%.8X' % tmp
        # Wait until I2C bus is idle
        i=2000000
        while i > 0:
            i-=1
            tmp = gennum.iread(4, 0x904, 4)
            #print 'TWI_STATUS=%.8X' % tmp
            #time.sleep(.5)
            if tmp & 0x100 == 0:
                #print 'I2C bus is idle'
                break
        # Read to clear TWI_IRT_STATUS
        tmp = gennum.iread(4, 0x910, 4)
        #print 'TWI_IRT_STATUS=%.8X (read to clear)' % tmp
        # Write word offset
        tmp=(0xFF & offset)
        gennum.iwrite(4, 0x90C, 4, tmp)
        #print 'Write offset %.8X' % tmp
        # Write device address
        tmp=(0x7F & i2c_addr)
        gennum.iwrite(4, 0x908, 4, tmp)
        #print 'Write I2C slave address %.8X' % tmp
        # Wait for transfer complete status
        i=2000000
        while i > 0:
            tmp = gennum.iread(4, 0x910, 4)
            #print 'TWI_IRT_STATUS=%.8X' % tmp
            #time.sleep(.5)
            if tmp & 0x1:
                #print 'Transfer completed'
                break
            elif tmp & 0xC:
                print 'NACK detected or TIMEOUT, IRT_STATUS = 0x%x!!' % tmp
                sys.exit()
            i-=1
        if i == 0:
            print 'ERROR, completion status not detected!!'
            sys.exit()
        # Change to read mode
        gennum.iwrite(4, 0x900, 4, 0x384F)
        #print 'Change to read mode'
        # Perform sequential page read from the start address
        error_flag=0
        total_transfer=0
        while length > 0 and error_flag == 0:
            # Transfer bigger than I2C fifo (8 bytes) are split
            if length > 8:
                transfer_len = 8
                length -= 8
            else:
                transfer_len = length
                length = 0
            # Update expected receive data size
            gennum.iwrite(4, 0x914, 4, transfer_len)
            #print 'Transfer length=%.3d' % transfer_len
            # Write device address
            gennum.iwrite(4, 0x908, 4, (0x7F & i2c_addr))
            # Wait until transfer is completed
            j=2000000
            while j > 0:
                tmp = gennum.iread(4, 0x910, 4)
                if tmp & 0x1:
                    #print 'Transfer completed'
                    break
                j-=1
            if j == 0:
                error_flag = 1
                print 'ERROR, completion status not detected!!'
            # Read data from fifo
            while transfer_len > 0:
                read_data.append(0xFF & gennum.iread(4, 0x90C, 4))
                #print 'read_data[%.3d]=%.2X' %(total_transfer,read_data[total_transfer])
                transfer_len-=1
                total_transfer+=1
        # End of read
        return total_transfer

    # Write to I2C
    def i2c_write(gennum, i2c_addr, offset, length, write_data):
        # Shut off EEPROM_INIT state machine if not done so */
        tmp = gennum.iread(4, 0x804, 4)
        #print 'LB_CTL=%.8X' % tmp
        if tmp & 0x10000 == 0:
            tmp |= 0x10000
            #print 'LB_CTL=%.8X' % tmp
            gennum.iwrite(4, 0x804, 4, tmp)
        # Read to clear TWI_IRT_STATUS
        gennum.iread(4, 0x910, 4)
        # Read to clear TWI_STATUS
        gennum.iread(4, 0x904, 4)
        # Init I2C clock Fpci/(22*Fscl)=(DIV_A+1)*(DIV_B+1)
        # CLR_FIFO=1, SLVMON=0, HOLD=0, ACKEN=1, NEA=1, MS=1, RW=0
        gennum.iwrite(4, 0x900, 4, 0x384E)
        # Read back from register to guarantee the mode change
        gennum.iread(4, 0x900, 4)
        # Wait until I2C bus is idle
        i=2000000
        while i > 0:
            i-=1
            tmp = gennum.iread(4, 0x904, 4)
            if tmp & 0x100 == 0:
                break
        # Perform sequential page write from the start address
        error_flag=0
        total_transfer=0
        while length > 0 and error_flag == 0:
            # Write word offset
            gennum.iwrite(4, 0x90C, 4, (0xFF & offset))
            #print 'Offset=%.2X' % offset
            i=6 # fifo size - 2
            while i > 0 and length > 0:
                tmp = (0xFF & write_data[total_transfer])
                #print 'data=%.2X' % tmp
                gennum.iwrite(4, 0x90C, 4, tmp)
                total_transfer+=1
                offset+=1
                i-=1
                length-=1
                #print 'total_transfer=%d, offset=%d, i=%d, length=%d' %(total_transfer,offset,i,length)
                # Reaches the page write address boundary, thus need to start
                # the offset at the next page (page size = 8)
                if offset & 7 == 0:
                    #print 'page boundary reached!'
                    break
            # Write device address
            gennum.iwrite(4, 0x908, 4, (0x7F & i2c_addr))
            #print 'Write I2C address'
            # Wait until transfer is completed
            i=2000000
            while i > 0:
                tmp = gennum.iread(4, 0x910, 4)
                time.sleep(0.01)
                if tmp & 0x1:
                    #print 'Transfer completed!'
                    tmp = gennum.iread(4, 0x914, 4)
                    #print 'TR_SIZE=%d' % tmp
                    break
                elif tmp & 0xC:
                    print 'NACK detected or TIMEOUT, IRT_STATUS = 0x%x!!' % tmp
                    tmp = gennum.iread(4, 0x914, 4)
                    #print 'TR_SIZE=%d' % tmp
                    #print total_transfer
                    return total_transfer
                i-=1
        return total_transfer

    def eeprom_dump_to_screen(gennum):
        eeprom_data=[]
        nb_rec=42
        i2c_read(gennum, 0x56, 0, nb_rec*6, eeprom_data)
        for i in range(0,nb_rec*6,6):
            addr=eeprom_data[i] + (eeprom_data[i+1] << 8)
            data=eeprom_data[i+2] + (eeprom_data[i+3] << 8) + (eeprom_data[i+4] << 16) + (eeprom_data[i+5] << 24)
            if addr == 0xFFFF:
                break
            print '[%.2d]=%.4X %.8X' %(i/6,addr,data)
        print ''
        for i in range(0,len(eeprom_data)):
            print '[%.2d]=%.2X' %(i,eeprom_data[i])
            if eeprom_data[i+1] == 0xFF and eeprom_data[i+2] == 0xFF:
                break
        return 0

    def eeprom_dump_to_file(gennum):
        file_name = raw_input('Enter a file name (default=eeprom.dat) :')
        if file_name == "":
            file_name = "eeprom.dat"
        file = open(file_name, 'w+')
        eeprom_data=[]
        nb_rec=100
        i2c_read(gennum, 0x56, 0, nb_rec*6, eeprom_data)
        for i in range(0,nb_rec*6,6):
            addr=eeprom_data[i] + (eeprom_data[i+1] << 8)
            data=eeprom_data[i+2] + (eeprom_data[i+3] << 8) + (eeprom_data[i+4] << 16) + (eeprom_data[i+5] << 24)
            print >>file,'%.4X %.8X' %(addr,data)
            if addr == 0xFFFF:
                break
        return 0

    def file_dump_to_screen():
        file_name = raw_input('Enter a file name (default=eeprom.dat):')
        if file_name == "":
            file_name = "eeprom.dat"
        file = open(file_name, 'r+')
        file_data=[]
        for line in file:
            addr,data = line.split()
            print addr+' '+data
            for i in range(2,0,-1):
                #print addr[(i-1)*2:(i-1)*2+2]
                file_data.append(int(addr[(i-1)*2:(i-1)*2+2],16))
            for i in range(4,0,-1):
                #print data[(i-1)*2:(i-1)*2+2]
                file_data.append(int(data[(i-1)*2:(i-1)*2+2],16))
        print ''
        for i in range(0,len(file_data)):
            print '[%.2d]=%.2X' %(i,file_data[i])
        return 0

    def file_dump_to_eeprom(gennum):
        file_name = raw_input('Enter a file name (default=eeprom.dat):')
        if file_name == "":
            file_name = "eeprom.dat"
        file = open(file_name, 'r+')
        file_data=[]
        # Read file
        for line in file:
            addr,data = line.split()
            for i in range(2,0,-1):
                #print addr[(i-1)*2:(i-1)*2+2]
                file_data.append(int(addr[(i-1)*2:(i-1)*2+2],16))
            for i in range(4,0,-1):
                #print data[(i-1)*2:(i-1)*2+2]
                file_data.append(int(data[(i-1)*2:(i-1)*2+2],16))
        # Write EEPROM
        confirm = raw_input('Do you really want to write the EEPROM? (Type "Yes" to confirm) :')
        if confirm != "Yes":
            return 1
        #print len(file_data)
        #print file_data
        written = i2c_write(gennum, 0x56, 0, len(file_data), file_data)
        if written == len(file_data):
            print 'EEPROM written with '+file_name+' content!'
        else :
            print 'ERROR!!'
        return 0

    def compare_eeprom_with_file(gennum):
        file_name = raw_input('Enter a file name (default=eeprom.dat):')
        if file_name == "":
            file_name = "eeprom.dat"
        file = open(file_name, 'r+')
        file_data=[]
        eeprom_data=[]
        nb_rec=0
        # Read file
        for line in file:
            addr,data = line.split()
            for i in range(2,0,-1):
                #print addr[(i-1)*2:(i-1)*2+2]
                file_data.append(int(addr[(i-1)*2:(i-1)*2+2],16))
            for i in range(4,0,-1):
                #print data[(i-1)*2:(i-1)*2+2]
                file_data.append(int(data[(i-1)*2:(i-1)*2+2],16))
            nb_rec+=1
        # Read EEPROM
        i2c_read(gennum, 0x56, 0, (nb_rec+1)*6, eeprom_data)
        # Compare
        for i in range(0,len(file_data)):
            if file_data[i] == eeprom_data[i]:
                print 'EEPROM= %.2X, FILE= %.2X => OK' %(eeprom_data[i],file_data[i])
            else :
                print 'EEPROM= %.2X, FILE= %.2X => ERROR' %(eeprom_data[i],file_data[i])

    def display_options():
        print ' '
        print ' '
        print '************************************************************'
        print '* GN4124 EEPROM utility                                    *'
        print '************************************************************'
        print ' '
        print ' Choose one of the following options and type ENTER:'
        print ' '
        print '1 -> Read EEPROM and dump on screen.'
        print '2 -> Read EEPROM and dump to file.'
        print '3 -> Write EEPROM from file.'
        print '4 -> Verify EEPROM content against file.'
        print '5 -> Read file and dump on screen.'
        print '0 -> Exit'
        print ' '

    def bind(input, gennum):
        #print input
        if input == "1":
            eeprom_dump_to_screen(gennum)
            return 0
        if input == "2":
            eeprom_dump_to_file(gennum)
            return 0
        if input == "3":
            file_dump_to_eeprom(gennum)
            return 0
        if input == "4":
            compare_eeprom_with_file(gennum)
            return 0
        if input == "5":
            file_dump_to_screen()
            return 0
        if input == "0":
            print 'Exiting program'
            return 1
        else :
            print 'Unknown option, try again...'
            return 0

    while 1:
        display_options()
        if bind(raw_input(': '),card):
            sys.exit()
            break
