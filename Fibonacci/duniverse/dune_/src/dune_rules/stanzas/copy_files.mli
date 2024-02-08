open Import

type t =
  { add_line_directive : bool
  ; alias : Alias.Name.t option
  ; mode : Rule.Mode.t
  ; enabled_if : Blang.t
  ; files : String_with_vars.t
  ; syntax_version : Dune_lang.Syntax.Version.t
  }

include Stanza.S with type t := t

val decode : t Dune_lang.Decoder.t
