# mirage-unikraft-overlays

Temporary opam repo for all mirage-unikraft packages.

To test:
```
$ opam repo add mirage-unikraft-overlays https://github.com/Firobe/mirage-unikraft-overlays.git
$ opam pin -ny 'https://github.com/shym/ocaml-unikraft.git#dev'
$ opam install mirage
$ mirage configure -t qemu
$ make
```
