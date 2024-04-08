#include <sys/types.h>
#include <dirent.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include "/home/svante/Documents/mlkit/src/Runtime/String.h"
#include <errno.h>
#include <err.h>
#include <arpa/inet.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <sys/types.h>
#include <sys/socket.h>
#if defined(__FreeBSD__) || defined(__OpenBSD__)
#include <netinet/in.h>
#endif /* __FreeBSD__ */
#include <ifaddrs.h>
#include <assert.h>
#include <linux/if.h>
#include <linux/if_tun.h>

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
    #if defined(__FreeBSD__) || defined(__OpenBSD__)
    ifr.ifr_addr.sa_len = IFNAMSIZ;
    #endif /* __FreeBSD__ */

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

int tapfd = -1;
char* read_tap(int addr, Region str_r, Context ctx) {
    char tap_name[IFNAMSIZ];

    strcpy(tap_name, "tap0");

    if (tapfd == -1) {
        tapfd = tun_alloc(tap_name, IFF_TAP);  /* tap interface */

        if (tapfd == -1) return NULL;

        setup(tap_name);
    }

    char buf[1500];
    ssize_t bytes_read = read(tapfd, buf, 1500);

    // Null-terminate the buffer
    buf[bytes_read] = '\0';

    return my_convertStringToML(str_r, buf, bytes_read);
}

char* read_fd(int addr, String fileName, Region str_r, Context ctx) {
    char file[1024];
    char fileName_buf[100];
    size_t len = 100;
    uintptr_t exn = 10; // No idea what this is supposed to be but this value works.
    convertStringToC(ctx, fileName, fileName_buf, len, exn);
    int fd = open(fileName_buf, O_RDONLY);
    if (fd == -1) {
        return NULL;
    }

    ssize_t bytes_read = read(fd, file, 1024);
    if (bytes_read == -1) {
        close(fd);
        return NULL;
    }

    close(fd);

    // Null-terminate the buffer
    file[bytes_read] = '\0';

    return my_convertStringToML(str_r, file, bytes_read);
}


int write_fd(String fileName, String toWrite, Context ctx) {
    char fileName_buf[100];
    size_t len = 100;
    uintptr_t exn = 10; // No idea what this is supposed to be but this value works.
    convertStringToC(ctx, fileName, fileName_buf, len, exn);

    // Opens write only, creates if the file doesnt exists and truncate to zero if it does exist. 
    // https://medium.com/@joshuaudayagiri/linux-system-calls-write-a9251cd782c8
    int fd = open(fileName_buf, O_WRONLY | O_CREAT | O_TRUNC, 0644);

    if (fd == -1) return 1;

    char toWrite_buf[1024];
    size_t toWrite_len = 1024;
    convertStringToC(ctx, toWrite, toWrite_buf, toWrite_len, exn);
    
    ssize_t bytes_written = write(fd, toWrite_buf, strlen(toWrite_buf));
    if (bytes_written == -1) {
        close(fd);
        return 1;
    }

    close(fd);
    return 0;
}