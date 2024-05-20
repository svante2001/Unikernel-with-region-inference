/*----------------------------------------------------------------*
 *             Runtime system for the ML-Kit                      *
 *----------------------------------------------------------------*/
#include <console.h>
#include <xmalloc.h>
#include "Runtime.h"
#include "Flags.h"
#include "Tagging.h"
#include "String.h"
#include "Math.h"
#include "Exception.h"
#include "Region.h"
#include "Table.h"


int
die (const char *s)
{
  printk("Runtime Error: %s\n",s);
  while(1);
  return -1;
  // exit(-1)
}

int
die2 (const char *s1, const char* s2)
{
  printk("Runtime Error: %s\n%s\n",s1,s2);
  while(1);
  return -1;
  // exit(-1)
}

// static struct rlimit limit;
typedef unsigned long rlim_t;
struct rlimit
  {
    /* The current (soft) limit.  */
    rlim_t rlim_cur;
    /* The hard limit.  */
    rlim_t rlim_max;
  };
  
#define SIZE_MAX 18446744073709551615UL
#define RLIMIT_STACK 3
#define RLIM_INFINITY 18446744073709551615UL
// #define __THROW	__attribute__ ((__nothrow__ __LEAF));
// extern int getrlimit (int __resource,
// 		      struct rlimit *__rlimits) __THROW __nonnull ((2));

// extern int setrlimit (int __resource,
// 		      const struct rlimit *__rlimits) __THROW __nonnull ((2));

void
setStackSize(rlim_t size)
{
  // int res;
  // char *bad = "Bad";
  // struct rlimit lim;
  // struct rlimit oldlim;
  // res = getrlimit(RLIMIT_STACK, &oldlim);
  // if (res == -1)
  // {
  //   // bad = strerror(errno);
  //   die2("setStackSize(1)", bad);
  // }
  // lim.rlim_cur = oldlim.rlim_max;
  // lim.rlim_max = oldlim.rlim_max;
  // res = setrlimit(RLIMIT_STACK, &lim);
  // if (res == -1)
  // {
  //   return;  // return silently in case of an error; on
  //            // macOS, the call fails, but the stack should already be
  //            // big in size (set during linking)
  // }
  // res = getrlimit(RLIMIT_STACK, &limit);
  // if (res == -1)
  // {
  //   // bad = strerror(errno);
  //   die2("setStackSize(3)", bad);
  // }
  return;
}

void
setStackSizeUnlimited(void)
{
  return setStackSize(RLIM_INFINITY);
}

long
terminateML (long status)
{
  debug(printf("[terminateML..."));
  debug(printf("]\n"));
  return convertIntToC(status);
}

size_t failNumber = SIZE_MAX;
size_t syserrNumber = SIZE_MAX;

void
sml_setFailNumber(uintptr_t ep, int i)
{
  uintptr_t e = first(ep);
  switch (convertIntToC(i))
  {
    case 1:
      failNumber = convertIntToC(first(e));
      break;
    case 2:
      syserrNumber = convertIntToC(first(e));
      break;
  }
  return;
}

// Here is the main thread's "uncaught exception" handler; for server
// purposes, will later allow for end users to install their own
// uncaught exception handlers. A spawned thread has its own kind of
// uncaught exception handler, which will install the exception value
// in the thread context and raise it if the parent thread tries to
// join the thread.

int uncaught_exn_raised = 0;

void
uncaught_exception (Context ctx, String exnStr, unsigned long n, uintptr_t ep)
{
  printk("uncaught exception1\n");
  uintptr_t a;
  ctx->uncaught_exnname = convertIntToC(n);
  printk("uncaught exception2\n");
  
  // fputs(exnStr->data, stderr);
  
  if (convertIntToC(n) == failNumber)
  {
    a = second (ep);
    // fputs(" ", stderr);
    printk("%s", ((String) a)->data);
    // fputs(((String) a)->data,stderr);
    
  }
  if (convertIntToC(n) == syserrNumber)
  {
    a = second(ep);
    a = first(a);
     printk("%s", ((String) a)->data);
    // fputs(" ", stderr);
    // fputs(((String) a)->data,stderr);
    
  }
  printk( "\n");
  while(1);
  
  return;
}

extern void code(Context ctx);

Context top_ctx;   // only for REPL

int
main(int argc, char *argv[])
{
  printk("Running in runtime2!\n");
  if ((((double)Max_Int) != Max_Int_d) || (((double)Min_Int) != Min_Int_d))
    die("main - integer configuration is erroneous");

  // try to set stack size
  setStackSizeUnlimited();

  // parseCmdLineArgs(argc, argv);   /* also initializes ml-access to args */

  Context ctx = (Context) malloc(sizeof(context));
  ctx->topregion = NULL;
  ctx->exnptr = NULL;
  top_ctx = ctx;


  code(ctx);

  printk("Code done running!\n");
  while(1);

  return -1;   /* never comes here (i.e., exits through
                            * terminateML or uncaught_exception) */
}

// Functions for managing high-bit tags (see also Tagging.h)
uintptr_t ptr_hitag_set_fun(uintptr_t ptr, uint16_t tag) {
  return ptr_hitag_set(ptr,tag);
}

uintptr_t ptr_hitag_clear_fun(uintptr_t ptr) {
  return ptr_hitag_clear(ptr);
}

uint16_t ptr_hitag_get_fun(uintptr_t ptr) {
  return ptr_hitag_get(ptr);
}
