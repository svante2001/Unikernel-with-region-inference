#include <console.h>
#include <netfront.h>
#include <mini-os/os.h>
#include <mini-os/hypervisor.h>
#include <mini-os/mm.h>
#include <mini-os/events.h>
#include <mini-os/time.h>
#include <mini-os/types.h>
#include <mini-os/lib.h>
#include <mini-os/sched.h>
#include <mini-os/xenbus.h>
#include <mini-os/gnttab.h>
#include <mini-os/netfront.h>
#include <mini-os/blkfront.h>
#include <mini-os/fbfront.h>
#include <mini-os/pcifront.h>
#include <mini-os/xmalloc.h>
#include <fcntl.h>
#include <xen/features.h>
#include <xen/version.h>
#include <xen/io/xs_wire.h>
#include <String.h>
#include <List.h>
#include <Math.h>

String REG_POLY_FUN_HDR(my_convertStringToML, Region rAddr, const char *cStr, int len) {  
    String res;
    char *p;

    res = allocStringC(rAddr, len);
    
    for (p = res->data; len > 0;) {
        *p++ = *cStr++;
        len--;
    }

    *p = '\0';
    
    return res;
}

static struct netfront_dev *net_dev = NULL;
static struct semaphore net_sem = __SEMAPHORE_INITIALIZER(net_sem, 0);

#define QUEUE_SIZE 1000

unsigned char * dataPtrs[QUEUE_SIZE];
int dataLengths[QUEUE_SIZE];

int writePos = 1;
int readPos = 0;

static void netfront_thread(void *p) {
    net_dev = init_netfront(NULL, NULL, NULL, NULL);
    up(&net_sem);
}

int extern main(int argc, char ** argv);

static void sml_thread(void *p) {
    down(&net_sem);
    up(&net_sem);

    char * minios[2] = {"mini-os", NULL};
    main(1, minios);
}


void netif_rx(unsigned char* data, int len, void *arg) {
    int newWritePos = (writePos + 1) % QUEUE_SIZE;
    dataPtrs[writePos] = data;
    dataLengths[writePos] = len;
    writePos = newWritePos;
}

int app_main(void *p) {
    create_thread("netfront", netfront_thread, p);
    create_thread("sml", sml_thread, p);
    return 0;
}

String Receive(int addr, Region str_r, Context ctx) {
    int newReadPos = (readPos + 1) % QUEUE_SIZE;
    while (newReadPos == writePos);

    readPos = newReadPos;

    unsigned char * pktptr = dataPtrs[newReadPos];
    int pktlen = dataLengths[newReadPos];
    
    return my_convertStringToML(str_r, (char *)pktptr, pktlen);;
}

void Send(uintptr_t byte_list) {
    down(&net_sem);
    unsigned char toWrite_buf[1518];

    uintptr_t ys;
    int i = 0;
    for (ys = byte_list; isCONS(ys); ys=tl(ys)) {
        toWrite_buf[i++] = convertIntToC(hd(ys));
    }

    netfront_xmit(net_dev, toWrite_buf, i);
    up(&net_sem);
}