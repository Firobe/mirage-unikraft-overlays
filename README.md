# mirage-unikraft-overlays

Temporary opam repo for all mirage-unikraft packages.

**Ensure you have `opam-monorepo` version 0.4.3 at least**

To test:
```
$ opam switch create test ocaml-base-compiler.5.3.0
$ opam repo add mirage-unikraft-overlays https://github.com/Firobe/mirage-unikraft-overlays.git
$ opam install mirage ocaml-unikraft-backend-qemu ocaml-unikraft-x86_64
$ mirage configure -t unikraft-qemu
$ make
```
