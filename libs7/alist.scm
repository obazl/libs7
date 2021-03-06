;; (display "loading libs7/alist.scm") (newline)

(load "srfi.scm")
(load "utils.scm")

(define (assoc-val k alist)
  (if-let ((a (assoc k alist)))
          (cdr a)
          #f))

;; s7test.scm
(define eq eq?)
(define eql eqv?)
(define equal equal?)

(define* (rassoc-if predicate alist (key cdr))
  ;; (format #t "rassoc-if ~A :: ~A\n" key alist)
  (if (null? alist)
      ()
      (if (and (pair? (car alist))
	       (predicate (key (car alist))))
	  (car alist)
	  (rassoc-if predicate (cdr alist) key))))

(define* (rassoc item alist (test eql) (key cdr))
  (rassoc-if (lambda (obj)
               ;; (format #t "rassoc test: ~A :: ~A\n" item obj)
               (test item obj)) alist key))

;;;;;;;;;;;;;;;;
(define (alist? obj)
  (if (list? obj)
      (if (null? obj)
          #t ;; ?
          (if (pair? (car obj))
              (and (> (length (car obj)) 1)
                   (alist? (cdr obj)))
              #f))
      #f))

;; rassoc: searches for pair with matching value

;; srfi-1: alist-cons
(define acons
  (let ((+documentation+ "(acons key datum alist)")
        (+signature+ '(acons key datum alist)))
    (lambda (key datum alist)
      (cons (list key datum) alist))))

;; assoc*
;; like assoc, but returns list of all matches instead of the first
;; returns '() on no match (assoc returns #f)
(define assoc*
  (let ((+documentation+ "(assoc* key alist) like assoc, but returns list of all matches instead of the first.")
        (+signature+ '(assoc-in keypath alist)))
    (lambda (stanza-key alist)
      (cond ((null? alist) '())
            ((equal? stanza-key (caar alist))
             (cons (car alist) (assoc* stanza-key (cdr alist))))
            (else (assoc* stanza-key (cdr alist)))))))

;; assoc-in
;; returns first assoc pairs for keypath in a nested alist struct
(define assoc-in
  (let ((+documentation+ "(assoc-in keypath alist) keypath: list of keys; alist: tree of alists. Returns the first assoc found by successively applying 'assoc'.")
        (+signature+ '(assoc-in keypath alist)))
    (lambda (key-path alist)
      (if (null? key-path)
          #f ;; alist
          (if (list? alist)
              (if (null? alist)
                  #f
                  (if-let ((in-alist (assoc (car key-path) alist)))
                          (if (null? (cdr key-path))
                              in-alist
                              (assoc-in (cdr key-path) (cdr in-alist)))
                          #f))
              #f)))))

;; assoc-in*
;; returns all assoc pairs for last key in keypath in a nested alist struct
;; for all preceding keys, uses first match
;; i.e. use this when the path is unique up to the last key
;; use assoc-in*+ when each alist on the path may have dup keys
(define assoc-in*
  (let ((+documentation+ "(assoc-in* keypath alist) keypath: list of keys; alist: tree of alists. Returns all assocs for last key in keypath. For all preceding keys in keypath uses first match.")
        (+signature+ '(assoc-in* keypath alist)))
    (lambda (key-path alist)
      (if (null? key-path)
          alist
          (if (list? alist)
              (if (null? alist)
                  #f
                  (if-let ((in-alist (assoc (car key-path) alist)))
                          (begin
                            (if (null? (cdr key-path))
                                ;; last key: get all matches
                                (assoc* (car key-path) alist)
                                (assoc-in* (cdr key-path) (cdr in-alist))))
                          #f))
              #f)))))

;; srfi-1: (alist-delete k ls)
;; ref impl modified for s7
(define* (alist-delete ks alist (= equal?))
  ;; (format #t "alist-delete ~A ~A\n" ks alist)
  ;; (let ((= (:optional maybe-= equal?)))
  (filter (lambda (assoc-elt)
            (not (member (car assoc-elt) ks))
            ;; (not (= k (car elt)))
            )
          alist))

(define dissoc alist-delete) ;; clojure

;; (define (alist-delete! key alist . maybe-=)
;;   (let ((= (:optional maybe-= equal?)))
;;     (filter! (lambda (elt) (not (= key (car elt)))) alist)))

;; mit: (del-assq obj alist), del-assv, del-assoc
;; gauche: alist-delete, alist-delete!
;; guile: (assoc-remove! alist key)
;; (define (assq-del k als) ;; FIXME: k-list
;;   (if (null? als)
;;       '()
;;       (let ((h (car als)))
;;         ((if (eq? k (car h))
;;             (lambda (y) y)
;;             (lambda (y) (cons h y)))
;;          (assq-del k (cdr als))))))

;; (define (assv-del k als)
;;   (if (null? als)
;;       '()
;;       (let ((h (car als)))
;;         ((if (eqv? k (car h))
;;             (lambda (y) y)
;;             (lambda (y) (cons h y)))
;;          (assv-del k (cdr als))))))

;; (define (assoc-del k als)
;;   (if (null? als)
;;       '()
;;       (let ((h (car als)))
;;         ((if (equal? k (car h))
;;             (lambda (y) y)
;;             (lambda (y) (cons h y)))
;;          (assoc-del k (cdr als))))))

;; (define (assoc-del! als k)
;;   ;; FIXME: mutate als
;;   (if (null? als)
;;       '()
;;       (let ((h (car als)))
;;         ((if (equal? k (car h))
;;             (lambda (y) y)
;;             (lambda (y) (cons h y)))
;;          (assoc-del k (cdr als))))))

;; clojure: (update m k f)
;; gauche: assoc-adjoin
(define (assq-update k als fn)
  (if-let ((a (assq k als)))
          (cons (list k (fn (cadr (assoc k als)))) (assq-del k als))
          als))

(define (assv-update k als fn)
  (if-let ((a (assv k als)))
          (cons (list k (fn (assoc k als))) (assv-del k als))
          als))

;; fn must take an assoc arg
;; if key not found, passes '() as old assoc
(define (assoc-update k als fn)
  ;; (display (format #f "assoc-update ~A ~A" k als)) (newline)
  (if-let ((a (assoc k als)))
          (begin
            ;; (display (format #f "KEY ~A" k)) (newline)
            ;; (display (format #f "ASSOC ~A" a)) (newline)
            (cons (list k (fn a)) (alist-delete :k k als))
            )
          (cons (list k (fn '())) als)))

(define (assoc-update! k als fn)
  ;; FIXME: mutate
  (cons (list k (fn (assoc k als))) als)) ;; (alist-delete k als)))

;; clojure: update-in

;; gauche: assoc-update-in. "If alist doesn???t have the entry specified
;; by keys, a new entry is added. A new entry is added at the
;; beginning of the sequence where specified key didn???t exist."
;; FIXME: add optional eql? arg; default is equal?
;; ENHANCEMENT: proc that only adds to end, returns #<unspecified> for
;; other missing keys.
(define alist-update-in!
  (let ((+documentation+ "Updates als (alist) at keypath, using fn, which must be a function of one arg. The old value will be passed to fn, which must return a new val.")
        (+signature+ "(alist-update-in! alist keypath fn)"))
    (lambda (als ks fn)
      ;; (format #t "alist-update-in! keys: ~A\n" ks)
      ;; (format #t "alist-update-in! ~A\n  keys: ~A\n" als ks)
      (let ((the-alist als)
            (eql? equal?))
        (let recur ((als als)
                    (ks ks))
          ;; (format #t "RECURRING ks: ~A\n" ks)
          ;; (format #t "RECURRING als: ~A\n" als)
          (if (null? als)
              (if (null? ks)
                  (begin
                    ;; (format #t "als and ks null; invoking update fn\n")
                    (fn '()))
                  (let (;; (_ (format #t " empty als, ks: ~A\n" ks))
                        (recres (recur als (cdr ks))))
                    ;; (format #t " base recres for ~A: ~A\n" (car ks) recres)
                    (if (alist? recres)
                        (cons (car ks) recres)
                        (cons (car ks) (list recres)))))
              ;; als not null
              (if (null? ks)
                  (begin
                    ;; (format #t "matched all keys, applying fn to ~A\n" als)
                    (let ((base (fn als)))
                      ;; (format #t "fn result: ~A\n" base)
                      base))
                  ;; ks and als not null
                  (begin
                    ;; (format #t "(alist? als) ~A\n" (alist? als))
                    ;; (format #t "intermediate match on k? ~A\n"
                    ;;         (assoc (car ks) als))
                    (if-let ((sub-alist (assoc (car ks) als)))
                          (begin
                            ;; (format #t "intermediate match on k ~A\n"
                            ;;         (car ks))
                            ;; (format #t "isub-list before ~A\n" sub-alist)
                            (let ((recres (recur (cdr sub-alist) (cdr ks))))
                              ;; (format #t "imatch recres ~A\n" recres)
                              ;; replaces sub-alist within als
                              (set-cdr! sub-alist
                                        recres)
                              ;; (format #t "isub-list after ~A\n" sub-alist)
                              ;; (format #t "als after ~A\n" als)
                            als))

                          ;; no match, both ks and als not null
                          (begin
                            ;; (format #t "nomatch for key ~A - adding ~A\n"
                            ;;         (car ks) ks)
                            ;; (format #t "old als: ~A\n" als)
                            (let* (;;(_ (format
                                    ;; #t "nomatch for key ~A - adding ~A\n"
                                    ;; (car ks) ks))
                                  ;; (_ (format #t "old als: ~A\n" als))
                                  (recres (recur '() (cdr ks)))
                                  ;; (_ (format
                                  ;;     #t "i-nomatch recres for ~A: ~A\n"
                                  ;;     (car ks) recres))
                                  )
                              ;; recres could be: (:ml d.ml) for new file
                              ;; or (D (:ml d.ml)) for module
                            (let ((newtree
                                   (append! als
                                            (list
                                             (list (car ks)
                                                   ;;FIXME: don't think this works generally, but it works for mibl
                                                   (if (alist? recres)
                                                       (car recres)
                                                       recres))))))
                              ;; (format #t "newtree: ~A\n" newtree)
                              ;; (format #t "new als: ~A\n" als)
                              newtree))))))))
        the-alist))))

;;;;;;;;;;;;;;;; tests ;;;;;;;;;;;;;;;;
;; (define al '((:a 1) (:b 2) (:c 3) ("a" "hi") ("b" "bye")))

;; (equal? "a" "a")

;; (assq-del "a" al)
;; (assv-del "a" al)
;; (alist-delete "a" al equal?)

;; (assq-update "a" al (lambda (old) "new"))
;; (assv-update "a" al (lambda (old) "new"))
;; (assoc-update "a" al (lambda (old) "new"))

;; (let* ((x (assoc-update :c al (lambda (old) (+ 1 old))))
;;        (y (assoc-update :c x (lambda (old) (+ 1 old)))))
;;   (display x) (newline)
;;   ;(display y) (newline)
;;   y)
;; (display "loaded libs7/alist.scm") (newline)
