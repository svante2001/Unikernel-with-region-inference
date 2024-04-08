#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
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

int main() {
    char tap_name[IFNAMSIZ];

    strcpy(tap_name, "tap0");
    int tapfd = tun_alloc(tap_name, IFF_TAP);  /* tap interface */
    setup(tap_name);

    char buf[1500];
    while (1) {
        int i = read(tapfd, buf, 1500);
        printf("Thing: %.1500s", buf);
        printf("Read bytes: %d\n", i);
        // write(tapfd, buf, i);

        for (int i = 0; i < 99; i++) {
            printf("%d ", buf[i]);
        }
        printf("\n");
    }

    return 0;
}