#lang racket



;; Staging simple relations (vs unstaged)
(require "applications/replicate.rkt")
(require "applications/power.rkt")

;; Staging the evalo relation: write append as a function, compile as relation (thus faster flexible functions)
;;
(require "synth-task-macros.rkt") ;; just the running backwards
(require "interpreter/basics.rkt") ;; get append examples
;; --(require "../small-interp/staged.rkt")
;; -- (require "../small-interp/unstaged.rkt")
;; sub-block: eval-like relations on program-like arguments
(require "applications/grammars.rkt")

;; Staging the evalo relation running on (eval <program-text>) (thus faster eval functions in particular)
(require "applications/or-lang-interp.rkt")
(require "applications/proof.rkt")
(require "applications/parsing-with-derivatives.rkt")
(require "applications/double-eval.rkt") ;; quines w/quasiquotes

;; Synthesis w/ground context
;; When we rely on a built-in primitive implemented in the object 'eval', you get a neat multi-level compiled-interpreted interaction
(require "applications/map.rkt") ;; the example we wrote just for the purpose
(require "synth-task-macros.rkt") ;; synthesize part of append from context
