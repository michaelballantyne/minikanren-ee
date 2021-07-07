#lang racket/base

; This module defines the embedded expander and compiler for the
; core language.
;
; `define-goal-macro` and define-term-macro allow sugar definitions.
;

(require
  ee-lib/define
  syntax/parse/define
  racket/math
  (prefix-in mk: minikanren)
  "forms.rkt"
  "runtime.rkt"
  (for-syntax
   syntax/stx
   racket/syntax
   syntax/id-table
   ee-lib
   racket/base
   syntax/parse
   racket/generic
   "expand.rkt"
   (only-in syntax/parse [define/syntax-parse def/stx])
   "env-rep.rkt"
   "syntax-classes.rkt"))

(provide run run* relation define-relation
         (rename-out [define-relation defrel])
         quote cons #%term-datum #%lv-ref
         absento symbolo stringo numbero =/= ==
         conj disj fresh #%rel-app
         #%rkt-ref apply-relation rkt-term
         define-goal-macro define-term-macro
         mk-value? relation-value?
         relation-code
         (for-syntax gen:term-macro gen:goal-macro))

; Syntax

(begin-for-syntax

  ; Expander

  (define/hygienic (expand-relation stx) #:expression
    (syntax-parse stx
      #:literals (relation)
      [(relation (x:id ...) g)
       (with-scope sc
         (def/stx (x^ ...) (bind-logic-vars! (add-scope #'(x ...) sc)))
         (def/stx g^ (expand-goal (add-scope #'g sc)))
         (qstx/rc (relation (x^ ...) g^)))]))
  
  ; Optimization pass
  
  (define (build-conj l)
    (when (null? l) (error 'build-conj "requires at least one item"))
    (let recur ([l (reverse l)])
      (if (= (length l) 1)
          (car l)
          #`(conj
             #,(recur (cdr l))
             #,(car l)))))

  (define (reorder-conjunction stx)
    (define lvars '())
    (define constraints '())
    (define others '())
    (let recur ([stx stx])
      (syntax-parse stx #:literals (conj fresh ==)
        [(conj g1 g2) (recur #'g1) (recur #'g2)]
        [(fresh (x:id ...) g)
         (set! lvars (cons (syntax->list #'(x ...)) lvars))
         (recur #'g)]
        [(~or (c:unary-constraint t)
              (c:binary-constraint t1 t2))
         (set! constraints (cons this-syntax constraints))]
        [_ (set! others (cons (reorder-conjunctions this-syntax) others))]))
    (let ([lvars (apply append (reverse lvars))]
          [body (build-conj (append (reverse constraints) (reverse others)))])
      (if (null? lvars)
          body
          #`(fresh #,lvars #,body))))
  
  (define (reorder-conjunctions stx)
    (define (maybe-reorder stx)
      (syntax-parse stx
        #:literals (conj fresh)
        [((~or conj fresh) . _) (reorder-conjunction this-syntax)]
        [_ this-syntax]))
    (map-transform maybe-reorder stx))

  
  ; Code generation
  
  (define compiled-names (make-free-id-table))

  (define constraint-impls
    (make-free-id-table
     (hash #'symbolo #'mk:symbolo
           #'stringo #'mk:stringo
           #'numbero #'mk:numbero
           #'== #'mk:==
           #'=/= #'mk:=/=
           #'absento #'mk:absento)))

  (define expanded-relation-code (make-free-id-table))

  (define/hygienic (generate-relation stx) #:expression
    (syntax-parse stx
      [(_ (x^ ...) g^)
       #`(relation-value (lambda (x^ ...) #,(generate-code #'g^)))]))
  
  (define/hygienic (generate-code stx) #:expression
    (syntax-parse stx
      #:literal-sets (mk-literals)
      #:literals (quote cons)
      ; core terms
      [(#%lv-ref v:id)
       #'v]
      [(rkt-term e)
       #'(check-term e #'e)]
      [(#%term-datum l:number)
       #'(quote l)]
      [(#%term-datum l:string)
       #'(quote l)]
      [(#%term-datum l:boolean)
       #'(quote l)]
      [(quote d)
       #'(quote d)]
      [(cons t1:term/c t2:term/c)
       #`(cons #,(generate-code #'t1) #,(generate-code #'t2))]
      
      ; core goals
      [(c:unary-constraint t)
       (def/stx c^ (free-id-table-ref constraint-impls #'c))
       #`(c^ #,(generate-code #'t))]
      [(c:binary-constraint t1 t2)
       (def/stx c^ (free-id-table-ref constraint-impls #'c))
       #`(c^ #,(generate-code #'t1) #,(generate-code #'t2))]
      [(#%rel-app n:id t ...)
       (def/stx n^ (free-id-table-ref compiled-names #'n))
       #`((relation-value-proc n^) #,@ (stx-map generate-code #'(t ...)))]
      [(disj g1 g2)
       #`(mk:conde
          [#,(generate-code #'g1)]
          [#,(generate-code #'g2)])]
      [(conj g1 g2)
       #`(mk:fresh ()
                   #,(generate-code #'g1)
                   #,(generate-code #'g2))]
      [(fresh (x:id ...) g)
       #`(mk:fresh (x ...) #,(generate-code #'g))]
      [(apply-relation e t ...)
       #`((relation-value-proc (check-relation e #'e))
          #,@(stx-map generate-code #'(t ...)))]
      
      )))

; run, run*, and define-relation are the interface with Racket

(define-syntax run
  (syntax-parser
    [(~describe
      "(run <numeric-expr> (<id> ...+) <goal>)"
      (_ n:expr b:bindings+/c g:goal/c))
     (with-scope sc
       (def/stx (x^ ...) (bind-logic-vars! (add-scope #'(b.x ...) sc)))
       (define expanded (expand-goal (add-scope #'g sc)))
       (define reordered (reorder-conjunctions expanded))
       (define compiled (generate-code reordered))
       #`(mk:run (check-natural n #'n) (x^ ...) #,compiled))]))

(define-syntax run*
  (syntax-parser
    [(~describe
      "(run* (<id> ...+) <goal>)"
      (_ b:bindings+/c g:goal/c))
     (with-scope sc
       (def/stx (x^ ...) (bind-logic-vars! (add-scope #'(b.x ...) sc)))
       (define expanded (expand-goal (add-scope #'g sc)))
       (define reordered (reorder-conjunctions expanded))
       (define compiled (generate-code reordered))
       #`(mk:run* (x^ ...) #,compiled))]))

(define-syntax relation
  (syntax-parser
    [(~describe
      "(relation (<id> ...) <goal>)"
      (_ b:bindings/c g:goal/c))
     ; some awkwardness to let us capture the expanded and optimized mk code
     (define expanded (expand-relation this-syntax))
     (define reordered (reorder-conjunctions expanded))
     (define name (syntax-property this-syntax 'name))
     (when name
       (free-id-table-set! expanded-relation-code
                           name
                           reordered))
     (generate-relation reordered)]))

(define-syntax define-relation
  (syntax-parser
    [(~describe
      "(define-relation (<name:id> <arg:id> ...) <goal>)"
      (_ h:define-header/c (~or* (~seq g:goal/c) (~seq ~! (~fail "body should be a single goal")))))
     #`(begin
         ; Bind static information for expansion
         (define-syntax h.name
           (relation-binding-rep #,(length (syntax->list #'(h.v ...)))))
         ; Binding for the the compiled function.
         ; Expansion of `relation` expands and compiles the
         ; body in the definition context's second pass.
         (define tmp #,(syntax-property
                        #'(relation (h.v ...) g)
                        'name #'h.name))
         (begin-for-syntax
           (free-id-table-set! compiled-names #'h.name #'tmp)))]))

(define-syntax-rule
  (define-goal-macro m f)
  (define-syntax m (goal-macro-rep f)))

(define-syntax-rule
  (define-term-macro m f)
  (define-syntax m (term-macro-rep f)))

(define-syntax relation-code
  (syntax-parser
    [(_ name)
     (if (eq? 'expression (syntax-local-context))
         (let ()
           (when (not (lookup #'name relation-binding?))
             (raise-syntax-error #f "not bound to a relation" #'name))
           (define code (free-id-table-ref expanded-relation-code #'name #f))
           (when (not code)
             (error 'relation-code "can only access code of relations defined in the current module"))
           #`#'#,code)
         #'(#%expression (relation-code name)))]))