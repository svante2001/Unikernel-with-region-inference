/*
 * POSIX-compatible libc layer
 *
 * Samuel Thibault <Samuel.Thibault@eu.citrix.net>, October 2007
 *
 * Provides the UNIXish part of the standard libc function.
 *
 * Relatively straight-forward: just multiplex the file descriptor operations
 * among the various file types (console, FS, network, ...)
 */

//#define LIBC_VERBOSE
//#define LIBC_DEBUG

#ifdef LIBC_DEBUG
#define DEBUG(fmt,...) printk(fmt, ##__VA_ARGS__)
#else
#define DEBUG(fmt,...)
#endif

#ifdef HAVE_LIBC
#include <os.h>
#include <export.h>
#include <string.h>
#include <console.h>
#include <sched.h>
#include <events.h>
#include <wait.h>
#include <netfront.h>
#include <blkfront.h>
#include <fbfront.h>
#include <xenbus.h>
#include <xenstore.h>
#include <poll.h>
#include <termios.h>

#include <sys/types.h>
#include <sys/unistd.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <net/if.h>
#include <time.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <assert.h>
#include <dirent.h>
#include <stdlib.h>
#include <math.h>

#ifdef HAVE_LWIP
#include <lwip/sockets.h>
#endif

#define debug(fmt, ...) \

#define print_unsupported(fmt, ...) \
    printk("Unsupported function "fmt" called in Mini-OS kernel\n", ## __VA_ARGS__);

/* Crash on function call */
#define unsupported_function_crash(function) \
    int __unsup_##function(void) asm(#function); \
    int __unsup_##function(void) \
    { \
	print_unsupported(#function); \
	do_exit(); \
    } \
    EXPORT_SYMBOL(function)

/* Log and err out on function call */
#define unsupported_function_log(type, function, ret) \
    type __unsup_##function(void) asm(#function); \
    type __unsup_##function(void) \
    { \
	print_unsupported(#function); \
	errno = ENOSYS; \
	return ret; \
    } \
    EXPORT_SYMBOL(function)

/* Err out on function call */
#define unsupported_function(type, function, ret) \
    type __unsup_##function(void) asm(#function); \
    type __unsup_##function(void) \
    { \
	errno = ENOSYS; \
	return ret; \
    } \
    EXPORT_SYMBOL(function)

#define NOFILE 32
#define N_MOUNTS  16

extern void minios_evtchn_close_fd(int fd);
extern void minios_gnttab_close_fd(int fd);

pthread_mutex_t fd_lock = PTHREAD_MUTEX_INITIALIZER;
static struct file files[NOFILE] = {
    { .type = FTYPE_CONSOLE }, /* stdin */
    { .type = FTYPE_CONSOLE }, /* stdout */
    { .type = FTYPE_CONSOLE }, /* stderr */
};

static const struct file_ops file_ops_none = {
    .name = "none",
};

static const struct file_ops file_file_ops = {
    .name = "file",
    .lseek = lseek_default,
};

#ifdef HAVE_LWIP
static int socket_read(struct file *file, void *buf, size_t nbytes)
{
    return lwip_read(file->fd, buf, nbytes);
}

static int socket_write(struct file *file, const void *buf, size_t nbytes)
{
    return lwip_write(file->fd, buf, nbytes);
}

static int close_socket_fd(struct file *file)
{
    return lwip_close(file->fd);
}

static int socket_fstat(struct file *file, struct stat *buf)
{
    buf->st_mode = S_IFSOCK | S_IRUSR | S_IWUSR;
    buf->st_atime = buf->st_mtime = buf->st_ctime = time(NULL);

    return 0;
}

static int socket_fcntl(struct file *file, int cmd, va_list args)
{
    long arg;

    arg = va_arg(args, long);

    if ( cmd == F_SETFL && !(arg & ~O_NONBLOCK) )
    {
        /* Only flag supported: non-blocking mode */
        uint32_t nblock = !!(arg & O_NONBLOCK);

        return lwip_ioctl(file->fd, FIONBIO, &nblock);
    }

    printk("socket fcntl(fd, %d, %lx/%lo)\n", cmd, arg, arg);
    errno = ENOSYS;
    return -1;
}

static const struct file_ops socket_ops = {
    .name = "socket",
    .read = socket_read,
    .write = socket_write,
    .close = close_socket_fd,
    .fstat = socket_fstat,
    .fcntl = socket_fcntl,
};
#endif

static const struct file_ops *file_ops[FTYPE_N + FTYPE_SPARE] = {
    [FTYPE_NONE] = &file_ops_none,
#ifdef CONFIG_CONSFRONT
    [FTYPE_CONSOLE] = &console_ops,
#endif
    [FTYPE_FILE] = &file_file_ops,
#ifdef HAVE_LWIP
    [FTYPE_SOCKET] = &socket_ops,
#endif
};

unsigned int alloc_file_type(const struct file_ops *ops)
{
    static unsigned int i = FTYPE_N;
    unsigned int ret;

    pthread_mutex_lock(&fd_lock);

    BUG_ON(i == ARRAY_SIZE(file_ops));
    ret = i++;
    file_ops[ret] = ops;

    pthread_mutex_unlock(&fd_lock);

    printk("New file type \"%s\"(%u) allocated\n", ops->name, ret);

    return ret;
}
EXPORT_SYMBOL(alloc_file_type);

static const struct file_ops *get_file_ops(unsigned int type)
{
    if ( type >= ARRAY_SIZE(file_ops) || !file_ops[type] )
        return &file_ops_none;

    return file_ops[type];
}

struct file *get_file_from_fd(int fd)
{
    if ( fd < 0 || fd >= ARRAY_SIZE(files) )
        return NULL;

    return (files[fd].type == FTYPE_NONE) ? NULL : files + fd;
}
EXPORT_SYMBOL(get_file_from_fd);

DECLARE_WAIT_QUEUE_HEAD(event_queue);
EXPORT_SYMBOL(event_queue);

int alloc_fd(unsigned int type)
{
    int i;
    pthread_mutex_lock(&fd_lock);
    for (i=0; i<NOFILE; i++) {
	if (files[i].type == FTYPE_NONE) {
	    files[i].type = type;
            files[i].offset = 0;
	    pthread_mutex_unlock(&fd_lock);
	    return i;
	}
    }
    pthread_mutex_unlock(&fd_lock);
    printk("Too many opened files\n");
    do_exit();
}
EXPORT_SYMBOL(alloc_fd);

void close_all_files(void)
{
    int i;
    pthread_mutex_lock(&fd_lock);
    for (i=NOFILE - 1; i > 0; i--)
	if (files[i].type != FTYPE_NONE)
            close(i);
    pthread_mutex_unlock(&fd_lock);
}
EXPORT_SYMBOL(close_all_files);

int dup2(int oldfd, int newfd)
{
    pthread_mutex_lock(&fd_lock);
    if (files[newfd].type != FTYPE_NONE)
	close(newfd);
    // XXX: this is a bit bogus, as we are supposed to share the offset etc
    files[newfd] = files[oldfd];
    pthread_mutex_unlock(&fd_lock);
    return 0;
}
EXPORT_SYMBOL(dup2);

pid_t getpid(void)
{
    return 1;
}
EXPORT_SYMBOL(getpid);

pid_t getppid(void)
{
    return 1;
}
EXPORT_SYMBOL(getppid);

pid_t setsid(void)
{
    return 1;
}
EXPORT_SYMBOL(setsid);

char *getcwd(char *buf, size_t size)
{
    snprintf(buf, size, "/");
    return buf;
}
EXPORT_SYMBOL(getcwd);

int mkdir(const char *pathname, mode_t mode)
{
    errno = EIO;
    return -1;
}
EXPORT_SYMBOL(mkdir);

#ifdef CONFIG_CONSFRONT
int posix_openpt(int flags)
{
    int fd;

    /* Ignore flags */
    fd = open_consfront(NULL);
    printk("fd(%d) = posix_openpt\n", fd);

    return fd;
}
EXPORT_SYMBOL(posix_openpt);

static int open_pt(struct mount_point *mnt, const char *pathname, int flags,
                   mode_t mode)
{
    return posix_openpt(flags);
}

int open_savefile(const char *path, int save)
{
    int fd;
    char nodename[64];

    snprintf(nodename, sizeof(nodename), "device/console/%d", save ? 1 : 2);

    fd = open_consfront(nodename);
    printk("fd(%d) = open_savefile\n", fd);

    return fd;
}

static int open_save(struct mount_point *mnt, const char *pathname, int flags,
                     mode_t mode)
{
    return open_savefile(pathname, flags & O_WRONLY);
}
#else
int posix_openpt(int flags)
{
	errno = EIO;
	return -1;
}
EXPORT_SYMBOL(posix_openpt);

int open_savefile(const char *path, int save)
{
	errno = EIO;
	return -1;
}
#endif

static int open_log(struct mount_point *mnt, const char *pathname, int flags,
                    mode_t mode)
{
    int fd;

    /* Ugly, but fine.  */
    fd = alloc_fd(FTYPE_CONSOLE);
    printk("open(%s%s) -> %d\n", mnt->path, pathname, fd);
    return fd;
}

static int open_mem(struct mount_point *mnt, const char *pathname, int flags,
                    mode_t mode)
{
    int fd;

    fd = alloc_fd(FTYPE_MEM);
    printk("open(%s%s) -> %d\n", mnt->path, pathname, fd);
    return fd;
}

static struct mount_point mount_points[N_MOUNTS] = {
    { .path = "/var/log",     .open = open_log,  .dev = NULL },
    { .path = "/dev/mem",     .open = open_mem,  .dev = NULL },
#ifdef CONFIG_CONSFRONT
    { .path = "/dev/ptmx",    .open = open_pt,   .dev = NULL },
    { .path = "/var/lib/xen", .open = open_save, .dev = NULL },
#endif
};

int open(const char *pathname, int flags, ...)
{
    unsigned int m, mlen;
    struct mount_point *mnt;
    mode_t mode = 0;
    va_list ap;

    if ( flags & O_CREAT )
    {
        va_start(ap, flags);
        mode = va_arg(ap, mode_t);
        va_end(ap);
    }

    for ( m = 0; m < ARRAY_SIZE(mount_points); m++ )
    {
        mnt = mount_points + m;
        if ( !mnt->path )
            continue;
        mlen = strlen(mnt->path);
        if ( !strncmp(pathname, mnt->path, mlen) &&
             (pathname[mlen] == '/' || pathname[mlen] == 0) )
            return mnt->open(mnt, pathname + mlen, flags, mode);
    }

    errno = EIO;
    return -1;
}
EXPORT_SYMBOL(open);
EXPORT_SYMBOL(open64);

int mount(const char *path, void *dev,
          int (*open)(struct mount_point *, const char *, int, mode_t))
{
    unsigned int m;
    struct mount_point *mnt;

    for ( m = 0; m < ARRAY_SIZE(mount_points); m++ )
    {
        mnt = mount_points + m;
        if ( !mnt->path )
        {
            mnt->path = strdup(path);
            mnt->open = open;
            mnt->dev = dev;
            return 0;
        }
    }

    errno = ENOSPC;
    return -1;
}

void umount(const char *path)
{
    unsigned int m;
    struct mount_point *mnt;

    for ( m = 0; m < ARRAY_SIZE(mount_points); m++ )
    {
        mnt = mount_points + m;
        if ( mnt->path && !strcmp(mnt->path, path) )
        {
            free((char *)mnt->path);
            mnt->path = NULL;
            return;
        }
    }
}

int isatty(int fd)
{
    return files[fd].type == FTYPE_CONSOLE;
}
EXPORT_SYMBOL(isatty);

int read(int fd, void *buf, size_t nbytes)
{
    struct file *file = get_file_from_fd(fd);
    const struct file_ops *ops;

    if ( !file )
        goto error;

    ops = get_file_ops(file->type);
    if ( ops->read )
        return ops->read(file, buf, nbytes);

 error:
    printk("read(%d): Bad descriptor\n", fd);
    errno = EBADF;
    return -1;
}
EXPORT_SYMBOL(read);

int write(int fd, const void *buf, size_t nbytes)
{
    struct file *file = get_file_from_fd(fd);
    const struct file_ops *ops;

    if ( !file )
        goto error;

    ops = get_file_ops(file->type);
    if ( ops->write )
        return ops->write(file, buf, nbytes);

 error:
    printk("write(%d): Bad descriptor\n", fd);
    errno = EBADF;
    return -1;
}
EXPORT_SYMBOL(write);

off_t lseek_default(struct file *file, off_t offset, int whence)
{
    switch ( whence )
    {
    case SEEK_SET:
        file->offset = offset;
        break;

    case SEEK_CUR:
        file->offset += offset;
        break;

    case SEEK_END:
    {
        struct stat st;
        int ret;

        ret = fstat(file - files, &st);
        if ( ret )
            return -1;
        file->offset = st.st_size + offset;
        break;
    }

    default:
        errno = EINVAL;
        return -1;
    }

    return file->offset;
}

off_t lseek(int fd, off_t offset, int whence)
{
    struct file *file = get_file_from_fd(fd);
    const struct file_ops *ops;

    if ( !file )
    {
        errno = EBADF;
        return (off_t)-1;
    }

    ops = get_file_ops(file->type);
    if ( ops->lseek )
        return ops->lseek(file, offset, whence);

    /* Not implemented for this filetype */
    errno = ESPIPE;
    return (off_t) -1;
}
EXPORT_SYMBOL(lseek);
EXPORT_SYMBOL(lseek64);

int fsync(int fd) {
    errno = EBADF;
    return -1;
}
EXPORT_SYMBOL(fsync);

int close(int fd)
{
    int res = 0;
    struct file *file = get_file_from_fd(fd);
    const struct file_ops *ops;

    if ( !file )
        goto error;

    ops = get_file_ops(file->type);
    printk("close(%d)\n", fd);
    if ( ops->close )
        res = ops->close(file);
    else if ( file->type == FTYPE_NONE )
        goto error;

    memset(files + fd, 0, sizeof(struct file));
    BUILD_BUG_ON(FTYPE_NONE != 0);

    return res;

 error:
    printk("close(%d): Bad descriptor\n", fd);
    errno = EBADF;
    return -1;
}
EXPORT_SYMBOL(close);

static void init_stat(struct stat *buf)
{
    memset(buf, 0, sizeof(*buf));
    buf->st_dev = 0;
    buf->st_ino = 0;
    buf->st_nlink = 1;
    buf->st_rdev = 0;
    buf->st_blksize = 4096;
    buf->st_blocks = 0;
}

int stat(const char *path, struct stat *buf)
{
    errno = EIO;
    return -1;
}
EXPORT_SYMBOL(stat);

int fstat(int fd, struct stat *buf)
{
    struct file *file = get_file_from_fd(fd);
    const struct file_ops *ops;

    if ( !file )
        goto error;

    init_stat(buf);

    ops = get_file_ops(file->type);
    if ( ops->fstat )
        return ops->fstat(file, buf);

 error:
    printk("statf(%d): Bad descriptor\n", fd);
    errno = EBADF;
    return -1;
}
EXPORT_SYMBOL(fstat);
EXPORT_SYMBOL(fstat64);

int ftruncate(int fd, off_t length)
{
    errno = EBADF;
    return -1;
}
EXPORT_SYMBOL(ftruncate);

int remove(const char *pathname)
{
    errno = EIO;
    return -1;
}
EXPORT_SYMBOL(remove);

int unlink(const char *pathname)
{
    return remove(pathname);
}
EXPORT_SYMBOL(unlink);

int rmdir(const char *pathname)
{
    return remove(pathname);
}
EXPORT_SYMBOL(rmdir);

int fcntl(int fd, int cmd, ...)
{
    long arg;
    va_list ap;
    int res;
    struct file *file = get_file_from_fd(fd);
    const struct file_ops *ops;

    if ( !file )
    {
        errno = EBADF;
        return -1;
    }

    ops = get_file_ops(files[fd].type);

    if ( ops->fcntl )
    {
        va_start(ap, cmd);
        res = ops->fcntl(file, cmd, ap);
        va_end(ap);

        return res;
    }

    va_start(ap, cmd);
    arg = va_arg(ap, long);
    va_end(ap);

    printk("fcntl(%d, %d, %lx/%lo)\n", fd, cmd, arg, arg);
    errno = ENOSYS;
    return -1;
}
EXPORT_SYMBOL(fcntl);

DIR *opendir(const char *name)
{
    DIR *ret;
    ret = malloc(sizeof(*ret));
    ret->name = strdup(name);
    ret->offset = 0;
    ret->entries = NULL;
    ret->curentry = -1;
    ret->nbentries = 0;
    ret->has_more = 1;
    return ret;
}
EXPORT_SYMBOL(opendir);

struct dirent *readdir(DIR *dir)
{
    return NULL;
} 
EXPORT_SYMBOL(readdir);

int closedir(DIR *dir)
{
    int i;
    for (i=0; i<dir->nbentries; i++)
        free(dir->entries[i]);
    free(dir->entries);
    free(dir->name);
    free(dir);
    return 0;
}
EXPORT_SYMBOL(closedir);

/* We assume that only the main thread calls select(). */

#ifdef LIBC_DEBUG
static void dump_set(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, struct timeval *timeout)
{
    int i, comma;
#define printfds(set) do {\
    comma = 0; \
    for (i = 0; i < nfds; i++) { \
	if (FD_ISSET(i, set)) { \
	    if (comma) \
		printk(", "); \
            printk("%d(%s)", i, get_file_ops(files[i].type)->name); \
	    comma = 1; \
	} \
    } \
} while (0)

    printk("[");
    if (readfds)
	printfds(readfds);
    printk("], [");
    if (writefds)
	printfds(writefds);
    printk("], [");
    if (exceptfds)
	printfds(exceptfds);
    printk("], ");
    if (timeout)
	printk("{ %ld, %ld }", timeout->tv_sec, timeout->tv_usec);
}
#else
#define dump_set(nfds, readfds, writefds, exceptfds, timeout)
#endif

#ifdef LIBC_DEBUG
static void dump_pollfds(struct pollfd *pfd, int nfds, int timeout)
{
    int i, comma, fd;

    printk("[");
    comma = 0;
    for (i = 0; i < nfds; i++) {
        fd = pfd[i].fd;
        if (comma)
            printk(", ");
        printk("%d(%s)/%02x", fd, get_file_ops(files[fd].type)->name,
            pfd[i].events);
            comma = 1;
    }
    printk("]");

    printk(", %d, %d", nfds, timeout);
}
#else
#define dump_pollfds(pfds, nfds, timeout)
#endif

bool select_yes(struct file *file)
{
    return true;
}

bool select_read_flag(struct file *file)
{
    return file->read;
}
EXPORT_SYMBOL(select_read_flag);

/* Just poll without blocking */
static int select_poll(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds)
{
    int i, n = 0;
#ifdef HAVE_LWIP
    int sock_n = 0, sock_nfds = 0;
    fd_set sock_readfds, sock_writefds, sock_exceptfds;
    struct timeval timeout = { .tv_sec = 0, .tv_usec = 0};
#endif

#ifdef LIBC_VERBOSE
    static int nb;
    static int nbread[NOFILE], nbwrite[NOFILE], nbexcept[NOFILE];
    static s_time_t lastshown;

    nb++;
#endif

#ifdef HAVE_LWIP
    /* first poll network */
    FD_ZERO(&sock_readfds);
    FD_ZERO(&sock_writefds);
    FD_ZERO(&sock_exceptfds);
    for (i = 0; i < nfds; i++) {
	if (files[i].type == FTYPE_SOCKET) {
	    if (FD_ISSET(i, readfds)) {
		FD_SET(files[i].fd, &sock_readfds);
		sock_nfds = i+1;
	    }
	    if (FD_ISSET(i, writefds)) {
		FD_SET(files[i].fd, &sock_writefds);
		sock_nfds = i+1;
	    }
	    if (FD_ISSET(i, exceptfds)) {
		FD_SET(files[i].fd, &sock_exceptfds);
		sock_nfds = i+1;
	    }
	}
    }
    if (sock_nfds > 0) {
        DEBUG("lwip_select(");
        dump_set(nfds, &sock_readfds, &sock_writefds, &sock_exceptfds, &timeout);
        DEBUG("); -> ");
        sock_n = lwip_select(sock_nfds, &sock_readfds, &sock_writefds, &sock_exceptfds, &timeout);
        dump_set(nfds, &sock_readfds, &sock_writefds, &sock_exceptfds, &timeout);
        DEBUG("\n");
    }
#endif

    /* Then see others as well. */
    for (i = 0; i < nfds; i++) {
        struct file *file = get_file_from_fd(i);

        if ( !file )
        {
            FD_CLR(i, readfds);
            FD_CLR(i, writefds);
            FD_CLR(i, exceptfds);
            continue;
        }

        switch(file->type) {
	default:
        {
            const struct file_ops *ops = file_ops[file->type];

            if ( ops )
            {
                if ( FD_ISSET(i, readfds) )
                {
                    if ( ops->select_rd && ops->select_rd(file) )
                        n++;
                    else
                        FD_CLR(i, readfds);
                }
                if ( FD_ISSET(i, writefds) )
                {
                    if ( ops->select_wr && ops->select_wr(file) )
                        n++;
                    else
                        FD_CLR(i, writefds);
                }
                FD_CLR(i, exceptfds);

                break;
            }

	    if (FD_ISSET(i, readfds) || FD_ISSET(i, writefds) || FD_ISSET(i, exceptfds))
            {
		printk("bogus fd %d in select\n", i);
                if ( FD_ISSET(i, readfds) )
                    FD_CLR(i, readfds);
                if ( FD_ISSET(i, writefds) )
                    FD_CLR(i, writefds);
                if ( FD_ISSET(i, exceptfds) )
                    FD_CLR(i, exceptfds);
            }
	    break;
        }

#ifdef HAVE_LWIP
	case FTYPE_SOCKET:
	    if (FD_ISSET(i, readfds)) {
	        /* Optimize no-network-packet case.  */
		if (sock_n && FD_ISSET(files[i].fd, &sock_readfds))
		    n++;
		else
		    FD_CLR(i, readfds);
	    }
            if (FD_ISSET(i, writefds)) {
		if (sock_n && FD_ISSET(files[i].fd, &sock_writefds))
		    n++;
		else
		    FD_CLR(i, writefds);
            }
            if (FD_ISSET(i, exceptfds)) {
		if (sock_n && FD_ISSET(files[i].fd, &sock_exceptfds))
		    n++;
		else
		    FD_CLR(i, exceptfds);
            }
	    break;
#endif
	}
#ifdef LIBC_VERBOSE
	if (FD_ISSET(i, readfds))
	    nbread[i]++;
	if (FD_ISSET(i, writefds))
	    nbwrite[i]++;
	if (FD_ISSET(i, exceptfds))
	    nbexcept[i]++;
#endif
    }
#ifdef LIBC_VERBOSE
    if (NOW() > lastshown + 1000000000ull) {
	lastshown = NOW();
	printk("%lu MB free, ", num_free_pages() / ((1 << 20) / PAGE_SIZE));
	printk("%d(%d): ", nb, sock_n);
	for (i = 0; i < nfds; i++) {
	    if (nbread[i] || nbwrite[i] || nbexcept[i])
                printk(" %d(%c):", i, get_file_ops(files[i].type)->name);
	    if (nbread[i])
	    	printk(" %dR", nbread[i]);
	    if (nbwrite[i])
		printk(" %dW", nbwrite[i]);
	    if (nbexcept[i])
		printk(" %dE", nbexcept[i]);
	}
	printk("\n");
	memset(nbread, 0, sizeof(nbread));
	memset(nbwrite, 0, sizeof(nbwrite));
	memset(nbexcept, 0, sizeof(nbexcept));
	nb = 0;
    }
#endif
    return n;
}

/* The strategy is to
 * - announce that we will maybe sleep
 * - poll a bit ; if successful, return
 * - if timeout, return
 * - really sleep (except if somebody woke us in the meanwhile) */
int select(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds,
	struct timeval *timeout)
{
    int n, ret;
    fd_set myread, mywrite, myexcept;
    struct thread *thread = get_current();
    s_time_t start = NOW(), stop;
#ifdef CONFIG_NETFRONT
    DEFINE_WAIT(netfront_w);
#endif
    DEFINE_WAIT(event_w);
#ifdef CONFIG_BLKFRONT
    DEFINE_WAIT(blkfront_w);
#endif
#ifdef CONFIG_XENBUS
    DEFINE_WAIT(xenbus_watch_w);
#endif
#ifdef CONFIG_KBDFRONT
    DEFINE_WAIT(kbdfront_w);
#endif
    DEFINE_WAIT(console_w);

    assert(thread == main_thread);

    DEBUG("select(%d, ", nfds);
    dump_set(nfds, readfds, writefds, exceptfds, timeout);
    DEBUG(");\n");

    if (timeout)
	stop = start + SECONDS(timeout->tv_sec) + timeout->tv_usec * 1000;
    else
	/* just make gcc happy */
	stop = start;

    /* Tell people we're going to sleep before looking at what they are
     * saying, hence letting them wake us if events happen between here and
     * schedule() */
#ifdef CONFIG_NETFRONT
    add_waiter(netfront_w, netfront_queue);
#endif
    add_waiter(event_w, event_queue);
#ifdef CONFIG_BLKFRONT
    add_waiter(blkfront_w, blkfront_queue);
#endif
#ifdef CONFIG_XENBUS
    add_waiter(xenbus_watch_w, xenbus_watch_queue);
#endif
#ifdef CONFIG_KBDFRONT
    add_waiter(kbdfront_w, kbdfront_queue);
#endif
    add_waiter(console_w, console_queue);

    if (readfds)
        myread = *readfds;
    else
        FD_ZERO(&myread);
    if (writefds)
        mywrite = *writefds;
    else
        FD_ZERO(&mywrite);
    if (exceptfds)
        myexcept = *exceptfds;
    else
        FD_ZERO(&myexcept);

    DEBUG("polling ");
    dump_set(nfds, &myread, &mywrite, &myexcept, timeout);
    DEBUG("\n");
    n = select_poll(nfds, &myread, &mywrite, &myexcept);

    if (n) {
	dump_set(nfds, readfds, writefds, exceptfds, timeout);
	if (readfds)
	    *readfds = myread;
	if (writefds)
	    *writefds = mywrite;
	if (exceptfds)
	    *exceptfds = myexcept;
	DEBUG(" -> ");
	dump_set(nfds, readfds, writefds, exceptfds, timeout);
	DEBUG("\n");
	wake(thread);
	ret = n;
	goto out;
    }
    if (timeout && NOW() >= stop) {
	if (readfds)
	    FD_ZERO(readfds);
	if (writefds)
	    FD_ZERO(writefds);
	if (exceptfds)
	    FD_ZERO(exceptfds);
	timeout->tv_sec = 0;
	timeout->tv_usec = 0;
	wake(thread);
	ret = 0;
	goto out;
    }

    if (timeout)
	thread->wakeup_time = stop;
    schedule();

    if (readfds)
        myread = *readfds;
    else
        FD_ZERO(&myread);
    if (writefds)
        mywrite = *writefds;
    else
        FD_ZERO(&mywrite);
    if (exceptfds)
        myexcept = *exceptfds;
    else
        FD_ZERO(&myexcept);

    n = select_poll(nfds, &myread, &mywrite, &myexcept);

    if (n) {
	if (readfds)
	    *readfds = myread;
	if (writefds)
	    *writefds = mywrite;
	if (exceptfds)
	    *exceptfds = myexcept;
	ret = n;
	goto out;
    }
    errno = EINTR;
    ret = -1;

out:
#ifdef CONFIG_NETFRONT
    remove_waiter(netfront_w, netfront_queue);
#endif
    remove_waiter(event_w, event_queue);
#ifdef CONFIG_BLKFRONT
    remove_waiter(blkfront_w, blkfront_queue);
#endif
#ifdef CONFIG_XENBUS
    remove_waiter(xenbus_watch_w, xenbus_watch_queue);
#endif
#ifdef CONFIG_KBDFRONT
    remove_waiter(kbdfront_w, kbdfront_queue);
#endif
    remove_waiter(console_w, console_queue);
    return ret;
}
EXPORT_SYMBOL(select);

/* Wrap around select */
int poll(struct pollfd _pfd[], nfds_t _nfds, int _timeout)
{
    int n, ret;
    int i, fd;
    struct timeval _timeo, *timeo = NULL;
    fd_set rfds, wfds, efds;
    int max_fd = -1;

    DEBUG("poll(");
    dump_pollfds(_pfd, _nfds, _timeout);
    DEBUG(")\n");

    FD_ZERO(&rfds);
    FD_ZERO(&wfds);
    FD_ZERO(&efds);

    n = 0;

    for (i = 0; i < _nfds; i++) {
        fd = _pfd[i].fd;
        _pfd[i].revents = 0;

        /* fd < 0, revents = 0, which is already set */
        if (fd < 0) continue;

        /* fd is invalid, revents = POLLNVAL, increment counter */
        if (fd >= NOFILE || files[fd].type == FTYPE_NONE) {
            n++;
            _pfd[i].revents |= POLLNVAL;
            continue;
        }

        /* normal case, map POLL* into readfds and writefds:
         * POLLIN  -> readfds
         * POLLOUT -> writefds
         * POLL*   -> none
         */
        if (_pfd[i].events & POLLIN)
            FD_SET(fd, &rfds);
        if (_pfd[i].events & POLLOUT)
            FD_SET(fd, &wfds);
        /* always set exceptfds */
        FD_SET(fd, &efds);
        if (fd > max_fd)
            max_fd = fd;
    }

    /* should never sleep when we already have events */
    if (n) {
        _timeo.tv_sec  = 0;
        _timeo.tv_usec = 0;
        timeo = &_timeo;
    } else if (_timeout >= 0) {
        /* normal case, construct _timeout, might sleep */
        _timeo.tv_sec  = _timeout / 1000;
        _timeo.tv_usec = (_timeout % 1000) * 1000;
        timeo = &_timeo;
    } else {
        /* _timeout < 0, block forever */
        timeo = NULL;
    }


    ret = select(max_fd+1, &rfds, &wfds, &efds, timeo);
    /* error in select, just return, errno is set by select() */
    if (ret < 0)
        return ret;

    for (i = 0; i < _nfds; i++) {
        fd = _pfd[i].fd;

        /* the revents has already been set for all error case */
        if (fd < 0 || fd >= NOFILE || files[fd].type == FTYPE_NONE)
            continue;

        if (FD_ISSET(fd, &rfds) || FD_ISSET(fd, &wfds) || FD_ISSET(fd, &efds))
            n++;
        if (FD_ISSET(fd, &efds)) {
            /* anything bad happens we set POLLERR */
            _pfd[i].revents |= POLLERR;
            continue;
        }
        if (FD_ISSET(fd, &rfds))
            _pfd[i].revents |= POLLIN;
        if (FD_ISSET(fd, &wfds))
            _pfd[i].revents |= POLLOUT;
    }

    return n;
}
EXPORT_SYMBOL(poll);

#ifdef HAVE_LWIP
int socket(int domain, int type, int protocol)
{
    int fd, res;
    fd = lwip_socket(domain, type, protocol);
    if (fd < 0)
	return -1;
    res = alloc_fd(FTYPE_SOCKET);
    printk("socket -> %d\n", res);
    files[res].fd = fd;
    return res;
}
EXPORT_SYMBOL(socket);

int accept(int s, struct sockaddr *addr, socklen_t *addrlen)
{
    int fd, res;
    if (files[s].type != FTYPE_SOCKET) {
	printk("accept(%d): Bad descriptor\n", s);
	errno = EBADF;
	return -1;
    }
    fd = lwip_accept(files[s].fd, addr, addrlen);
    if (fd < 0)
	return -1;
    res = alloc_fd(FTYPE_SOCKET);
    files[res].fd = fd;
    printk("accepted on %d -> %d\n", s, res);
    return res;
}
EXPORT_SYMBOL(accept);

#define LWIP_STUB(ret, name, proto, args) \
ret name proto \
{ \
    if (files[s].type != FTYPE_SOCKET) { \
	printk(#name "(%d): Bad descriptor\n", s); \
	errno = EBADF; \
	return -1; \
    } \
    s = files[s].fd; \
    return lwip_##name args; \
}

LWIP_STUB(int, bind, (int s, struct sockaddr *my_addr, socklen_t addrlen), (s, my_addr, addrlen))
EXPORT_SYMBOL(bind);
LWIP_STUB(int, getsockopt, (int s, int level, int optname, void *optval, socklen_t *optlen), (s, level, optname, optval, optlen))
EXPORT_SYMBOL(getsockopt);
LWIP_STUB(int, setsockopt, (int s, int level, int optname, void *optval, socklen_t optlen), (s, level, optname, optval, optlen))
EXPORT_SYMBOL(setsockopt);
LWIP_STUB(int, connect, (int s, struct sockaddr *serv_addr, socklen_t addrlen), (s, serv_addr, addrlen))
EXPORT_SYMBOL(connect);
LWIP_STUB(int, listen, (int s, int backlog), (s, backlog));
EXPORT_SYMBOL(listen);
LWIP_STUB(ssize_t, recv, (int s, void *buf, size_t len, int flags), (s, buf, len, flags))
EXPORT_SYMBOL(recv);
LWIP_STUB(ssize_t, recvfrom, (int s, void *buf, size_t len, int flags, struct sockaddr *from, socklen_t *fromlen), (s, buf, len, flags, from, fromlen))
EXPORT_SYMBOL(recvfrom);
LWIP_STUB(ssize_t, send, (int s, void *buf, size_t len, int flags), (s, buf, len, flags))
EXPORT_SYMBOL(send);
LWIP_STUB(ssize_t, sendto, (int s, void *buf, size_t len, int flags, struct sockaddr *to, socklen_t tolen), (s, buf, len, flags, to, tolen))
EXPORT_SYMBOL(sendto);
LWIP_STUB(int, getsockname, (int s, struct sockaddr *name, socklen_t *namelen), (s, name, namelen))
EXPORT_SYMBOL(getsockname);
#endif

static char *syslog_ident;
void openlog(const char *ident, int option, int facility)
{
    free(syslog_ident);
    syslog_ident = strdup(ident);
}
EXPORT_SYMBOL(openlog);

void vsyslog(int priority, const char *format, va_list ap)
{
    printk("%s: ", syslog_ident);
    print(0, format, ap);
}
EXPORT_SYMBOL(vsyslog);

void syslog(int priority, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    vsyslog(priority, format, ap);
    va_end(ap);
}
EXPORT_SYMBOL(syslog);

void closelog(void)
{
    free(syslog_ident);
    syslog_ident = NULL;
}
EXPORT_SYMBOL(closelog);

void vwarn(const char *format, va_list ap)
{
    int the_errno = errno;
    printk("stubdom: ");
    if (format) {
        print(0, format, ap);
        printk(", ");
    }
    printk("%s", strerror(the_errno));
}
EXPORT_SYMBOL(vwarn);

void warn(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    vwarn(format, ap);
    va_end(ap);
}
EXPORT_SYMBOL(warn);

void verr(int eval, const char *format, va_list ap)
{
    vwarn(format, ap);
    exit(eval);
}
EXPORT_SYMBOL(verr);

void err(int eval, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    verr(eval, format, ap);
    va_end(ap);
}
EXPORT_SYMBOL(err);

void vwarnx(const char *format, va_list ap)
{
    printk("stubdom: ");
    if (format)
        print(0, format, ap);
}
EXPORT_SYMBOL(vwarnx);

void warnx(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    vwarnx(format, ap);
    va_end(ap);
}
EXPORT_SYMBOL(warnx);

void verrx(int eval, const char *format, va_list ap)
{
    vwarnx(format, ap);
    exit(eval);
}
EXPORT_SYMBOL(verrx);

void errx(int eval, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    verrx(eval, format, ap);
    va_end(ap);
}
EXPORT_SYMBOL(errx);

int nanosleep(const struct timespec *req, struct timespec *rem)
{
    s_time_t start = NOW();
    s_time_t stop = start + SECONDS(req->tv_sec) + req->tv_nsec;
    s_time_t stopped;
    struct thread *thread = get_current();

    thread->wakeup_time = stop;
    clear_runnable(thread);
    schedule();
    stopped = NOW();

    if (rem)
    {
	s_time_t remaining = stop - stopped;
	if (remaining > 0)
	{
	    rem->tv_nsec = remaining % 1000000000ULL;
	    rem->tv_sec  = remaining / 1000000000ULL;
	} else memset(rem, 0, sizeof(*rem));
    }

    return 0;
}
EXPORT_SYMBOL(nanosleep);

int usleep(useconds_t usec)
{
    /* "usec shall be less than one million."  */
    struct timespec req;
    req.tv_nsec = usec * 1000;
    req.tv_sec = 0;

    if (nanosleep(&req, NULL))
	return -1;

    return 0;
}
EXPORT_SYMBOL(usleep);

unsigned int sleep(unsigned int seconds)
{
    struct timespec req, rem;
    req.tv_sec = seconds;
    req.tv_nsec = 0;

    if (nanosleep(&req, &rem))
	return -1;

    if (rem.tv_nsec > 0)
	rem.tv_sec++;

    return rem.tv_sec;
}
EXPORT_SYMBOL(sleep);

int clock_gettime(clockid_t clk_id, struct timespec *tp)
{
    switch (clk_id) {
	case CLOCK_MONOTONIC:
	{
	    struct timeval tv;

	    gettimeofday(&tv, NULL);

	    tp->tv_sec = tv.tv_sec;
	    tp->tv_nsec = tv.tv_usec * 1000;

	    break;
	}
	case CLOCK_REALTIME:
	{
	    uint64_t nsec = monotonic_clock();

	    tp->tv_sec = nsec / 1000000000ULL;
	    tp->tv_nsec = nsec % 1000000000ULL;

	    break;
	}
	default:
	    print_unsupported("clock_gettime(%ld)", (long) clk_id);
	    errno = EINVAL;
	    return -1;
    }

    return 0;
}
EXPORT_SYMBOL(clock_gettime);

uid_t getuid(void)
{
	return 0;
}
EXPORT_SYMBOL(getuid);

uid_t geteuid(void)
{
	return 0;
}
EXPORT_SYMBOL(geteuid);

gid_t getgid(void)
{
	return 0;
}
EXPORT_SYMBOL(getgid);

gid_t getegid(void)
{
	return 0;
}
EXPORT_SYMBOL(getegid);

int gethostname(char *name, size_t namelen)
{
	strncpy(name, "mini-os", namelen);
	return 0;
}
EXPORT_SYMBOL(gethostname);

size_t getpagesize(void)
{
    return PAGE_SIZE;
}
EXPORT_SYMBOL(getpagesize);

void *mmap(void *start, size_t length, int prot, int flags, int fd, off_t offset)
{
    unsigned long n = (length + PAGE_SIZE - 1) / PAGE_SIZE;

    ASSERT(!start);
    ASSERT(prot == (PROT_READ|PROT_WRITE));
    ASSERT((fd == -1 && (flags == (MAP_SHARED|MAP_ANON) || flags == (MAP_PRIVATE|MAP_ANON)))
        || (fd != -1 && flags == MAP_SHARED));

    if (fd == -1)
        return map_zero(n, 1);
    else if (files[fd].type == FTYPE_MEM) {
        unsigned long first_mfn = offset >> PAGE_SHIFT;
        return map_frames_ex(&first_mfn, n, 0, 1, 1, DOMID_IO, NULL, _PAGE_PRESENT|_PAGE_RW);
    } else ASSERT(0);
}
EXPORT_SYMBOL(mmap);
EXPORT_SYMBOL(mmap64);

int munmap(void *start, size_t length)
{
    int total = length / PAGE_SIZE;
    int ret;

    ret = unmap_frames((unsigned long)start, (unsigned long)total);
    if (ret) {
        errno = ret;
        return -1;
    }
    return 0;
}
EXPORT_SYMBOL(munmap);

void sparse(unsigned long data, size_t size)
{
    unsigned long newdata;
    xen_pfn_t *mfns;
    int i, n;

    newdata = (data + PAGE_SIZE - 1) & PAGE_MASK;
    if (newdata - data > size)
        return;
    size -= newdata - data;
    data = newdata;
    n = size / PAGE_SIZE;
    size = n * PAGE_SIZE;

    mfns = malloc(n * sizeof(*mfns));
    for (i = 0; i < n; i++) {
#ifdef LIBC_DEBUG
        int j;
        for (j=0; j<PAGE_SIZE; j++)
            if (((char*)data + i * PAGE_SIZE)[j]) {
                printk("%lx is not zero!\n", data + i * PAGE_SIZE + j);
                exit(1);
            }
#endif
        mfns[i] = virtual_to_mfn(data + i * PAGE_SIZE);
    }

    printk("sparsing %ldMB at %lx\n", ((long) size) >> 20, data);

    munmap((void *) data, size);
    free_physical_pages(mfns, n);
    do_map_zero(data, n);
}

int nice(int inc)
{
    printk("nice() stub called with inc=%d\n", inc);
    return 0;
}
EXPORT_SYMBOL(nice);

/* Limited termios terminal settings support */
const struct termios default_termios = {0,             /* iflag */
                                        OPOST | ONLCR, /* oflag */
                                        0,             /* lflag */
                                        CREAD | CS8,   /* cflag */
                                        {}};           /* cc */

int tcsetattr(int fildes, int action, const struct termios *tios)
{
    struct consfront_dev *dev;

    if (fildes < 0 || fildes >= NOFILE) {
        errno = EBADF;
        return -1;
    }

    if (files[fildes].type != FTYPE_CONSOLE) {
        errno = ENOTTY;
        return -1;
    }

    if (tios == NULL) {
        errno = EINVAL;
        return -1;
    }

    switch (action) {
        case TCSANOW:
        case TCSADRAIN:
        case TCSAFLUSH:
            break;
        default:
            errno = EINVAL;
            return -1;
    }

    dev = files[fildes].dev;
    if (dev == NULL) {
        errno = ENOSYS;
        return -1;
    }

    dev->is_raw = !(tios->c_oflag & OPOST);

    return 0;
}
EXPORT_SYMBOL(tcsetattr);

int tcgetattr(int fildes, struct termios *tios)
{
    struct consfront_dev *dev;

    if (fildes < 0 || fildes >= NOFILE) {
        errno = EBADF;
        return -1;
    }

    if (files[fildes].type != FTYPE_CONSOLE) {
        errno = ENOTTY;
        return -1;
    }

    dev = files[fildes].dev;
    if (dev == NULL) {
        errno = ENOSYS;
        return 0;
    }

    if (tios == NULL) {
        errno = EINVAL;
        return -1;
    }

    memcpy(tios, &default_termios, sizeof(struct termios));

    if (dev->is_raw)
        tios->c_oflag &= ~OPOST;

    return 0;
}
EXPORT_SYMBOL(tcgetattr);

void cfmakeraw(struct termios *tios)
{
    tios->c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP
                       | INLCR | IGNCR | ICRNL | IXON);
    tios->c_oflag &= ~OPOST;
    tios->c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
    tios->c_cflag &= ~(CSIZE | PARENB);
    tios->c_cflag |= CS8;
}
EXPORT_SYMBOL(cfmakeraw);

/* Not supported by FS yet.  */
unsupported_function_crash(link);
unsupported_function(int, readlink, -1);
unsupported_function_crash(umask);

/* We could support that.  */
unsupported_function_log(int, chdir, -1);

/* No dynamic library support.  */ 
unsupported_function_log(void *, dlopen, NULL);
unsupported_function_log(void *, dlsym, NULL);
unsupported_function_log(char *, dlerror, NULL);
unsupported_function_log(int, dlclose, -1);

/* We don't raise signals anyway.  */
unsupported_function(int, sigemptyset, -1);
unsupported_function(int, sigfillset, -1);
unsupported_function(int, sigaddset, -1);
unsupported_function(int, sigdelset, -1);
unsupported_function(int, sigismember, -1);
unsupported_function(int, sigprocmask, -1);
unsupported_function(int, sigaction, -1);
unsupported_function(int, __sigsetjmp, 0);
unsupported_function(int, sigaltstack, -1);
unsupported_function_crash(kill);

/* Unsupported */
unsupported_function_crash(pipe);
unsupported_function_crash(fork);
unsupported_function_crash(execv);
unsupported_function_crash(execve);
unsupported_function_crash(waitpid);
unsupported_function_crash(wait);
unsupported_function_crash(lockf);
unsupported_function_crash(sysconf);
unsupported_function(int, grantpt, -1);
unsupported_function(int, unlockpt, -1);
unsupported_function(char *, ptsname, NULL);

/* net/if.h */
unsupported_function_log(unsigned int, if_nametoindex, -1);
unsupported_function_log(char *, if_indextoname, (char *) NULL);
unsupported_function_log(struct  if_nameindex *, if_nameindex, (struct  if_nameindex *) NULL);
unsupported_function_crash(if_freenameindex);

/* Linuxish abi for the Caml runtime, don't support 
   Log, and return an error code if possible.  If it is not possible
   to inform the application of an error, then crash instead!
*/
unsupported_function_log(struct dirent *, readdir64, NULL);
unsupported_function_log(int, getrusage, -1);
unsupported_function_log(int, getrlimit, -1);
unsupported_function_log(int, getrlimit64, -1);
unsupported_function_log(int, __xstat64, -1);
unsupported_function_log(long, __strtol_internal, LONG_MIN);
unsupported_function_log(double, __strtod_internal, HUGE_VAL);
unsupported_function_log(int, utime, -1);
unsupported_function_log(int, truncate64, -1);
unsupported_function_log(int, tcflow, -1);
unsupported_function_log(int, tcflush, -1);
unsupported_function_log(int, tcdrain, -1);
unsupported_function_log(int, tcsendbreak, -1);
unsupported_function_log(int, cfsetospeed, -1);
unsupported_function_log(int, cfsetispeed, -1);
unsupported_function_crash(cfgetospeed);
unsupported_function_crash(cfgetispeed);
unsupported_function_log(int, symlink, -1);
unsupported_function_log(const char*, inet_ntop, NULL);
unsupported_function_crash(__fxstat64);
unsupported_function_crash(__lxstat64);
unsupported_function_log(int, socketpair, -1);
unsupported_function_crash(sigsuspend);
unsupported_function_log(int, sigpending, -1);
unsupported_function_log(int, shutdown, -1);
unsupported_function_log(int, setuid, -1);
unsupported_function_log(int, setgid, -1);
unsupported_function_crash(rewinddir);
unsupported_function_log(int, getpriority, -1);
unsupported_function_log(int, setpriority, -1);
unsupported_function_log(int, mkfifo, -1);
unsupported_function_log(int, getitimer, -1);
unsupported_function_log(int, setitimer, -1);
unsupported_function_log(void *, getservbyport, NULL);
unsupported_function_log(void *, getservbyname, NULL);
unsupported_function_log(void *, getpwuid, NULL);
unsupported_function_log(void *, getpwnam, NULL);
unsupported_function_log(void *, getprotobynumber, NULL);
unsupported_function_log(void *, getprotobyname, NULL);
unsupported_function_log(int, getpeername, -1);
unsupported_function_log(int, getnameinfo, -1);
unsupported_function_log(char *, getlogin, NULL);
unsupported_function_crash(__h_errno_location);
unsupported_function_log(int, gethostbyname_r, -1);
unsupported_function_log(int, gethostbyaddr_r, -1);
unsupported_function_log(int, getgroups, -1);
unsupported_function_log(void *, getgrgid, NULL);
unsupported_function_log(void *, getgrnam, NULL);
unsupported_function_log(int, getaddrinfo, -1);
unsupported_function_log(int, freeaddrinfo, -1);
unsupported_function_log(int, ftruncate64, -1);
unsupported_function_log(int, fchown, -1);
unsupported_function_log(int, fchmod, -1);
unsupported_function_crash(execvp);
unsupported_function_log(int, dup, -1);
unsupported_function_log(int, chroot, -1);
unsupported_function_log(int, chown, -1);
unsupported_function_log(int, chmod, -1);
unsupported_function_crash(alarm);
unsupported_function_log(int, inet_pton, -1);
unsupported_function_log(int, access, -1);
#endif
