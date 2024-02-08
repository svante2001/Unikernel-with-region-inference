Building the executable generated by the MDX stanza works when implicit
transitive dependencies are disabled.

  $ cat >dune-project <<EOF
  > (lang dune 3.0)
  > (using mdx 0.2)
  > (implicit_transitive_deps false)
  > EOF

  $ cat >dune <<EOF
  > (mdx)
  > EOF

  $ dune build
