(* This structure declares values that must be initialised when the
 * system starts executing. The purpose is to allow the clients of
 * this structure to be discharged at link time; only files that are
 * safe (no side effects) can be discharged at link time. ME 1998-08-21 *)

structure Initial =
  struct
    infix - + * < =

    type int0 = int
    type word0 = word         (* used by WORD signature *)

    exception Fail of string
    val _ = prim("sml_setFailNumber", (Fail "hat" : exn, 1 : int)) : unit;

    (* Real structure *)
    local
      fun get_posInf () : real = prim ("posInfFloat", ())
      fun get_negInf () : real = prim ("negInfFloat", ())
      fun get_maxFinite () : real = prim("maxFiniteFloat", ())
    in
      val posInf = get_posInf()
      val negInf = get_negInf()
      val minPos = 0.5E~323
      val maxFinite : real = get_maxFinite()
      val minNormalPos = 0.22250738585072014E~307
    end

    (* Math structure *)
    local
      fun sqrt (r : real) : real = prim ("sqrtFloat", r)
      fun ln' (r : real) : real = prim ("lnFloat", r)
    in
      val ln10 = ln' 10.0
      val NaN = sqrt ~1.0
    end

    (* ByteTable and WordTable functors *)
    val bytetable_maxlen : int = 4 * 1024 * 1024 * 1024  (* 4Gb *)
    val wordtable_maxlen : int = 123456789*100 (* arbitrary chosen. *)

    (* Int structure. Integers are untagged (or tagged if GC is enabled),
     * and there is a limit to the size of immediate integers that the Kit
     * accepts. We should change the lexer such that it does not convert a
     * string representation of an integer constant into an internal
     * integer, as this makes the the kit dependent on the precision of
     * the compiler that we use to compile the Kit. *)

    type int0 = int

    local fun pow2 n : int63 = if n < 1 then 1 else 2 * pow2(n-1)
    in val maxInt63 : int63 = pow2 61 + (pow2 61 - 1)
       val minInt63 : int63 = ~maxInt63 - 1
    end

    local fun pow2 n : int64 = if n < 1 then 1 else 2 * pow2(n-1)
    in val maxInt64 : int64 = pow2 62 + (pow2 62 - 1)
       val minInt64 : int64 = ~maxInt64 - 1
    end

    fun op = (x: ''a, y: ''a): bool = prim ("=", (x, y))
    fun fromI63 (i:int63) : int = prim("__int63_to_int", i)
    fun fromI64 (i:int64) : int = prim("__int64_to_int", i)

    val precisionInt0 : int = prim("precision", 0)
    val (minInt0:int,maxInt0:int) =
        if precisionInt0 = 63 then (fromI63 minInt63, fromI63 maxInt63)
        else (fromI64 minInt64, fromI64 maxInt64)

  end
