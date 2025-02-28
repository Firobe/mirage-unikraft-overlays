# mirage-unikraft-overlays

Temporary opam repo for all mirage-unikraft packages.

To test:
```
$ opam switch create test 5.3.0
$ opam repo add mirage-unikraft-overlays https://github.com/Firobe/mirage-unikraft-overlays.git
$ opam install mirage ocaml-unikraft-backend-qemu ocaml-unikraft-x86_64
$ mirage configure -t qemu
$ make
```
