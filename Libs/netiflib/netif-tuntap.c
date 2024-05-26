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
#if defined(__FreeBSD__) || defined(__OpenBSD__)
#include <netinet/in.h>
#endif /* __FreeBSD__ */
#include <ifaddrs.h>
#include <assert.h>
#include <linux/if.h>
#include <linux/if_tun.h>

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
  
  /* this is the special file descriptor that the caller will use to talk
   * with the virtual interface */
  return fd;
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
String readTap(int addr, Region str_r, Context ctx) {

    if (tapfd == -1) {
        char tap_name[IFNAMSIZ];

        strcpy(tap_name, "tap0");
        tapfd = tun_alloc(tap_name, IFF_TAP);  /* tap interface */

        if (tapfd == -1) return NULL;
    }

    char buf[1518]; // MTU + 18 (the 18 bytes are header and frame check sequence)
    ssize_t bytesRead = read(tapfd, buf, 1518);

    // Null-terminate the buffer
    buf[bytesRead] = '\0';

    return toMLString(str_r, buf+4, bytesRead-4); // For some reason we get 4 extra bytes we do not use
}

void writeTap(uintptr_t byte_list) {
    char toWrite_buf[1518];
    size_t toWrite_len = 1518;

    toWrite_buf[0] = toWrite_buf[1] = 0;

    uintptr_t ys;
    int i = 4;
    for (ys = byte_list; isCONS(ys) && i <= 1518; ys=tl(ys)) {
        toWrite_buf[i++] = convertIntToC(hd(ys));
    }

    // Copying ethtype bytes to start of buffer
    toWrite_buf[2] = toWrite_buf[13];
    toWrite_buf[3] = toWrite_buf[14];

    ssize_t bytes_written = write(tapfd, toWrite_buf, i);
}