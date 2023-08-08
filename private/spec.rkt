#lang racket/base

(provide (all-defined-out)
         (for-syntax (all-defined-out)))

(require syntax-spec
         (for-syntax racket/base
                     syntax/parse
                     (only-in ee-lib lookup)))

;; TODO: should build in support to syntax-spec
(begin-for-syntax
  (define-syntax-class boolean/c
    (pattern (~or #t #f)))
  (define-syntax-class string/c
    (pattern s:string))

  (define (maybe-interposition form-id ctx-stx)
    (let ([interposition-id (datum->syntax ctx-stx (syntax-e form-id))])
      (if (lookup interposition-id (lambda (v) #t))
          interposition-id
          form-id))))

(syntax-spec
 (binding-class term-variable #:description "miniKanren term variable")
 (binding-class relation-name #:description "miniKanren relation name")
  
 (extension-class term-macro
                  #:binding-space mk)
 (extension-class goal-macro
                  #:binding-space mk)
  
 (nonterminal quoted
   #:description "quoted value"
   s:id
   n:number
   s:string/c
   b:boolean/c
   ())

 (nonterminal term
   #:description "miniKanren term"
   #:bind-literal-set term-literals
   #:allow-extension term-macro

   (#%lv-ref x:term-variable)
   (rkt-term e:racket-expr)
   ((~literal quote) t:quoted)
   ((~literal cons) t1:term t2:term)

   ;; TODO: officially supported way of doing these matches
   (~> x:id               
       #:when (lookup #'x (binding-class-predicate term-variable))
       #:with #%lv-ref (maybe-interposition #'#%lv-ref this-syntax)
       #'(#%lv-ref x))
   (~> x:id
         ;; TODO: this doesn't work to detect racket-vars. They don't have a syntax-local-value.
         ;; See ee-lib identifier-has-binding? comments for more discussion on difficulties.
         ;; for now require explicity rkt-term.
         ;; #:when (lookup #'x (binding-class-predicate racket-var))
         #'(rkt-term x))
   (~> (~or lit:number lit:string lit:boolean)
       #'(quote lit)))

 (nonterminal goal
   #:description "miniKanren goal"
   #:bind-literal-set goal-literals
   #:allow-extension goal-macro

   ;; TODO: rename these to the more standard succeed and fail
   success
   failure
    
   (symbolo t:term)
   (numbero t:term)
   (stringo t:term)
    
   (== t1:term t2:term)
   (=/= t1:term t2:term)
   (absento t1:term t2:term)

   (disj g1:goal g2:goal)
   (conj g1:goal g2:goal)
  
   (fresh (x:term-variable ...) b:goal)
   #:binding {(bind x) b}

   ;; TODO: final language should have project and goal-expression, not
   ;; apply-relation and relation.
   (apply-relation e:racket-expr t:term ...)
   #;(project (x:term-variable ...) e:racket-expr ...)

   (#%rel-app r:relation-name t:term ...+)
    
   (~> (r:id t ...)
       ;; TODO: this guard didn't work here, not sure why
       ;; #:when (lookup #'x (binding-class-predicate relation-name))
       #:with #%rel-app (maybe-interposition #'#%rel-app this-syntax)
       #'(#%rel-app r t ...)))

 (nonterminal ir-relation
   (ir-rel (x:term-variable ...) g:goal)))