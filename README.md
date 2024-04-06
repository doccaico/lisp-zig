# Lisp-Zig (Tested on Windows only)

Something like Lisp. I referred to [Lisp interpreter in Rust](https://vishpat.github.io/lisp-rs/) and [https://github.com/vishpat/lisp-rs](vishpat/lisp-rs). Thank you Vishal Patil.

## Zig version

```
// 2024/04/06
0.12.0-dev.3533+e5d900268
```

## Usage

```
$ zig run src\main.zig
```

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

- begin
```
begin element ...

(begin
    (define a 1)
    (define b 2)
    (+ a b)
)

> 3
```

- list
```
list element ...

(list 1 2 3 4 5)

> (1 2 3 4 5) 
```

- lambda
```
lambda args body

(define add (lambda (a b) (+ a b)))
(add 1 2)

> 3
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

- map
```
map function list

(map (lambda (a) (+ a 10)) (list 1 2 3 4 5))

> (11 12 13 14 15)
```

- filter
```
filter function list

(begin
    (define odd (lambda (v) (= 1 (% v 2))))
    (define l (list 1 2 3 4 5))
    (filter odd l)
)

> (1 3 5)
```

- reduce
```
reduce function list

(begin
    (define add (lambda (a b) (+ a b)))
    (define l (list 1 2 4 8 16 32))
    (reduce add l )
)

> 63
```

- range
```
range (start end stride)

(range 0 11)

>(0 1 2 3 4 5 6 7 8 9 10)

(range 0 11 2)

>(0 2 4 6 8 10)
```

- car
```
car list

(car (list 1 2 3))

>1
```

- cdr
```
cdr list

(car (list 1 2 3))

>(2 3)
```

- length
```
length list

(length (list 1 2 3))

>3
```

- null?
```
null? list

(null? (list 1 2 3 4 5))

>false

(null? (list))

>true
```
