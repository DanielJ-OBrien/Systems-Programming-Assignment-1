# When the PC starts, the processor is essentially emulating an 8086 processor, i.e. 
# a 16-bit processor.  So our initial boot loader code is 16-bit code that will 
# eventually switch the processor into 32-bit mode.

# This code is linked to assume a starting address of 0x7C00 which is where the BIOS
# will load a boot segment.



.code16                         # Assemble for 16-bit mode
.globl start
start:
    jmp     real_start

# Write to the console using BIOS.
# 
# Input: SI contains the address of the null-terminated string to be displayed

cons_write:
    mov    $0x0e, %ah           # 0x0e is the INT 10h BIOS call to output the value contained in AL to screen

cons_write_rpt:
    movb    (%si), %al          # Load the byte at the location contained in the SI register into AL   
    inc     %si                 # Add 1 to the value in SI
    cmp     $0, %al             # Compare the value in AL with 0
    jz      cons_write_done     # If it is zero, then we are done
    int     $0x10               # Output the character in AL to the screen
    jmp     cons_write_rpt      # and continue

cons_write_done:                # Something that is called will never return 
    ret                         # until a 'ret' instruction is encountered.  Labels do 
                                # not give a program any structure.  They just give a 
                                # memory location a name that we can use in our code. 

cons_write_ascii:
    mov     $0x0e, %ah          # 0x0e is the INT 10h BIOS call to output the value contained in AL to screen
    cmp     $0x20, (%si)
    jl      cons_ascii_empty
    movb    (%si), %al          # Load the byte at the location contained in the SI register into AL   
    int     $0x10               # Output the character in AL to the screen
    ret

cons_ascii_empty:
    mov     $'_', %al
    int     $0x10               # Output the character in AL to the screen
    ret

cons_write_crlf:
    mov     $0x0e, %ah          # Output CR
    movb    $0x0d, %al
    int     $0x10
    movb    $0x0a, %al          # Output LF
    int     $0x10
    ret

cons_writeline:
    call    cons_write
    call    cons_write_crlf
    ret    

HexChars:	.ascii "0123456789ABCDEF"

cons_write_hex_offset:
	movw   $4, %cx
    mov    $0x0E, %ah
    jmp    hexloop

cons_write_hex:
	movw   $2, %cx
    mov    $0x0E, %ah
	
hexloop:
    rol     $4, %bx
    movw    %bx, %si
    and     $0x000F, %si
    movb    HexChars(%si), %al
	int		$0x10
	loop	hexloop
	ret

real_start:
    movb    %dl, (boot_device) # Boot device number is passed in DL from BIOS. Save it hear since DL might get trashed

    movw    $boot_message, %si  # Display our boot message
    call    cons_writeline

diskread_start:
    mov     $0, %ax
    mov     $0, %bx
    mov     $0, %cx
    mov     (boot_device), %dl
    #setting dl to 0 blows up the program,. why?
    movw    $sector_message, %si      # Display our sector request message
    call    cons_writeline

                           # This code reads 4 keyboard inputs for sector selection
    mov     $0x00, %ah                # Converts keyboard input from ascii to actual value 
    int     $0x16
    sub     $0x30, %al     
    imul    $1000, %ax                # Multiplies by 1000 for the 1000 column
    add     %al, %bl 

    mov     $0x00, %ah                # Converts keyboard input from ascii to actual value 
    int     $0x16
    sub     $0x30, %al     
    imul    $100, %ax     
    add     %al, %bl   

    mov     $0x00, %ah                # Converts keyboard input from ascii to actual value 
    int     $0x16
    sub     $0x30, %al     
    imul    $10, %ax     
    add     %al, %bl  

    mov     $0x00, %ah                # Converts keyboard input from ascii to actual value 
    int     $0x16
    sub     $0x30, %al         
    add     %al, %bl  

    movw    $disk_address_packet, %si # Move address of the disk address packet into SI
    movw    $1, 2(%si)                # Set the number of blocks to read to be 1
    movw    $0xD000, 4(%si)           # Set the address to read into to be 0xD000
    mov     %bl, 8(%si)               # Set the first block to read to be block 0
    
    mov     $0x42, %ah                # 0x42 is the int 13h BIOS function to read the disk using LBA addressing
    int     $0x13                     # Read the disk

    mov     $0xCFFF, %si              # Select starting memory address to read from
    mov     $0, %dl              # Sets greaterloop counter to 0

greaterloop:

    push %si

    movzb   %dl, %bx
    imul    $16, %bx
    call    cons_write_hex_offset     # Calls hex offset function
    inc     %dl

    pop %si

    mov     $0, %dh                   # Sets hexreadloop counter to 0
    call	hexreadloop

    push	%dx
    sub     $15, %si                  # Reduces the memory address counted by 16 so that the ascii
    mov     $1, %dx                   # can be iterated through as well

    push    %si
    movw    $space, %si
    call    cons_write
    pop     %si                     # Adds a space


    call    displayascii
    pop     %dx

    call    cons_write_crlf


    cmp    $16, %dl
    je     fullsectorloop
    cmp    $32, %dl
    jl     greaterloop
    je     diskread_start
fullsectorloop:

    push    %si
    movw    $pressanykey, %si
    call    cons_writeline
    pop     %si                     # Displays the press any key line

    push    %ax
    mov     $0x00, %ah
    int     $0x16                   # Waits on key press
    pop     %ax

    jmp     greaterloop

displayascii:

    push    %si
    call    cons_write_ascii
    pop     %si


    inc     %si                     # Increments memory address
    inc     %dl                     # Increments loop counter

    cmp     $16, %dl                # Loops if < 15
    jle     displayascii
    ret

hexreadloop:
    add     $1, %dh

    push %si

    mov (%si), %bx

    movw    $space, %si
    call    cons_write

    call    cons_write_hex # Prints hex values

    pop %si

    inc  %si # increment memory address

    cmp     $15, %dh
    jle     hexreadloop
    ret


# Program data

boot_device:
    .byte   0

disk_address_packet:
    .byte   0x10
    .byte   0
    .word   0
    .long   0
    .long   0
    .long   0

boot_message:     
    .string "Boot Loader Stage 2 loaded"

sector_message:     
    .string "Which sector would you like to read? (4 digits i.e 0001) "     

space:     
    .string " " 

pressanykey:     
    .string "Press a key to continue" 

test_1:
    .string "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

test_2:
    .string "abcdefghijklmnopqrstuvwxyz"

test3:
    .string "!@#$%^&*()+-=[]{}|\;:',.<>/?`~"

test_4:
    .string "0123456789"

