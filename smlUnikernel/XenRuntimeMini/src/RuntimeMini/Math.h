/*----------------------------------------------------------------*
 *                         Math                                   *
 *----------------------------------------------------------------*/

#ifndef __MATH_H
#define __MATH_H

#include "Flags.h"
#include "Tagging.h"
#include "String.h"

/*----------------------------------------------------------------*
 *                       Integer operations.                      *
 *----------------------------------------------------------------*/

#define muliML(x,y,d)  ((d)=(x)*(y))
#define addiML(x,y,d)  ((d)=(x)+(y))
#define subiML(x,y,d)  ((d)=(x)-(y))

#define  minDefine(A,B) ((A<B)?A:B)

#define Max_Int 9223372036854775807
#define Min_Int (-9223372036854775807-1)
#define Max_Int_d 9223372036854775807.0
#define Min_Int_d -9223372036854775808.0
#define val_precision 64

/*----------------------------------------------------------------*
 *        Prototypes for external and internal functions.         *
 *----------------------------------------------------------------*/
ssize_t max_fixed_int(ssize_t dummy);
ssize_t min_fixed_int(ssize_t dummy);
ssize_t precision(ssize_t dummy);
ssize_t __div_int31(Context ctx, ssize_t x, ssize_t y, uintptr_t exn);
ssize_t __div_int63(Context ctx, ssize_t x, ssize_t y, uintptr_t exn);
ssize_t __mod_int31(Context ctx, ssize_t x, ssize_t y, uintptr_t exn);
ssize_t __mod_int63(Context ctx, ssize_t x, ssize_t y, uintptr_t exn);
ssize_t __quot_int31(ssize_t x, ssize_t y);
ssize_t __quot_int63(ssize_t x, ssize_t y);
ssize_t __rem_int31(ssize_t x, ssize_t y);
ssize_t __rem_int63(ssize_t x, ssize_t y);

size_t __div_word31(Context ctx, size_t x, size_t y, uintptr_t exn);
size_t __div_word63(Context ctx, size_t x, size_t y, uintptr_t exn);
size_t __mod_word31(Context ctx, size_t x, size_t y, uintptr_t exn);
size_t __mod_word63(Context ctx, size_t x, size_t y, uintptr_t exn);

ssize_t realInt(ssize_t d, ssize_t x);
ssize_t floorFloat(Context ctx, ssize_t f);
ssize_t ceilFloat(Context ctx, ssize_t f);
ssize_t roundFloat(ssize_t f);
ssize_t truncFloat(Context ctx, ssize_t f);
ssize_t realFloor(ssize_t d, ssize_t x);
ssize_t realCeil(ssize_t d, ssize_t x);
ssize_t realTrunc(ssize_t d, ssize_t x);
ssize_t realRound(ssize_t d, ssize_t x);
ssize_t divFloat(ssize_t d, ssize_t x, ssize_t y);
ssize_t remFloat(ssize_t d, ssize_t x, ssize_t y);

ssize_t sqrtFloat(ssize_t d, ssize_t s);
ssize_t sinFloat(ssize_t d, ssize_t s);
ssize_t cosFloat(ssize_t d, ssize_t s);
ssize_t atanFloat(ssize_t d, ssize_t s);
ssize_t asinFloat(ssize_t d, ssize_t s);
ssize_t acosFloat(ssize_t d, ssize_t s);
ssize_t atan2Float(ssize_t d, ssize_t y, ssize_t x);
ssize_t expFloat(ssize_t d, ssize_t s);
ssize_t powFloat(ssize_t d, ssize_t x, ssize_t y);
ssize_t lnFloat(ssize_t d, ssize_t s);
ssize_t sinhFloat(ssize_t d, ssize_t s);
ssize_t coshFloat(ssize_t d, ssize_t s);
ssize_t tanhFloat(ssize_t d, ssize_t s);
ssize_t isnanFloat(ssize_t s);
ssize_t posInfFloat(ssize_t d);
ssize_t negInfFloat(ssize_t d);

void floatSetRoundingMode(ssize_t m); // 0:TONEAREST, 1: DOWNWARD, 2: UPWARD, 3: ZERO
ssize_t floatGetRoundingMode(void);

String REG_POLY_FUN_HDR(stringOfFloat,Region rAddr, size_t f);
String REG_POLY_FUN_HDR(generalStringOfFloat,Region rAddr, String str, size_t f);

/* For basislib Math structure */
ssize_t sml_sqrt(ssize_t d, ssize_t s);

/* For basislib PackReal{Big,Little} structures */
String REG_POLY_FUN_HDR(sml_real_to_bytes,Region rAddr, size_t f);
size_t sml_bytes_to_real(size_t d, String s);

void printReal(size_t f);

ssize_t __div_int32ub(Context ctx, ssize_t x, ssize_t y, uintptr_t exn);
ssize_t __div_int64ub(Context ctx, ssize_t x, ssize_t y, uintptr_t exn);
ssize_t __mod_int32ub(Context ctx, ssize_t x, ssize_t y, uintptr_t exn);
ssize_t __mod_int64ub(Context ctx, ssize_t x, ssize_t y, uintptr_t exn);
ssize_t __quot_int32ub(ssize_t x, ssize_t y);
ssize_t __quot_int64ub(ssize_t x, ssize_t y);
ssize_t __rem_int32ub(ssize_t x, ssize_t y);
ssize_t __rem_int64ub(ssize_t x, ssize_t y);

size_t __div_word32ub(Context ctx, size_t x, size_t y, uintptr_t exn);
size_t __div_word64ub(Context ctx, size_t x, size_t y, uintptr_t exn);
size_t __mod_word32ub(Context ctx, size_t x, size_t y, uintptr_t exn);
size_t __mod_word64ub(Context ctx, size_t x, size_t y, uintptr_t exn);

#endif /*__MATH_H*/
