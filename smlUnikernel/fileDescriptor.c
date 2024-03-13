#include <sys/types.h>
#include <dirent.h>
#include <stdio.h>

#include <fcntl.h>
#include <unistd.h>
#include <string.h>

#include "/home/svante/Documents/mlkit/src/Runtime/List.h"
#include "/home/svante/Documents/mlkit/src/Runtime/String.h"
#include "/home/svante/Documents/mlkit/src/Runtime/Exception.h"
#include "/home/svante/Documents/mlkit/src/Runtime/Region.h"
#include "/home/svante/Documents/mlkit/src/Runtime/Tagging.h"

char file[1024];

char* open_fd(int addr, String fileName, Region str_r) {
    int fd = open("test.txt", O_RDONLY);
    if (fd == -1) {
        return NULL;
    }

    // Read the file in chunks
    ssize_t bytes_read = read(fd, file, 1024);
    if (bytes_read == -1) {
        close(fd);
        return NULL;
    }

    close(fd);

    // Null-terminate the buffer
    file[bytes_read] = '\0';

    return convertStringToML(str_r, file);
}
