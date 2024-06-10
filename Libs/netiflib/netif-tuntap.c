#include <sys/types.h>
#include <dirent.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include "String.h"
#include "List.h"
#include "Math.h"
#include <errno.h>
#include <err.h>
#include <arpa/inet.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <sys/types.h>
#include <errno.h>
#include <ifaddrs.h>
#include <assert.h>
#include <linux/if.h>
#include <linux/if_tun.h>

#define MTU 1518

/*
    This function including commens is copied from: 
    https://backreference.org/2010/03/26/tuntap-interface-tutorial/index.html
*/
int tun_alloc(char *dev, int flags) {

  struct ifreq ifr;
  int fd, err;
  char *clonedev = "/dev/net/tun";

  /* Arguments taken by the function:
   *
   * char *dev: the name of an interface (or '\0'). MUST have enough
   *   space to hold the interface name if '\0' is passed
   * int flags: interface flags (eg, IFF_TUN etc.)
   */

   /* open the clone device */
   if( (fd = open(clonedev, O_RDWR)) < 0 ) {
     return fd;
   }

   /* preparation of the struct ifr, of type "struct ifreq" */
   memset(&ifr, 0, sizeof(ifr));

   ifr.ifr_flags = flags;   /* IFF_TUN or IFF_TAP, plus maybe IFF_NO_PI */

   if (*dev) {
     /* if a device name was specified, put it in the structure; otherwise,
      * the kernel will try to allocate the "next" device of the
      * specified type */
     strncpy(ifr.ifr_name, dev, IFNAMSIZ);
   }

   /* try to create the device */
   if( (err = ioctl(fd, TUNSETIFF, (void *) &ifr)) < 0 ) {
     printf("ERROR!");
     close(fd);
     exit(0);
     return err;
   }

   /* if the operation was successful, write back the name of the
   * interface to the variable "dev", so the caller can know
   * it. Note that the caller MUST reserve space in *dev (see calling
   * code below) */
  strcpy(dev, ifr.ifr_name);
  
  /* this is the special file descriptor that the caller will use to talk
   * with the virtual interface */
  return fd;
}

void setup(char *dev) {
    int fd;
    struct ifreq ifr;
    int flags;

    if((fd = socket(PF_INET, SOCK_DGRAM, 0)) == -1)
        printf("setup and running socket");

    strncpy(ifr.ifr_name, dev, IFNAMSIZ);
    ifr.ifr_addr.sa_family = AF_INET;

    if (ioctl(fd, SIOCGIFFLAGS, &ifr) == -1)
        printf("setup and running flags");

    strncpy(ifr.ifr_name, dev, IFNAMSIZ);

    flags = ifr.ifr_flags | (IFF_UP|IFF_RUNNING|IFF_BROADCAST|IFF_MULTICAST);
    if (flags != ifr.ifr_flags) {
        ifr.ifr_flags = flags;
        if (ioctl(fd, SIOCSIFFLAGS, &ifr) == -1)
        printf("set_up_and_running SIOCSIFFLAGS");
    }
}

String REG_POLY_FUN_HDR(toMLString, Region rAddr, const char *cStr, int len) {  
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

int tapfd = -1;
String Receive(int addr, Region str_r, Context ctx) {

    if (tapfd == -1) {
        char tap_name[IFNAMSIZ];

        strcpy(tap_name, "tap0");
        tapfd = tun_alloc(tap_name, IFF_TAP);  /* tap interface */

        if (tapfd == -1) return NULL;

        setup(tap_name);
    }

    char buf[MTU]; // MTU + 18 (the 18 bytes are header and frame check sequence)
    ssize_t bytesRead = read(tapfd, buf, MTU);

    // Null-terminate the buffer
    buf[bytesRead] = '\0';

    return toMLString(str_r, buf+4, bytesRead-4); 
}

void Send(uintptr_t byte_list) {
    char toWrite_buf[MTU] = {0};

    uintptr_t ys;
    int i = 4;
    for (ys = byte_list; isCONS(ys) && i <= MTU; ys=tl(ys)) {
        toWrite_buf[i++] = convertIntToC(hd(ys));
    }

    // Copying ethtype bytes to start of buffer
    toWrite_buf[2] = toWrite_buf[13];
    toWrite_buf[3] = toWrite_buf[14];

    ssize_t bytes_written = write(tapfd, toWrite_buf, i);
}