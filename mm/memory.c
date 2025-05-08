//#include <linux/sched.h>
#include <linux/mm.h>

unsigned long HIGH_MEMORY = 0;

unsigned char mem_map [ PAGING_PAGES ] = {0,};

void mem_init(long start_mem, long end_mem) {
    int i;

    HIGH_MEMORY = end_mem;

    /* 15MB的paging memory(1~4MB对应DMA区域，4~16对应的memory给用户使用)对应的页框管理结构清0 */
    for (i = 0; i < PAGING_PAGES; i++) {
        mem_map[i] = USED;
    }

    i = MAP_NR(start_mem);
    end_mem -= start_mem;
    end_mem >>= 12;

    /* 用户page清0，表示未被使用 */
    while (end_mem--)
        mem_map[i++] = 0;
}
