# Lisp-Zig (Tested on Windows only)

## Fucntions

- map
```
map function list

$ (map (lambda (a) (+ a 10)) (list 1 2 3 4 5))
> (11 12 13 14 15)
```
- print
```
print arg -> void

(print "foobar")

> "foobar"
```
- let
```
let binds body

(begin
    (let ((a 1) (b 2))
        (+ a b)
    )
)

> 3
```
