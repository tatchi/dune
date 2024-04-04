Test exec --watch with a program that ignores sigterm.

  $ dune exec --watch ./foo.exe &
  Success, waiting for filesystem changes...
  1: before
  $ PID=$!

  $ ../wait-for-file.sh _build/done_flag

  $ sed -i -e 's/1: before/2: before/' foo.ml
  sed: foo.ml: in-place editing only works for regular files
  [1]

  $ ../wait-for-file.sh _build/done_flag
  Timeout waiting for file _build/done_flag
  [1]

Prevent the test from leaking the dune process.
  $ kill $PID
