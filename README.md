# mirage-unikraft-overlays

Temporary opam repo for all mirage-unikraft packages.

To test:
```
$ opam switch create test ocaml-base-compiler.5.3.0
$ opam repo add mirage-unikraft-overlays https://github.com/Firobe/mirage-unikraft-overlays.git
$ opam install mirage ocaml-unikraft-backend-qemu ocaml-unikraft-x86_64
$ mirage configure -t unikraft-qemu
$ make
```

## Changes from published packages

- `ocaml-unikraft`
  - removed `dev-repo` as a work-around until
    [this bugfix for opam-monorepo](https://github.com/tarides/opam-monorepo/pull/415) is released
