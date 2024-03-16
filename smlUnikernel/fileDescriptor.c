#include <sys/types.h>
#include <dirent.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include "/home/svante/Documents/mlkit/src/Runtime/String.h"

#include <fcntl.h>    // for open
#include <unistd.h>   // for read, close

String REG_POLY_FUN_HDR(my_convertStringToML, Region rAddr, const char *cStr, int len) {  
    String res;
    char *p;
    res = REG_POLY_CALL(allocStringC, rAddr, len);
    for (p = res->data; len > 0;) {
        if (*cStr != '\0') {
            *p++ = *cStr++;
        } else {
            cStr++; // Skip null byte
        }
        len--;
    }
    *p = '\0';
    return res;
}

char file[1024];
char* read_fd(int addr, String fileName, Region str_r, Context ctx) {
    char fileName_buf[100];
    size_t len = 100;
    uintptr_t exn = 10; // No idea what this is supposed to be but this value works.
    convertStringToC(ctx, fileName, fileName_buf, len, exn);
    int fd = open(fileName_buf, O_RDONLY);
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
