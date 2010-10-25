#!/bin/bash

# Find the physical addresses of the three first pages of the buffer
address0=`./rrcmd getplist|grep "buf 0x00000000"|sed 's/.*0x00000000//'`
address1=`./rrcmd getplist|grep "buf 0x00001000"|sed 's/.*0x00000000//'`
address2=`./rrcmd getplist|grep "buf 0x00002000"|sed 's/.*0x00000000//'` 

# Change local bus frequency to 100MHz
echo Set local bus freq to 100MHz
./rrcmd w4 4:0808 0xe001f07c;

# Gennum config for interrupt generation from GPIO
./rrcmd w4 4:0A04 0x00000100; # set GPIO8 as input
./rrcmd w4 4:0A1C 0x0000FEFF; # set GPIO interrupt mask
./rrcmd w4 4:0A18 0x00000100; # set GPIO interrupt mask
./rrcmd w4 4:0A28 0x00000100; # set GPIO8 polarity to rising edge
./rrcmd w4 4:0820 0x00008000; # enable GPIO interrupt on INT0 line

# Write the next item of the DMA chain in the first page
./rrcmd w4 c:0000 00000000;      # Start address in the carrier
./rrcmd w4 c:0004 $address2;     # Start address (low) in the host
./rrcmd w4 c:0008 00000000;      # Start address (high) in the host
./rrcmd w4 c:000c 40;            # Length
./rrcmd w4 c:0010 00000000;      # Address (low) of the next item in the host
./rrcmd w4 c:0014 00000000;      # Address (high) of the next item in the host
./rrcmd w4 c:0018 00000000;      # Control of the DMA chain

# Write data to be catched by the DMA engine
for num in $(printf "%.3X\n" `seq 0 4 64`) ; do
 ./rrcmd w4 c:1${num} ${num};
done ;

# Configure the first transfer in the DMA controler
./rrcmd w4 0:0008 00000000;      # Start address in the carrier
./rrcmd w4 0:000c $address1;     # Start address (low) in the host
./rrcmd w4 0:0014 40;            # Length
./rrcmd w4 0:0018 $address0;     # Address (low) of the next item in the host
./rrcmd w4 0:0020 3;             # Control of the DMA chain

# Enable interrupts in the driver
./rrcmd irqena

# Start the DMA transfer
./rrcmd w4 0:0000 1;             # DMA engine control (start the transfer)

# Wait for end of DMA transfer interrupt
echo 'Wait for interrupt'
./rrcmd irqwait
echo 'INTERRUPT RECEIVED'

# Read GN4142 interrupt status registers to clear interrupt
./rrcmd r4 4:814;
./rrcmd r4 4:A20;

# Prints the three pages
echo Page 0 - Next transfer - $address0
for num in $(printf "%.3X\n" `seq 0 4 24`) ; do
 ./rrcmd r4 c:0${num};
done ;

echo Page 1 - Data to write to the board - $address1
for num in $(printf "%.3X\n" `seq 0 4 64`) ; do
 ./rrcmd r4 c:1${num};
done ;

echo Page 2 - Data read back from the board - $address2
for num in $(printf "%.3X\n" `seq 0 4 64`) ; do
 ./rrcmd r4 c:2${num};
done ;
