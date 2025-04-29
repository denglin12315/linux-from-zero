SYSSIZE = 0x3000
SETUPLEN = 4
BOOTSEG = 0x7c0
INITSEG = 0x9000
SETUPSEG = 0x9020
SYSSEG = 0x1000
ENDSEG = SYSSEG + SYSSIZE
ROOT_DEV = 0x0000

.code16
.text

.global _start

# the entry of bootsect
_start:
    jmpl $BOOTSEG, $start2

# move bootsect itself from 0x7c00 to 0x90000
start2:
    movw $BOOTSEG, %ax  # src
    movw %ax, %ds
    movw $INITSEG, %ax  # dest
    movw %ax, %es
    movw $256,%cx       # size
    subw %si, %si       # clr %si
    subw %di, %di       # clr %di

    rep                 # repeat exec the next inst until %cx is 0
    movsw               # mov dword, [ds:si] -> [es:di]

# goto 0x90000
    jmpl $INITSEG, $go
go:
    # set seg selector and sp
    movw %cs, %ax       # 0x9000
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %ss
    movw $0xFF00, %sp   # stack 0x9000:0xff00

# load setup behind the bootsect
#      bootsect    setup
# 0x90000    0x90200    0x90a00
#      1 secotr    4 sector
#
load_setup:
    movw $0x0000, %dx   # dl=0 means the first floppy or harddisk
    movw $0x0002, %cx   # ch=0 means sylinder num, cl=2 means the 2st sector
    movw $0x0200, %bx   # read 2st sector data to [es:bx] -> [0x9000:0x200]
    # read floppy or harddisk
    movb $SETUPLEN, %al # the num of sectors(4)
    movb $0x02, %ah     # int func 0x2 -> read sector
    int $0x13
    # read ok(CF=0), jump to...
    jnc ok_load_setup
    # fail, reset floppy or harddisk
    movw $0x0000, %dx
    movw $0x0000, %ax
    int $0x13
    jmp load_setup      # read again because fail

ok_load_setup:
	movb $0x00, %dl
	movw $0x0800, %ax
	int  $0x13          # get disk parms ah=0x8
	movb $0x00, %ch
	movw %cx, %cs:sectors # 得到每磁道的扇区数（从CX寄存器低字节中取得）, 并将其保存在变量sectors中

    # read linux kernel(SYSSEG)
	movw $SYSSEG, %ax
	movw %ax, %es
	call read_it    
	call kill_motor

    # check root is predefined 
	movw %cs:root_dev, %ax
	cmpw $0, %ax            # judge if root_dev == 0
	jne  root_defined
    #
    # 比较当前B floppy disk, 每磁道扇区数是否为15. 如果是，则说明是1.2MB的5.25寸软盘
    # the extra infomation
    # Linux 0.11 在开发和测试时，常使用两张软盘：A: 启动盘（boot+setup+system），B: 根文件系统。
	movw %cs:sectors, %bx   # 得到每磁道的扇区数
	movw $0x0208, %ax       # 高字节 $02：软盘驱动器号（0x02 表示第二个软驱，B 盘）/ 低字节 $08：扇区号（此值不是关键，下一行会覆盖）
	cmpw $15, %bx
	je   root_defined
    
    # # 比较当前B floppy disk, 每磁道扇区数是否为18. 如果是，则说明是1.44MB的3.5寸软盘
	movw $0x021c, %ax
	cmpw $18, %bx
	je   root_defined
undef_root:
	jmp  undef_root
root_defined:
	mov  %ax, %cs:root_dev      # write dev num(0x0208 or 0x021c) to root_dev, ROOT_DEV
                                # 是setup阶段最终写入的变量，用于告诉内核
                                # "根文件系统所在的设备"。这个值会被保存在内核数据段中，在内核初始化时读取。

	movw %cs, %ax
	movw %ax, %ds
	movw %ax, %es
	
	movw $0x600, %ax        # AH=0x06 (Scroll Window Up), AL=0x00 (scroll 0 行，相当于不滚动)
	movw $0x700, %bx        # BH=0x07 (属性字节：灰底白字)
	movw $0x0,   %cx        # CH=0x00, CL=0x00 → 窗口左上角坐标 (row=0, col=0)
	movw $0x184f,%dx        # DH=0x18 (24), DL=0x4F (79) → 窗口右下角坐标 (row=24, col=79)
	int  $0x10
	
    # print "Linux is booting..."
	movw $msg, %ax
	movw %ax, %bp
	movw $0x01301, %ax
	movw $0x0c, %bx
	movw $23, %cx
	movw $0, %dx
	int  $0x010

    # jump to setup.S to exec
	jmpl $SETUPSEG, $0

sread:
	.word 1+SETUPLEN        # +1 means bootsect(means which sector already read)
head:
	.word 0
track:
	.word 0

# read linux kernel image
read_it:
	movw %es, %ax           #the val of es is 0x1000, so low 12 bits is 0
	testw $0x0fff, %ax
die:
	jne die                 # so , not jump to die here
	xor %bx, %bx
rp_read:
	movw %es, %ax           # start 0x1000
	cmpw $ENDSEG, %ax       # end 0x4000
	jb   ok1_read           # jump when lower than
	ret
/*
 * 这几行是想知道：如果再把current track所有剩余扇区都读进来，是否会超过一个段（64KB）？
 */
ok1_read:
	movw %cs:sectors, %ax   # 读取总扇区数
	subw sread, %ax         # this track 还剩多少扇区没读(minus occupied by setup and bootsect)
	movw %ax, %cx
	shlw $9,  %cx           # 转换为字节数（每扇区512字节 = 2^9）
	addw %bx, %cx           # 加上段内偏移(bx is 0), 如果 addw %bx, %cx 产生进位（即 CX 溢出了 16 位），说明 再读这些数据会超出段限（64KB）
	jnc  ok2_read           # current segment can load left sector, jmp
	je   ok2_read           # just read all left sector when segment is full, jmp
    # 计算还剩多少字节空间（段剩余空间 = 64KB - 已使用偏移）, 
    # 然后除以 512，换算成能读取的扇区数, AX 中就是这一次最多能读取的扇区数
	xorw %ax, %ax
	subw %bx, %ax           # 0 - %bx  （在 16 位寄存器里，这样减就自然等于 65536 - %bx）
	shrw $9,  %ax
ok2_read:
	call read_track
	movw %ax, %cx           # update sectors already readed
	addw sread, %ax
	cmpw %cs:sectors, %ax   # 判断是否已经读完本磁道所有扇区
	jne  ok3_read           # 如果还没读完这一磁道的扇区，跳到ok3_read
    # 读完一个磁道的所有扇区后，准备换头或换道
    # 一个软盘或硬盘通常有两个磁头（head），分别用于读取磁盘的上下两个表面
    /*
     * if (head != 1)
     *      head = 1;
     * else
     *      track += 1;  // 换磁道
     *      head = 0;
     * 
     * 当前 head 不是 1（即 head 是 0）
     *  → 意味着刚刚读完了 head 0（第一个盘面）上的数据
     *  → 那么，接下来切换到 head 1（第二个盘面）

     *  当前 head 是 1
     *  → 刚刚读完了 head 1（第二个盘面）上的数据
     *  → 那么，说明两个盘面都读完了，应该进入下一个 track（柱面） → 然后回到 head 0（第一个盘面）
     *  这是一种软盘读写交错优化的方式：

     *  每个柱面有两个面：head=0 和 head=1

     *  每次读一个面之后，切到另一个面，而不是立刻换柱面

     *  这样可以减少磁头移动的频率，提高读写效率
     */
	movw $1, %ax
	subw head, %ax
	jne  ok4_read
	incw track
ok4_read:
	movw %ax, head
	xorw %ax, %ax

ok3_read:
	movw %ax, sread             # update sread
	shlw $9,  %cx
	addw %cx, %bx
	jnc  rp_read
    # 如果段满了，切换到下一段
	movw %es, %ax
	addw $0x1000, %ax           # 每读满 64KB（一个段）就把段地址 ES 加一段（0x1000 = 16 段 = 64KB）. 
                                # 同时将偏移 BX = 0，重新从新段的开头开始写入
	movw %ax, %es
	xorw %bx, %bx
	jmp  rp_read

read_track:
	pushw %ax               # AL = 读取的扇区数
	pushw %bx
	pushw %cx
	pushw %dx
	movw  track, %dx        # load current track id, is 0
	movw  sread, %cx        # already readed sector in track 0
	incw  %cx               # so +1 shfit to the 1st wanted sector in track 0
	movb  %dl, %ch          # 构造 %cx：CH（磁道），CL（扇区号）
    # 构造 %dx：DH（磁头号），DL（驱动器号）
	movw  head, %dx
	movb  %dl, %dh
	movb  $0, %dl           # DL = 驱动器号 = 0
	andw  $0x0100, %dx      # 只保留 DX 的第 8 位，用来设置 head 和保留位（最多两个磁头）
	movb  $2, %ah           #  int 0x13, 功能号 2 = 读扇区
	int   $0x13             # >>>>>>>>> 从软盘读取 1 个扇区，到 ES:BX 指向的内存
	jc    bad_rt            # 如果 CF 被置位，表示发生错误，跳到 bad_rt 重试
	popw  %dx
	popw  %cx
	popw  %bx
	popw  %ax
	ret
bad_rt:
    # reset drive
	movw $0x0, %ax
	movw $0x0, %dx
	int  $0x13
	popw %dx
	popw %cx
	popw %bx
	popw %ax
	jmp read_track      # try it again

kill_motor:
	pushw %dx
	movw  $0x3f2, %dx
	movb  $0,  %al
	outb  %al, %dx
	popw  %dx
	ret

sectors:
	.word 0

msg:
.byte 13, 10
.ascii "Linux is booting..."
.byte 13, 10

.org 508
root_dev:
    .word ROOT_DEV
boot_flag:
    .word 0xaa55

