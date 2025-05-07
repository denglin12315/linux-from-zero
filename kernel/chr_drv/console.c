
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

static unsigned char video_type;
static unsigned long video_num_columns;
static unsigned long video_num_lines;
static unsigned long video_mem_base;
static unsigned long video_mem_term;
static unsigned long video_size_row;
static unsigned char video_page;
static unsigned short video_port_reg;
static unsigned short video_port_val;

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
        video_mem_base = 0xb8000;
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
    display_ptr=((char *)video_mem_base) + video_size_row - 8;
    while (*display_desc) {
        *display_ptr++ = *display_desc++;
        display_ptr++;
    }
}

