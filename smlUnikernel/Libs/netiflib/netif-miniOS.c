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
    res = REG_POLY_CALL(allocStringC, rAddr, len);
    for (p = res->data; len > 0;) {
        *p++ = *cStr++;
        len--;
    }
    *p = '\0';
    return res;
}

static struct netfront_dev *net_dev = NULL;
// static struct semaphore net_sem = __SEMAPHORE_INITIALIZER(net_sem, 0);

static void netfront_thread(void *p) {
    net_dev = init_netfront(NULL, NULL, NULL, NULL);
    // up(&net_sem);
}

int extern main(int argc, char ** argv);

unsigned char * gdata = NULL;

int glen = 0;

static void sml_thread(void *p) {
    // down(&net_sem);
    // up(&net_sem);

    char * minios[2] = {"mini-os", NULL};
    main(1, minios);
}


void netif_rx(unsigned char* data, int len, void *arg) {
    gdata = data;
    glen = len;
}

int app_main(void *p) {
    create_thread("netfront", netfront_thread, p);
    create_thread("sml", sml_thread, p);
    return 0;
}

String read_tap(int addr, Region str_r, Context ctx) {
    while (gdata == NULL);

    char buf[1518]; // MTU + 18 (the 18 bytes are header and frame check sequence)
    for (int i = 0; i < glen; i++) {
        buf[i] = gdata[i];
    }

    // Null-terminate the buffer
    buf[glen] = '\0';

    gdata = NULL;
    glen = 0;

    return my_convertStringToML(str_r, buf, glen);
}

void write_tap(uintptr_t byte_list) {
    unsigned char toWrite_buf[1518];

    uintptr_t ys;
    int i = 0;
    for (ys = byte_list; isCONS(ys); ys=tl(ys)) {
        toWrite_buf[i++] = convertIntToC(hd(ys));
    }
    
    netfront_xmit(net_dev, toWrite_buf, i);
}