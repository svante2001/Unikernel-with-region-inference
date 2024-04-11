#include <stdlib.h>
#include <string.h>

#include "CommandLine.h"
#include "String.h"
#include "List.h"
#include "Tagging.h"
#include "Flags.h"

int commandline_argc;
char **commandline_argv;
static int app_arg_index = 1; /* index for first argument to application. Set by parseArgs */

/*----------------------------------------*
 * Flags recognized by the runtime system *
 *----------------------------------------*/

void
printUsage(void)
{
  fprintf(stderr,"Usage: %s\n", commandline_argv[0]);
  fprintf(stderr,"      [-help, -h] \n");
  fprintf(stderr,"  where\n");
  fprintf(stderr,"      -help, -h                Print this help screen and exit.\n\n");
  fprintf(stderr, "\n");
  exit(0);
}

void
parseCmdLineArgs(int argc, char *argv[])
{
  long match;
  /* initialize global variables to hold command line arguments */
  commandline_argc = argc;
  commandline_argv = argv;
  match = 1;
  while ((--argc > 0) && match) {
    ++argv;    /* next parameter. */
    match = 0;
    if ((strcmp((char *)argv[0], "-h")==0) ||
	(strcmp((char *)argv[0], "-help")==0)) {
      match = 1;
      printUsage();  /* exits */
    }
    if (match) {
      app_arg_index++;
    }
  }
  return;
}

String
REG_POLY_FUN_HDR(sml_commandline_name, Region rAddr)
{
  return REG_POLY_CALL(convertStringToML, rAddr, commandline_argv[0]);
}

uintptr_t
REG_POLY_FUN_HDR(sml_commandline_args, Region pairRho, Region strRho)
{
  uintptr_t *resList, *pairPtr;
  String mlStr;
  int counter = commandline_argc;
  makeNIL(resList);
  while ( counter > app_arg_index )
    {
      mlStr = REG_POLY_CALL(convertStringToML, strRho, commandline_argv[--counter]);
      REG_POLY_CALL(allocPairML, pairRho, pairPtr);
      first(pairPtr) = (size_t) mlStr;
      second(pairPtr) = (size_t) resList;
      makeCONS(pairPtr, resList);
    }
  return (uintptr_t) resList;
}
