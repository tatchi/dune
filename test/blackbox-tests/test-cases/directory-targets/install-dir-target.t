Allow directories to be installable

  $ cat >dune-project <<EOF
  > (lang dune 3.0)
  > (package (name foo))
  > (using directory-targets 0.1)
  > EOF

  $ cat >dune <<EOF
  > (install
  >  (dirs rules/bar)
  >  (section share))
  > EOF

  $ mkdir rules
  $ cat >rules/dune <<EOF
  > (rule
  >  (target (dir bar))
  >  (action (bash "mkdir bar && touch bar/{x,y,z}")))
  > EOF

  $ dune build foo.install
  $ cat _build/default/foo.install
  lib: [
    "_build/install/default/lib/foo/META"
    "_build/install/default/lib/foo/dune-package"
  ]
