/*----------------------------------------------------------------*
 *                        Regions                                 *
 *----------------------------------------------------------------*/
#include <stdio.h>
#include "Flags.h"
#include "Region.h"
#include "Math.h"
#include "Runtime.h"

/*----------------------------------------------------------------*
 * Global declarations                                            *
 *----------------------------------------------------------------*/
Rp * global_freelist = NULL;
long rp_total = 0;

/* Print info about a region. */
void
pp_gen(Gen *gen)
{
  Rp* rp;

  fprintf(stderr,"\n[Gen g%d at addr: %p, fp:%p, a:%p, b:%p\n",
	  (is_gen_1(*gen)?1:0),
	  gen,
	  gen->fp,
	  gen->a,
	  rpBoundary(gen->a));
  for (rp = clear_fp(gen->fp) ; rp ; rp = clear_tospace_bit(rp->n)) {
    fprintf(stderr,"  Rp %p, next:%p, data: %p, rp+1: %p\n",
	    rp,
	    rp->n,
	    &(rp->i),
	    rp+1);
  }
  fprintf(stderr,"]\n");
}

void
pp_reg(Region r,  char *str)
{
  r = clearStatusBits(r);
  fprintf(stderr,"printRegionInfo called from: %s\n",str);
  fprintf(stderr,"Region at address: %p\n", r);
  pp_gen(&(r->g0));
  return;
}

void
chk_obj_in_gen(Gen *gen, uintptr_t *obj_ptr, char* s)
{
  Rp* rp;
  int found = 0;
  return;  // ToDo: GenGC remove
  for (rp = clear_fp(gen->fp) ; rp ; rp = clear_tospace_bit(rp->n)) {
    if (obj_ptr < (uintptr_t*)(rp+1) && obj_ptr >= (uintptr_t*) &(rp->i))
      found = 1;
  }
  if (! found) {
    fprintf(stderr,"chk_obj_in_gen, obj_ptr: %p not in gen:\n",obj_ptr);
    pp_reg(get_ro_from_gen(*gen),"chk_obj_in_gen");
    fprintf(stderr,"STOP:%s\n",s);
    die("");
  }
  return;
}

/* Calculate number of pages in a generation */
inline size_t
NoOfPagesInGen(Gen *gen)
{
  size_t i;
  Rp *rp;

  debug(printf("[NoOfPagesInGen..."));

  for ( i = 0, rp = clear_fp(gen->fp) ; rp ; rp = clear_tospace_bit(rp->n) )
    i++;

  debug(printf("]\n"));

  return i;
}

/* Calculate number of pages in an infinite region. */
size_t
NoOfPagesInRegion(Region r)
{
  return NoOfPagesInGen(&(r->g0));
}

/*-------------------------------------------------------------------------*
 *                         Region operations.                              *
 *                                                                         *
 * allocateRegion: Allocates a region and return a pointer to it.          *
 * deallocateRegion: Pops the top region of the region stack.              *
 * callSbrk: Updates the freelist with new region pages.                   *
 * alloc: Allocates n words in a region.                                   *
 * resetRegion: Resets a region by freeing all pages except one            *
 * deallocateRegionsUntil: All regions below a threshold are deallocated.  *
 *   (stack grows downwards)                                               *
 *-------------------------------------------------------------------------*/

/*----------------------------------------------------------------------*
 *alloc_new_page:                                                       *
 *  Allocates a new page in region.                                     *
 *  The second argument is a pointer to the generation in r to use      *
 *  Important: alloc_new_page must preserve all marks in fp (Region.h)  *
 *----------------------------------------------------------------------*/

uintptr_t *
alloc_new_page(Gen *gen)
{
  Rp* np;
  debug(printf("[alloc_new_page: gen: %p", gen);)

  MAYBE_DEFINE_CONTEXT;

  if ( FREELIST ) {
    np = FREELIST;
    FREELIST = FREELIST->n;
  } else {
    callSbrk();
    np = FREELIST;
    FREELIST = FREELIST->n;
  }

  np->n = NULL;
  np->gen = gen;         // Install origin-pointer to generation - used by GC

  if ( clear_fp(gen->fp) )
    last_rp_of_gen(gen)->n = np; // Updates the next field in the last region page.
  else {
    gen->fp = np;                /* Update pointer to the first page. */
  }

  debug(printf("]\n");)
  return (uintptr_t *) (&(np->i));    /* Return the allocation pointer. */
}

/*----------------------------------------------------------------------*
 *allocateRegion:                                                       *
 *  Get a first regionpage for the region.                              *
 *  Put a region administrationsstructure on the stack. The address is  *
 *  in roAddr.                                                          *
 *----------------------------------------------------------------------*/

static inline Region
allocateRegion0(Context ctx, Region r, Protect protect)
{
  debug(printf("[allocateRegion0 (rAddr=%p, protect=%zu)...",r,protect));
  r = clearStatusBits(r);

  CHECK_CTX("allocateRegion0");

  r->g0.fp = NULL;
  r->p = TOP_REGION;	                   // Push this region onto the region stack
  r->lobjs = NULL;                         // The list of large objects is empty
  r->g0.a = alloc_new_page(&(r->g0));      // Allocate the first region page in g0

  TOP_REGION = r;

  debug(printf("]\n"));
  return r;
}

Region
allocateRegion(Context ctx, Region r, Protect p)
{
  r = allocateRegion0(ctx,r,p);
  r = (Region)setInfiniteBit((uintptr_t)r);
  return r;
}

void free_lobjs(Lobjs* lobjs)
{
  while ( lobjs )
    {
      Lobjs* lobjsTmp;
      lobjsTmp = clear_lobj_bit(lobjs->next);
      free(lobjs);
      lobjs = lobjsTmp;
    }
}

/*----------------------------------------------------------------------*
 *deallocateRegion:                                                     *
 *  Pops the top region of the stack, and insert the regionpages in the *
 *  free list. There have to be atleast one region on the stack.        *
 *  When profiling we also use this function.                           *
 *----------------------------------------------------------------------*/
void deallocateRegion(Context ctx) {
  debug(printf("[deallocateRegion... top region: %p\n", TOP_REGION));
  CHECK_CTX("deallocateRegion");
  free_lobjs(TOP_REGION->lobjs);

  /* Insert the region pages in the freelist; there is always
   * at least one page in a generation. */
  last_rp_of_gen(&(TOP_REGION->g0))->n = FREELIST;  // Free pages in generation 0
  FREELIST = clear_fp(TOP_REGION->g0.fp);
  TOP_REGION = TOP_REGION->p;
  debug(printf("]\n"));
  return;
}

inline static Lobjs *
alloc_lobjs(int n) {
  Lobjs* lobjs;
  lobjs = (Lobjs*)malloc(sizeof(uintptr_t)*n + sizeof(Lobjs));
  if ( lobjs == NULL )
    die("alloc_lobjs: malloc returned NULL");
  return lobjs;
}

/*----------------------------------------------------------------------*
 *callSbrk:                                                             *
 *  Sbrk is called and the free list is updated.                        *
 *  The free list has to be empty.                                      *
 *----------------------------------------------------------------------*/
void callSbrk() {
  Rp *np, *old_free_list;
  char *sb;
  size_t temp;

  /* We must manually insure double alignment. Some operating systems (like *
   * HP UX) does not return a double aligned address...                     */

  /* For GC we require alignments according to the size of region pages! */

  sb = malloc(BYTES_ALLOC_BY_SBRK + sizeof(Rp) + sizeof(Rp) );

  if ( sb == NULL ) {
    perror("I could not allocate more memory; either no more memory is\navailable or the memory subsystem is detectively corrupted\n");
    exit(-1);
  }

  /* alignment (martin) */
  if (( temp = (size_t)(((uintptr_t)sb) % sizeof(Rp) ))) {
    sb = sb + sizeof(Rp) - temp;
  }

  if ( ! is_rp_aligned((size_t)sb) ) {
    printf ("sb=%p\n", sb);
    printf ("sizeof(Rp)=%ld\n", sizeof(Rp));
    printf ("sizeof(uintptr_t)=%ld\n", sizeof(uintptr_t));
    printf ("temp=%ld\n", temp);
    die("SBRK region page is not properly aligned.");
  }

  old_free_list = global_freelist;
  np = (Rp *) sb;
  global_freelist = np;

  rp_total++;

  /* fragment the SBRK-chunk into region pages */
  while ((char *)(np+1) < ((char *)global_freelist)+BYTES_ALLOC_BY_SBRK) {
    np++;
    (np-1)->n = np;
    rp_total++;
  }
  np->n = old_free_list;

  return;
}

/*----------------------------------------------------------------------*
 *alloc:                                                                *
 *  Allocates n words in region rAddr. It will make sure, that there    *
 *  is space for the n words before doing the allocation.               *
 *  Objects whose size n <= ALLOCATABLE_WORDS_IN_REGION_PAGE are        *
 *  allocated in region pages; larger objects are allocated using       *
 *  malloc.                                                             *
 *----------------------------------------------------------------------*/
inline uintptr_t *
allocGen (
	  Gen *gen, size_t n
	  ) {
  uintptr_t *t1;
  uintptr_t *t2;
  uintptr_t *t3;
  Region r;

  debug(printf("[allocGen... generation: %p, n:%zu ", gen,n));
  debug(fflush(stdout));

  // see if the size of requested memory exceeds
  // the size of a region page

  if ( n > ALLOCATABLE_WORDS_IN_REGION_PAGE )   // notice: n is in words
    {
      r = get_ro_from_gen(*gen);
      Lobjs* lobjs;
      lobjs = alloc_lobjs(n);
      lobjs->next = set_lobj_bit(r->lobjs);
      r->lobjs = lobjs;
      return &(lobjs->value);
    }

  t1 = gen->a;
  t2 = t1 + n;
  t3 = rpBoundary(t1);
  if (t2 > t3) {
    gen->a = alloc_new_page(gen);
    t1 = gen->a;
    t2 = t1+n;
  }
  gen->a = t2;

  debug(printf(", t1=%p, t2=%p]\n", t1,t2));
  debug(fflush(stdout));

  return t1;
}

uintptr_t *alloc (Region r, size_t n) {
  r = clearStatusBits(r);
  return allocGen(
		  &(r->g0), n
		  );
}

/*----------------------------------------------------------------------*
 *resetRegion:                                                          *
 *  All regionpages except one are inserted into the free list, and     *
 *  the region administration structure is updated. The statusbits are  *
 *  not changed.                                                        *
 *----------------------------------------------------------------------*/
static inline
void resetGen(Gen *gen)
{
  /* There is always at least one page in a generation. */
  if ( (clear_fp(gen->fp))->n ) { /* There are more than one page in the generation. */
    MAYBE_DEFINE_CONTEXT;
    (last_rp_of_gen(gen))->n = FREELIST;
    FREELIST = (clear_fp(gen->fp))->n;
    (clear_fp(gen->fp))->n = NULL;
  }
  gen->a = (uintptr_t *)(&((clear_fp(gen->fp))->i));   /* beginning of data in first page */
  return;
}

Region
resetRegion(Region rAdr)
{
  Ro *r;
  debug(printf("[resetRegions..."));
  r = clearStatusBits(rAdr);
  resetGen(&(r->g0));
  free_lobjs(r->lobjs);
  r->lobjs = NULL;
  debug(printf("]\n"));
  return rAdr; /* We preserve rAdr and the status bits. */
}

/*-------------------------------------------------------------------------*
 * deallocateRegionsUntil:                                                 *
 *  It is called with rAddr=sp, which do not necessarily point at a region *
 *  description. It deallocates all regions that are placed under sp.      *
 * (notice: the stack is growing downwards                                 *
 *-------------------------------------------------------------------------*/
void
deallocateRegionsUntil(Context ctx, Region r)
{
  debug(printf("[deallocateRegionsUntil(r = %p, topr= %p)...\n", r, TOP_REGION));
  r = clearStatusBits(r);
  while (TOP_REGION && r >= TOP_REGION)
    {
      debug(printf("r: %p, top region %p\n",r,TOP_REGION));
      deallocateRegion(ctx);
    }
  debug(printf("]\n"));
  return;
}
