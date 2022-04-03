;; TODO: constraints like absento and probably reification need to know about apply-rep.
;; TODO: need a story for letrec
(define-record-type apply-rep
  (nongenerative)
  (fields name-staged name-dyn args proc))

(define-syntax lreify-call
  (lambda (stx)
    (syntax-case stx ()
        ((_ rep ((rel-staged rel-dyn) (x ...) (y ...)))
         (andmap (lambda (id) (free-identifier=? id #'_)) (syntax->list #'(y ...)))
         (with-syntax
          (((x-n ...) (generate-temporaries #'(x ...)))
           ((y-n ...) (generate-temporaries #'(y ...))))
          #'(fresh (x-n ... y-n ... body)
              (later-scope (rel-staged x-n ... y-n ...) body)
              (l== rep (make-apply-rep
                       'rel-staged 'rel-dyn (list x ...)
                       (unexpand `(lambda (,x-n ...)
                                    (lambda (,y-n ...)
                                      (fresh () . ,body))))))))))))

(define-syntax reify-call
  (lambda (stx)
    (syntax-case stx ()
        ((_ rep ((rel-staged rel-dyn) (x ...) (y ...)))
         (andmap (lambda (id) (free-identifier=? id #'_)) (syntax->list #'(y ...)))
         #'(== rep (make-apply-rep
                    'rel-staged 'rel-dyn (list x ...)
                    #f))))))

(define-syntax apply-reified
  (lambda (stx)
    (syntax-case stx ()
        ((_ rep ((rel-staged rel-dyn) (x ...) (y ...)))
         (andmap (lambda (id) (free-identifier=? id #'_)) (syntax->list #'(x ...)))
         (with-syntax
          (((x-n ...) (generate-temporaries #'(x ...)))
           ((y-n ...) (generate-temporaries #'(y ...))))
          #'(project (rep)
              (cond
                ((var? rep)
                 (fresh (x-n ... y-n ...)
                   (== rep (make-apply-rep
                            'rel-staged 'rel-dyn (list x-n ...) ;
                            #f))
                   (rel-dyn x-n ... y ...)))
                ((apply-rep? rep)
                 (let ((proc (apply-rep-proc rep)))
                   ;; TODO: unify to check names
                   (if (or (not proc) (unexpand? proc))
                       (apply rel-dyn (append (apply-rep-args rep) (list y ...)))
                       ((apply proc (apply-rep-args rep)) y ...))))
                (else fail))))))))

(define-syntax lapply-reified
  (syntax-rules ()
    ((_ rep ((rel-staged rel-dyn) (x ...) (y ...)))
     (later `(apply-reified ,rep ((rel-staged rel-dyn) (x ...) (,(expand y) ...)))))))
