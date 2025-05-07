#include <asm/io.h>
#include <asm/system.h>

/* 这些显示器参数由setup模块准备好放在0x90000地址处,这里获取配置 */
#define ORIG_X              (*(unsigned char *)0x90000)
#define ORIG_Y              (*(unsigned char *)0x90001)
#define ORIG_VIDEO_PAGE     (*(unsigned short *) 0x90004)
#define ORIG_VIDEO_MODE     ((*(unsigned short *)0x90006) & 0xff)
#define ORIG_VIDEO_COLS     (((*(unsigned short *)0x90006) & 0xff00) >>8)
#define ORIG_VIDEO_LINES    ((*(unsigned short *)0x9000e) & 0xff)
#define ORIG_VIDEO_EGA_AX   (*(unsigned short *) 0x90008)   //视频模式编号（BIOS INT 0x10 的返回值）
#define ORIG_VIDEO_EGA_BX   (*(unsigned short *)0x9000a)    //显存起始页框号（video page start）
#define ORIG_VIDEO_EGA_CX   (*(unsigned short *)0x9000c)    //屏幕列数（columns, e.g., 80 for VGA）
#define VIDEO_TYPE_MDA      0x10    //MDA（Monochrome Display Adapter）
#define VIDEO_TYPE_CGA      0x11    //CGA（Color Graphics Adapter）
#define VIDEO_TYPE_EGAM     0x20    //EGA（Enhanced Graphics Adapter）– 单色模式
#define VIDEO_TYPE_EGAC     0x21    //EGA/VGA 彩色模式(文本模式下显存地址通常是 0xB8000 或 0xC0000)

#define NPAR 16

static unsigned char    video_type;     /* Type of display being used   */
static unsigned long    video_num_columns;  /* Number of text columns   */
static unsigned long    video_num_lines;    /* Number of test lines     */
static unsigned long    video_mem_start;     /* Base of video memory     */
static unsigned long    video_mem_term;     /* End of video memory      */
static unsigned long    video_size_row;     /* Bytes per row        */
static unsigned char    video_page;     /* Initial video page       */
static unsigned short   video_port_reg;     /* Video register select port   */
static unsigned short   video_port_val;     /* Video register value port    */
static unsigned short   video_erase_char;

static unsigned long    origin;
static unsigned long    scr_end;
static unsigned long    pos;
static unsigned long    x, y;
static unsigned long    top, bottom;
static unsigned long    npar, par[NPAR];
static unsigned long    ques = 0;
static unsigned long    attr = 0x07;

#define RESPONSE "\033[?1;2c"

static inline void gotoxy(int new_x, unsigned int new_y)
{
    if (new_x > video_num_columns || new_y >= video_num_lines)
        return;

    x = new_x;
    y = new_y;
    pos = origin + y*video_size_row + (x << 1);
}

static inline void set_origin() {
    cli();
    outb_p(12, video_port_reg);
    outb_p(0xff & ((origin - video_mem_start) >> 9), video_port_val);
    outb_p(13, video_port_reg);
    outb_p(0xff & ((origin - video_mem_start) >> 1), video_port_val);
    sti();
}

static inline void set_cursor()
{
    cli();
    outb_p(14, video_port_reg);
    outb_p(0xff&((pos-video_mem_start)>>9), video_port_val);
    outb_p(15, video_port_reg);
    outb_p(0xff&((pos-video_mem_start)>>1), video_port_val);
    sti();
}

#if 0
static void respond(struct tty_struct * tty) {
    char * p = RESPONSE;

    cli();
    while (*p) {
        PUTCH(*p,tty->read_q);
        p++;
    }
    sti();
    copy_to_cooked(tty);
}
#endif

static void scrdown() {
    if (bottom <= top)
        return;

    __asm__("std\n\t"
            "rep\n\t"
            "movsl\n\t"
            "addl $2,%%edi\n\t"
            "movl video_num_columns,%%ecx\n\t"
            "rep\n\t"
            "stosw"
            ::"a" (video_erase_char),
            "c" ((bottom-top-1)*video_num_columns>>1),
            "D" (origin+video_size_row*bottom-4),
            "S" (origin+video_size_row*(bottom-1)-4):);
}

static void ri() {
    if (y>top) {
        y--;
        pos -= video_size_row;
        return;
    }
    scrdown();
}

static void scrup() {
    if (video_type == VIDEO_TYPE_EGAC || video_type == VIDEO_TYPE_EGAM) {
        if (!top && bottom == video_num_lines) {
            origin += video_size_row;
            pos += video_size_row;
            scr_end += video_size_row;

            if (scr_end > video_mem_term) {
                __asm__("cld\n\t"
                        "rep\n\t"
                        "movsl\n\t"
                        "movl video_num_columns,%1\n\t"
                        "rep\n\t"
                        "stosw"
                        ::"a" (video_erase_char),
                        "c" ((video_num_lines-1)*video_num_columns>>1),
                        "D" (video_mem_start),
                        "S" (origin):);
                scr_end -= origin-video_mem_start;
                pos -= origin-video_mem_start;
                origin = video_mem_start;
            }
            else {
                 __asm__("cld\n\t"
                         "rep\n\t"
                         "stosw"
                         ::"a" (video_erase_char),
                         "c" (video_num_columns),
                         "D" (scr_end-video_size_row):);
            }
            set_origin();
        }
        else {
            __asm__("cld\n\t"
                    "rep\n\t"
                    "movsl\n\t"
                    "movl video_num_columns,%%ecx\n\t"
                    "rep\n\t"
                    "stosw"
                    ::"a" (video_erase_char),
                    "c" ((bottom-top-1)*video_num_columns>>1),
                    "D" (origin+video_size_row*top),
                    "S" (origin+video_size_row*(top+1)):);
        }
    }
    else {
        __asm__("cld\n\t"
                "rep\n\t"
                "movsl\n\t"
                "movl video_num_columns,%%ecx\n\t"
                "rep\n\t"
                "stosw"
                ::"a" (video_erase_char),
                "c" ((bottom-top-1)*video_num_columns>>1),
                "D" (origin+video_size_row*top),
                "S" (origin+video_size_row*(top+1)):);
    }
}

void lf() {
    if (y + 1 < bottom) {
        y++;
        pos += video_size_row;
        return;
    }
    scrup();
}

static void cr() {
    pos -= x << 1;
    x = 0;
}

static void del() {
    if (x) {
        pos -= 2;
        x--;
        *(unsigned short*)pos = video_erase_char;
    }
}

static void csi_J(int vpar) {
    long count, start;

    switch (vpar) {
        case 0:
            count = (scr_end-pos)>>1;
            start = pos;
            break;
        case 1:
            count = (pos-origin)>>1;
            start = origin;
            break;
        case 2:
            count = video_num_columns * video_num_lines;
            start = origin;
            break;
        default:
            return;
    }

    __asm__("cld\n\t"
            "rep\n\t"
            "stosw\n\t"
            ::"c" (count),
            "D" (start),"a" (video_erase_char)
            :);
}

static void csi_K(int vpar) {
    long count, start;

    switch (vpar) {
        case 0:
            if (x>=video_num_columns)
                return;
            count = video_num_columns-x;
            start = pos;
            break;
        case 1:
            start = pos - (x<<1);
            count = (x<video_num_columns)?x:video_num_columns;
            break;
        case 2:
            start = pos - (x<<1);
            count = video_num_columns;
            break;
        default:
            return;
    }

    __asm__("cld\n\t"
            "rep\n\t"
            "stosw\n\t"
            ::"c" (count),
            "D" (start),"a" (video_erase_char)
            :);
}

void csi_m() {
    int i;
    for (i=0;i<=npar;i++) {
        switch (par[i]) {
            case 0: attr= 0x07; break;
            case 1: attr= 0x0f; break;
            case 4: attr = 0x0f; break;
            case 7: attr = 0x70; break;
            case 27: attr = 0x07; break;
        }
    }
}

static void delete_char() {
    int i;
    unsigned short * p = (unsigned short *) pos;
    if (x>=video_num_columns)
        return;
    i = x;
    while (++i < video_num_columns) {
        *p = *(p+1);
        p++;
    }
    *p = video_erase_char;
}

static void delete_line() {
    int oldtop,oldbottom;

    oldtop = top;
    oldbottom = bottom;
    top = y;
    bottom = video_num_lines;
    scrup();
    top = oldtop;
    bottom = oldbottom;
}

static void insert_char() {
    int i=x;
    unsigned short tmp, old = video_erase_char;
    unsigned short * p = (unsigned short *) pos;

    while (i++<video_num_columns) {
        tmp=*p;
        *p=old;
        old=tmp;
        p++;
    }
}

static void insert_line() {
    int oldtop,oldbottom;

    oldtop = top;
    oldbottom = bottom;
    top = y;
    bottom = video_num_lines;
    scrdown();
    top = oldtop;
    bottom = oldbottom;
}

static void csi_at(unsigned int nr) {
    if (nr > video_num_columns)
        nr = video_num_columns;
    else if (!nr)
        nr = 1;
    while (nr--)
        insert_char();
}

static void csi_L(unsigned int nr) {
    if (nr > video_num_lines)
        nr = video_num_lines;
    else if (!nr)
        nr = 1;
    while (nr--)
        insert_line();
}

static void csi_P(unsigned int nr) {
    if (nr > video_num_columns)
        nr = video_num_columns;
    else if (!nr)
        nr = 1;
    while (nr--)
        delete_char();
}

static void csi_M(unsigned int nr) {
    if (nr > video_num_lines)
        nr = video_num_lines;
    else if (!nr)
        nr=1;
    while (nr--)
        delete_line();
}

static int saved_x = 0;
static int saved_y = 0;

static void save_cur() {
    saved_x=x;
    saved_y=y;
}

static void restore_cur() {
    gotoxy(saved_x, saved_y);
}

void console_print(const char *buf,int nr)
{
    const char *s=buf;

    while(nr--) {
        char c= *s++;
        if(c>31 && c<127){
            if (x >= video_num_columns) {
                x -= video_num_columns;
                pos -= video_size_row;
                lf();
            }

            *(char *) pos=c;
            *(((char *)pos)+1)=attr;
            pos+=2;
            x++;
        } else if (c == 10 || c == 11 || c == 12)
            lf();
        else if (c == 13)
            cr();
        else if (c == 127)
            del();
        else if (c == 8) {
            if (x) {
                x--;
                pos -= 2;
            }
        }
    }

    gotoxy(x, y);
    set_cursor();
}

void con_init(void)
{
    char *display_desc="????";
    char *display_ptr;
    video_num_columns = ORIG_VIDEO_COLS;
    video_size_row = video_num_columns * 2;
    video_num_lines = ORIG_VIDEO_LINES;
    video_page = ORIG_VIDEO_PAGE;

    /* 这是一个单色显示器吗？*/
    if (ORIG_VIDEO_MODE == 7) {
        //部分代码略
    } else {/* color display */
        /* 显存基地址 */
        video_mem_start = 0xb8000;
        /* 显示器控制端口地址 */
        video_port_reg = 0x3d4;
        video_port_val = 0x3d5;

        if ((ORIG_VIDEO_EGA_BX & 0xff) != VIDEO_TYPE_MDA) {
            video_type = VIDEO_TYPE_EGAC;
            video_mem_term = 0xc0000;
            display_desc = "EGAc";
        } else {
            //部分代码略
        }
    }

    /* 打印display_desc string  */
    display_ptr=((char *)video_mem_start) + video_size_row - 8;
    while (*display_desc) {
        *display_ptr++ = *display_desc++;
        display_ptr++;
    }

    origin = video_mem_start;
    scr_end = video_mem_start + video_num_lines * video_size_row;
    top = 0;
    bottom  = video_num_lines;

    gotoxy(ORIG_X, ORIG_Y);
    set_cursor();
    console_print("\r\nhello\r\nldeng", 14);
}

