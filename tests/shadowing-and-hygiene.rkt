#lang racket/base

(require (except-in rackunit fail)
         "../main.rkt")

;; Regresssion tests for problems caused by shadowing, in case the identifier
;; tables used in various compiler passes fail to distinguish bindings of the same name.

;; This caused a compile-time infinite loop in constant folding.
(defrel (uh-o ls)
  (fresh (m)
    (== ls `(,m)) ;; substitution maps ls -> (list m)
    (fresh (ls)
      (== ls m)   ;; ls bound, m unbound, so bind m -> ls
      (uh-o m)))) ;; so now inlining chases m -> ls -> (list m) -> (list ls) -> (list (list m)) -> ...

;; This caused a runtime infinite loop due to a cyclic term, created because of an
;; improperly skipped occurs check.
(defrel (r y)
  (fresh (x y z)
    (== x (list y))
    (fresh (x)
      (== x 2)) ;; trick the occurs check pass into thinking x holds a constant
    (== y x) ;; skipping occurs check here creates a cycle
    (r2 x))) ;; pass term with cycle into r2 to diverge in unification
(defrel (r2 c)
  (fresh (z)
    (== c (list z))))
(check-equal?
 (run 1 (q) (r q))
 '())

;; Previously constant folding conflated the two `x`s, replacing the first macro-generated
;; unify with `succeed` and producing a result of 1 for this query.
(define-syntax m
  (goal-macro
    (syntax-rules ()
      [(_ a b)
       (fresh (x)
         (== a x)
         (== b x))])))
(check-equal?
 (run 1 (x) (m x 2) (== x 1))
 '())

;; Previously constant folding conflated the two `x`s, resulting in a spurious occurs-check failure.
(check-equal?
 (run 1 (x) (m (list x) (list x)))
 '(_.0))