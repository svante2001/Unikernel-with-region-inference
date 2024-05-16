/*----------------------------------------------------------------*
 *                         Regions                                *
 *----------------------------------------------------------------*/
#ifndef REGION_H
#define REGION_H

// #include <stdint.h>
#include <mini-os/console.h>
#include <mini-os/xmalloc.h>
#include <mini-os/types.h>
#include "Flags.h"
#define UINTPTR_MAX 18446744073709551615UL

/*
Overview
--------

This module defines the runtime representation of regions.

There are two types of regions: {\em finite} and {\em infinite}.
A region is finite if its (finite) size has been found at compile
time and to which at most one object will ever be written.
Otherwise it is infinite.

The runtime representation of a region depends on
  (a) whether the region is finite or infinite;
  (b) whether profiling is turned on or not.

We describe each of the four possibilities in turn.

(a) Finite region of size n bytes (n%4==0) -- meaning that
    every object that may be stored in the region has size
    at most n bytes:
    (i)  without profiling, the region is n/4 words on the
         runtime stack;
    (ii) with profiling, the region is represented by first
         pushing a region descriptor (see below) on the stack,
         then pushing an object descriptor (see below) on the stack and
         then reserving space for the object; the region descriptors
         of finite regions are linked together which the profiler
         can traverse.
(b) Infinite region -- meaning that the region can contain objects
    of different sizes.
    (i)  without profiling, the region is represented by a
         {\em region descriptor} on the stack. The region descriptor
         points to the beginning and the end of a linked list of
         fixed size region pages (see below).
    (ii) with profiling, the representation is the same as without
         profiling, except that the region descriptor contains more
         fields for profiling statistics.

A *region page* consists of a header and an array of words that
can be used for allocation.  The header takes up
HEADER_WORDS_IN_REGION_PAGE words, while the number of words
that can be allocated is ALLOCATABLE_WORDS_IN_REGION_PAGE.
Thus, a region page takes up
HEADER_WORDS_IN_REGION_PAGE + ALLOCATABLE_WORDS_IN_REGION_PAGE
words in all.

*/

/*
 * Number of words that can be allocated in each regionpage and number
 * of words in the header part of each region page.
 *
 * HEADER_WORDS_IN_REGION_PAGE + ALLOCATABLE_WORDS_IN_REGION_PAGE must
 * be a power of two (default was 1Kb, but is now 8k). Used by GC, for
 * instance.
 *
 * Remember also to change the function 'size_region_page' in
 * src/Compiler/Backend/BackendInfo.sml
 */

#define REGION_PAGE_SIZE_BYTES (8*1024)
#define HEADER_WORDS_IN_REGION_PAGE 2
#define WORD_SIZE_BYTES 8
#define ALLOCATABLE_WORDS_IN_REGION_PAGE ((REGION_PAGE_SIZE_BYTES / WORD_SIZE_BYTES) - HEADER_WORDS_IN_REGION_PAGE)

typedef struct rp {
  struct rp *n;                   /* NULL or pointer to next page. */
  struct gen *gen;                /* Pointer back to generation. Used by GC. */
  uintptr_t i[ALLOCATABLE_WORDS_IN_REGION_PAGE];  /* space for data */
} Rp;

#define is_rp_aligned(rp)  (((rp) & (sizeof(Rp)-1)) == 0)

// [rpBoundary(a)] returns the boundary for the last region page
// associated with the region for which a is the allocation
// pointer. The boundary is defined as a pointer to the first word
// following the last page. Because a may point to the boundary, we
// subtract one (byte) from a so that we make sure that it is a
// pointer into the page (initially, it points past the
// next-pointer)...

#define rpBoundary(a)      ((uintptr_t *)(((((unsigned long)a)-1) | (sizeof(Rp)-1))+1))
#define last_rp_of_gen(g)  ((Rp*)(((unsigned long)(((Gen*)g)->a)-1) & (~(sizeof(Rp)-1))))

/* Free pages are kept in a free list. When the free list becomes
 * empty and more space is required, the runtime system calls the
 * operating system function malloc in order to get space for a number
 * (here 30) of fresh region pages: */

/* Size of allocated space in each SBRK-call. */
#define BYTES_ALLOC_BY_SBRK REGION_PAGE_BAG_SIZE*sizeof(Rp)

#define clear_tospace_bit(p)  (p)

/* Region large objects idea: Modify the region based memory model so
 * that each ``infinite region'' (i.e., a region for which the size of
 * the region is not determined statically) contains a list of objects
 * allocated using the C library function `malloc'. When a region is
 * deallocated or reset, the list of malloced objects in the region
 * are freed using the C library function `free'. The major reason for
 * large object support is to gain better indexing properties for
 * arrays and vectors. Without support for large objects, arrays and
 * vectors must be split up in chunks. With strings implemented as
 * linked list of pages, indexing in large character arrays takes time
 * which is linear in the index parameter and with word-vectors and
 * word-arrays being implemented as a tree structure, indexing in
 * word-vectors and word-arrays take time which is logarithmic in the
 * index parameter.  -- mael 2001-09-13 */

/* For tag-free garbage collection of pairs, triples, and refs, we
 * make sure that large objects are aligned on 1K boundaries, which
 * makes it possible to determine if a pointer points into the stack,
 * constants in data space, a region in from-space, or a region in
 * to-space. The orig pointer points back to the memory allocated by
 * malloc (which holds the large object). */

typedef struct lobjs {
  struct lobjs* next;     // pointer to next large object or NULL
  uintptr_t value;        // a large object; inlined to avoid pointer-indirection
} Lobjs;

#define clear_lobj_bit(p)     (p)
#define set_lobj_bit(p)       (p)

typedef struct gen {
  uintptr_t * a;  /* Pointer to first unused word in the newest region
                     page of the region. This value is also used for
                     finding the page boundary. */
  Rp *fp;   /* Pointer to the oldest (first allocated) page of the
               region.  The beginning of the newest page of the region
               can be calculated from a using page alignment
               properties.  Thus the region descriptor gives direct
               access to both the first and the last region page of
               the region. This makes it possible to deallocate the
               entire region in constant time, by appending it to the
               free list. */
} Gen;


/*
Region descriptors
------------------
ro is the type of region descriptors. Region descriptors are kept on
the stack and are linked together so that one can traverse the stack
of regions (for profiling and for popping of regions when exceptions
are raised) */

/* Important: don't mess with Ro unless you also redefine the constants below. */
#define offsetG0InRo 0
typedef struct ro {
  Gen g0;              /* g0 is the only generation when ordinary GC is used. g0
                          is the youngest generation when using generational GC. */
  struct ro * p;       // Pointer to previous region descriptor.
  Lobjs *lobjs;        // large objects: a list of malloced memory in each region
} Ro;

typedef Ro* Region;
#define MIN_NO_OF_PAGES_IN_REGION 1
#define freeInRegion(rAddr)   (rpBoundary(rAddr->g0.a) - rAddr->g0.a) /* Returns freespace in words. */
#define descRo_a(rAddr,w) (rAddr->g0.a = rAddr->g0.a - w) /* Used in IO.inputStream */

// Notice, that the generation g0 is always used no matter what mode
// the compiler is in (no gc, gc or gen gc). The generation g1 is only
// used when generational gc is enabled. It is thus always possible to
// write r->g0, whereas r->g1 makes sense only when generational gc is
// enabled.
//
// We do not explicitly set the generation 0 bit when allocating a
// region because the bit is 0 by default, that is, set_gen_0 is not
// used in Region.c

#define is_gen_1(gen)            (0) /* Only g0 exists if no GC enabled */
#define clear_fp(fp)     (fp)

#define get_ro_from_gen(gen)    ( (Ro*)(((uintptr_t)(&(gen)))-offsetG0InRo) )

// ## Region polymorphism
//
// Regions can be passed to functions at runtime. The machine value
// that represents a region in this situation is a 64 bit word. The
// least significant bit is 1 iff the region is infinite. The second
// least significant bit is 1 iff stores into the region should be
// preceded by emptying the region of values before storing the new
// value (this is called storing a value at the _bottom_ of the region
// and is useful for, among other things, tail recursion).

// Operations on the two least significant
// bits in a region pointer.
// C ~ 1100, D ~ 1101, E ~ 1110 og F ~ 1111.

#define setInfiniteBit(x)   ((x) | 0x1)
#define clearInfiniteBit(x) ((x) & (UINTPTR_MAX ^ 0x1))

#define setAtbotBit(x)      ((x) | 0x2)
#define clearAtbotBit(x)    ((x) & (UINTPTR_MAX ^ 0x2))

#define setStatusBits(x)    ((x) | 0x3)
#define clearStatusBits(x)  ((Region)(((uintptr_t)(x)) & (UINTPTR_MAX ^ 0x3)))

#define is_inf_and_atbot(x) ((((uintptr_t)(x)) & 0x3)==0x3)
#define is_inf(x)           ((((uintptr_t)(x)) & 0x1)==0x1)
#define is_atbot(x)         ((((uintptr_t)(x)) & 0x2)==0x2)

// ## Contexts
//
// Evaluation happens in a context, meaning that, during evaluation,
// access to the top-most region, the current exception handler, and
// other stateful information can be accessed through the context. A
// pointer to the context is held in a designated register during
// evaluation. Because evaluation happens in a context, multiple
// threads can execute in parallel in different contexts, which has
// many benefits.

typedef struct {
  Region topregion;             // toplevel region
  void *exnptr;                 // pointer to toplevel handler
  long int uncaught_exnname;    // > 0 implies uncaught exception
} context;

typedef context* Context;

/*----------------------------------------------------------------*
 * Type of freelist and top-level region                          *
 *----------------------------------------------------------------*/

extern Rp * global_freelist;

#define MAYBE_DEFINE_CONTEXT
#define TOP_REGION   (ctx->topregion)
#define FREELIST     global_freelist
#define CHECK_CTX(x) ;

typedef size_t Protect;

/*----------------------------------------------------------------*
 *        Prototypes for external and internal functions.         *
 *----------------------------------------------------------------*/
Region allocateRegion(Context ctx, Region roAddr, Protect p);
void deallocateRegion(Context ctx);
void deallocateRegionsUntil(Context ctx, Region rAddr);

uintptr_t *alloc (Region r, size_t n);
// uintptr_t *__allocate (Region r, size_t n);
uintptr_t *alloc_new_page(Gen *gen);
void callSbrk(void);

uintptr_t *allocGen (Gen *gen, size_t n);

Region resetRegion(Region r);
// Region __resetRegion(Region r);
size_t NoOfPagesInRegion(Region r);
size_t NoOfPagesInGen(Gen* gen);

/*----------------------------------------------------------------*
 *        Declarations to support profiling                       *
 *----------------------------------------------------------------*/
#define notPP 0 /* Also used by GC */

void printTopRegInfo(void);
size_t size_free_list(void);
void pp_reg(Region r,  char *str);
void pp_gen(Gen *gen);
void chk_obj_in_gen(Gen *gen, uintptr_t *obj_ptr, char* s);

void free_lobjs(Lobjs* lobjs);

#endif /*REGION_H*/
