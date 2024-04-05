# Lisp-Zig (Tested on Windows only)

## Keywords

- print
```
print arg

(print "foobar")

> "foobar"
```

- define
```
define name value

(define pi 3.14)
(print pi)

> 3.14
```

- map
```
map function list

(map (lambda (a) (+ a 10)) (list 1 2 3 4 5))

> (11 12 13 14 15)
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
