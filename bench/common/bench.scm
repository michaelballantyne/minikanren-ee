(define complex-countdown3
  '(((lambda (w) (w w))
     (lambda (f)
       (lambda (n)
         ((lambda (id)
            ((n (lambda (_)
                  ((f f) (lambda (f)
                           (lambda (x)
                             (((n (lambda (g)
                                    (lambda (h)
                                      (h (g f)))))
                               (lambda (u) x))
                              id))))))
             id))
          (lambda (f) f)))))
    (lambda (f) (lambda (x) (f (f (f x)))))))

(define complex-countdown2
  '(((lambda (w) (w w))
     (lambda (f)
       (lambda (n)
         ((lambda (id)
            ((n (lambda (_)
                  ((f f) (lambda (f)
                           (lambda (x)
                             (((n (lambda (g)
                                    (lambda (h)
                                      (h (g f)))))
                               (lambda (u) x))
                              id))))))
             id))
          (lambda (f) f)))))
    (lambda (f) (lambda (x) (f (f x))))))

(define (logo-hard-program)
  (let ([N68 (build-num 68)])
    (run 9 (b q r) (logo N68 b q r) (>1o q))))

(module+ main

  (benchmark-suite "numbers"
    ["logo-hard" (logo-hard-program)])

  (benchmark-suite "all-in-fd"
    ["all-in-fd" (all-in-fd)])

  (benchmark-suite "four-fours"
    ["256" (four-fours 256)])

  (benchmark-suite "test fact"
    ["slow fact 6 = 720" (slow-fact-6-720)])

  (benchmark-suite "oxford artifact"
    ["love in 9900 ways" (love-in-9900-ways)]
    ["four-thrines-small" (four-thrines)]
    #;["twine-in-standard" (twine-slow)]
    ["dynamic-then-lexical-3-expressions" (dynamic-then-lexical-3-expressions)]
    ["lexical-then-dynamic-3-expressions" (lexical-then-dynamic-3-expressions)]
    ["append-backward-and-small-synthesis" (append-backward-and-small-synthesis)]
    #;["scheme-in-scheme-quine-with-quasiquote" (scheme-in-scheme-quine-with-quasiquote)])

  (benchmark-suite "relational graph coloring"
    #;["color middle earth" (color-middle-earth)]
    ["ways to color iberia" (ways-to-color-iberia)])

  (benchmark-suite "orchid graph coloring"
    ["color kazakhstan" (do-kazakhstan)])

  (benchmark-suite "simple interp"
    ["complex-countdown 2" (run 1 (q) (full:evalo complex-countdown2 q))])

  (benchmark-suite "simple matche-interp"
    ["unoptimized-matche-interp" (unoptimized-matche-interp)])

  (benchmark-suite "full interp"
    ["complex-countdown 2" (run 1 (q) (full:evalo complex-countdown2 q))]
    ["1 real quine" (run 4 (q) (full:evalo q q))]))

(module+ test
  (require rackunit)

  (check-equal?
   (logo-hard-program)
   '((() (_.0 _.1 . _.2) (0 0 1 0 0 0 1))
     ((1) (_.0 _.1 . _.2) (1 1 0 0 0 0 1))
     ((0 1) (0 1 1) (0 0 1))
     ((1 1) (1 1) (1 0 0 1 0 1))
     ((0 0 1) (1 1) (0 0 1))
     ((0 0 0 1) (0 1) (0 0 1))
     ((1 0 1) (0 1) (1 1 0 1 0 1))
     ((0 1 1) (0 1) (0 0 0 0 0 1))
     ((1 1 1) (0 1) (1 1 0 0 1))))

  (check-equal?
   (run 1 (q) (simple:evalo '((lambda (x) x) (lambda (y) y)) q))
   '((closure y y ())))

  (check-equal?
   (unoptimized-matche-interp)
   (optimized-matche-interp))

  )
