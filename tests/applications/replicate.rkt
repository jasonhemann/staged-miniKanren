#lang racket/base

(require "../../main.rkt" "../../test-check.rkt")

;;
;; Original unstaged program
;;

;; Replicate every element of `l` `n` times to produce `res`
(defrel (replicate n l res)
  (conde
    [(== l '())
     (== res '())]
    [(fresh (a d rec-res)
       (== l (cons a d))
       (cons-n n a rec-res res)
       (replicate n d rec-res))]))

;; Add `n` copies of `v` to the front of `l` to produce `res`
(defrel (cons-n n v l res)
  (conde
    [(== n 'Z)
     (== l res)]
    [(fresh (n-1 rec-res)
       (== n `(S ,n-1))
       (== res (cons v rec-res))
       (cons-n n-1 v l rec-res))]))

(test
 (run 1 (q)
   (cons-n '(S (S (S Z))) 1 '(2 2 2 3 3 3) q))
 '((1 1 1 2 2 2 3 3 3)))

(test
 (run 1 (q)
   (replicate '(S (S (S Z))) '(1 2 3) q))
 '((1 1 1 2 2 2 3 3 3)))

(test
 (run 3 (q)
   (fresh (n-2)
     (replicate `(S (S ,n-2)) '(1 2 3) q)))
 '((1 1 2 2 3 3) (1 1 1 2 2 2 3 3 3) (1 1 1 1 2 2 2 2 3 3 3 3)))

(test
 (run 2 (n l)
   (fresh (n-2)
     (replicate n l '(1 1 1 2 2 2 3 3 3))))
 '(((S (S (S Z))) (1 2 3)) ((S Z) (1 1 1 2 2 2 3 3 3))))


;;
;; Equivalent MetaOCaml code (also in replicate.ml)
;;

;; let rec replicate_staged (n : peano) =
;;   .<let rec replicate_n l =
;;      match l with
;;      | [] -> []
;;      | a :: d -> .~(cons_n_staged n .<a>. .<(replicate_n d)>.)
;;    in
;;    replicate_n>.
;; 
;; let rec cons_n_staged (n : peano) (v : 'a code) (l : 'a list code) =
;;   match n with
;;   | Z -> l
;;   | S p -> .<.~v :: .~(cons_n_staged p v l)>.


;;
;; Staged
;;


(defrel-partial/staged (replicate/staged rep [n] [l res])
  (gather
   (conde
     [(== l '())
      (== res '())]
     [(fresh (a d rec-res)
        (== l (cons a d))
        (cons-n/staged n a rec-res res)
        (later (finish-apply rep replicate/staged d rec-res)))])))

(defrel/staged (cons-n/staged n v l res)
  (fallback
   (conde
     [(== n 'Z)
      (== l res)]
     [(fresh (n-1 rec-res)
        (== n `(S ,n-1))
        (== res (cons v rec-res))
        (cons-n/staged n-1 v l rec-res))])))


;; Runtime-only test of the cons-n helper
(test
 (run 1 (q)
   (cons-n/staged '(S (S (S Z))) 1 '(2 2 2 3 3 3) q))
 '((1 1 1 2 2 2 3 3 3)))

;; Runtime-only test of replicate
(test
 (run 1 (q)
   (fresh (rep)
     (partial-apply rep replicate/staged '(S (S (S Z))))
     (finish-apply rep replicate/staged '(1 2 3) q)))
 '((1 1 1 2 2 2 3 3 3)))

;; Basic staged
(test
 (run 1 (q)
   (staged
    (fresh (rep)
      (specialize-partial-apply rep replicate/staged '(S (S (S Z))))
      (later (finish-apply rep replicate/staged '(1 2 3) q)))))
 '((1 1 1 2 2 2 3 3 3)))

;; Staged, running backwards in runtime portion
(test
 (run 1 (q)
   (staged
    (fresh (rep)
      (specialize-partial-apply rep replicate/staged '(S (S (S Z))))
      (later (finish-apply rep replicate/staged q '(1 1 1 2 2 2 3 3 3))))))
 '((1 2 3)))

;; Partially-staged: will replicate each element at least twice, but perhaps more.
;; The generated code has two unfolded `cons`es.
;; This relies on the fallback to terminate at staging-time; otherwise the take*
;;   done by the gather would unfold cons-n forever.
(test
 (run 3 (q)
   (staged
    (fresh (rep n)
      (specialize-partial-apply rep replicate/staged `(S (S ,n)))
      (later (finish-apply rep replicate/staged '(1 2 3) q)))))
 '((1 1 2 2 3 3) (1 1 1 2 2 2 3 3 3) (1 1 1 1 2 2 2 2 3 3 3 3)))

;; We don't expect any specialization in this fully-backwards example,
;; but it should still work.
(test
 (run 2 (n l)
   (staged
    (fresh (rep)
      (specialize-partial-apply rep replicate/staged n)
      (later (finish-apply rep replicate/staged l '(1 1 1 2 2 2 3 3 3))))))
 '(((S (S (S Z))) (1 2 3)) ((S Z) (1 1 1 2 2 2 3 3 3))))

;;
;; As a single relation
;;


(defrel-partial/staged (replicate/staged-single rep [n] [l res])
  (replicate-helper `(replicate ,rep ,n ,l ,res)))

(defrel/staged (replicate-helper e)
  (conde
    [(fresh (n l res rep)
       (== `(replicate ,rep ,n ,l ,res) e)
       (gather
        (conde
          [(== l '())
           (== res '())]
          [(fresh (a d rec-res)
             (== l (cons a d))
             (replicate-helper `(cons-n ,n ,a ,rec-res ,res))
             (later (finish-apply rep replicate/staged-single d rec-res)))])))]
    [(fresh (n v l res)
       (== `(cons-n ,n ,v ,l ,res) e)
       (fallback
        (conde
          [(== n 'Z)
           (== l res)]
          [(fresh (n-1 rec-res)
             (== n `(S ,n-1))
             (== res (cons v rec-res))
             (replicate-helper `(cons-n ,n-1 ,v ,l ,rec-res)))])))]))

(test
 (run 1 (q)
   (staged
    (fresh (rep)
      (specialize-partial-apply rep replicate/staged-single '(S (S (S Z))))
      (later (finish-apply rep replicate/staged-single '(1 2 3) q)))))
 '((1 1 1 2 2 2 3 3 3)))




;;
;; Staged for a different mode: where we know `l` but not `n`.
;;

;; Note the asymmetry, due to the fact that cons-n doesn't call replicate.

(defrel/staged (replicate/staged2 l n res)
  (fallback
   (conde
     [(== l '())
      (== res '())]
     [(fresh (a d rec-res)
        (== l (cons a d))
        (later (cons-n n a rec-res res))
        (replicate/staged2 d n rec-res))])))

;; We can't / don't know how to write a replicate/staged that will specialize in both modes.

(test
 (run 1 (q)
   (fresh (n)
     (== n '(S (S (S Z))))
     (staged
      (replicate/staged2 '(1 2 3) n q))))
   '((1 1 1 2 2 2 3 3 3)))

(generated-code)

