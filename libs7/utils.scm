;; (display "loading libs7/utils.scm") (newline)

(define (remove-ifx func lst)
  (map (lambda (x) (if (func x) (values) x)) lst))

(define (last list)
   (if (zero? (length (cdr list)))
      (car list)
      (last (cdr list))))

(load "s7/stuff.scm")

(set! *#readers*
      (cons (cons #\h (lambda (str)
			(and (string=? str "h") ; #h(...)
			     (apply hash-table (read)))))
	    *#readers*))
*#readers*

(define (sym<? s1 s2)
  (let ((x1 (symbol->string s1)) (x2 (symbol->string s2)))
    (string<? x1 x2)))

(define (modules<? s1 s2)
  (let ((x1 (if (symbol? s1) (symbol->string s1) s1))
        (x2 (if (symbol? s2) (symbol->string s2) s2)))
    (string<? x1 x2)))

;; (modules Registerer), (modules (:standard \ legacy_store_builder))
;; (modules)
;; (modules (:standard) \ Plugin_registerer)
;; (modules (:standard (symbol "\\") delegate_commands delegate_commands_registration))
;; (modules (:standard (symbol "\\") legacy_store_builder))
;; (modules :standard (symbol "\\") gen)
;; NB: modules may be generated rather than srcfile modules!
;; ex: src/lib_protocol_environment/sigs:Tezos_protocol_environment_sigs
;; depends on "V0", "V1"... which are generated by rule
;; a module must go in one of :direct or :indirect
(define (indirect-module-dep? module srcfiles)
  ;; (format #t "indirect-module-dep? ~A : ~A\n" module srcfiles)
  (let recur ((srcfiles srcfiles))
    (if (null? srcfiles)
        #t
        (let* ((m (if (symbol? module) (symbol->string module)
                     (copy module)))
               (bn (bname (car srcfiles))))

          (if (string=? m bn)
              #f
              (begin
                (string-set! m 0 (char-downcase (string-ref m 0)))
                (if (string=? m bn)
                    #f
                    (recur (cdr srcfiles)))))))))

(define (libdep->module-name libdep)
  (let ((mname (copy libdep)))
    libdep))

;; basename with extension removed
(define (bname path)
  (let* ((last-slash (string-index-right path (lambda (c) (eq? c #\/))))
         (basename (if last-slash
                       (string-drop path (+ last-slash 1))
                       path))
         (last-dot (string-index-right basename (lambda (c) (eq? c #\.)))))
    (string-take basename last-dot)))

;; s7test.scm
(define (identity x) x)
(define eq eq?)
(define eql eqv?)
(define equal equal?)

;; s7test.scm
(define (make obj size)
	  (cond ((vector? obj)     (make-vector size))
		((list? obj)       (make-list size))
		((string? obj)     (make-string size))
		((hash-table? obj) (make-hash-table size))))

;; s7test.scm
;; (define* (remove-if predicate sequence from-end (start 0) end count (key identity))
;;   (let* ((len (length sequence))
;; 	 (nd (or (and (number? end) end) len))
;; 	 (num (if (number? count) count len))
;; 	 (changed 0))
;;     (if (not (positive? num))
;; 	sequence
;; 	(let ((result ()))
;; 	  (if (null? from-end)
;; 	      (do ((i 0 (+ i 1)))
;; 		  ((= i len))
;; 		(if (or (< i start)
;; 			(>= i nd)
;; 			(>= changed num)
;; 			(not (predicate (key (sequence i)))))
;; 		    (set! result (cons (sequence i) result))
;; 		    (set! changed (+ changed 1))))
;; 	      (do ((i (- len 1) (- i 1)))
;; 		  ((< i 0))
;; 		(if (or (< i start)
;; 			(>= i nd)
;; 			(>= changed num)
;; 			(not (predicate (key (sequence i)))))
;; 		    (set! result (cons (sequence i) result))
;; 		    (set! changed (+ changed 1)))))
;; 	  (let* ((len (length result))
;; 		 (obj (make sequence len))
;; 		 (vals (if (null? from-end) (reverse result) result)))
;; 	    (do ((i 0 (+ i 1)))
;; 		((= i len))
;; 	      (set! (obj i) (vals i)))
;; 	    obj)))))

;; s7test.scm
(define* (remove item sequence from-end (test eql) (start 0) end count (key identity))
  (remove-if list (lambda (arg) (test item arg)) sequence))
  ;; (remove-if (lambda (arg) (test item arg)) sequence from-end start end count key))

;; s7test.scm
(define-macro* (delete item sequence from-end (test eql) (start 0) end count (key identity))
	    `(let ((obj (remove ,item ,sequence ,from-end ,test ,start ,end ,count ,key)))
	       (if (symbol? ',sequence)
		   (set! ,sequence obj))
	       obj))

;; convert a_b_c to a-b-c
(define (endash str)
  (apply string (map (lambda (ch)
                       (if (char=? ch #\_)
                           #\-
                           ch))
                     str)))

;; convert a-b-c to a_b_c
(define (undash str)
  (apply string (map (lambda (ch)
                       (if (char=? ch #\-)
                           #\_
                           ch))
                     str)))

;; convert a.b.c to a/b/c
(define (enslash str)
  (apply string (map (lambda (ch)
                       (if (char=? ch #\.)
                           #\/
                           ch))
                     str)))

(define (normalize-module-name mname)
  (let ((s (if (symbol? mname)
               (symbol->string mname)
               (if (string? mname)
                   mname
                   (error 'bad-type
                          (format #f "module name not sym or string: ~A"
                                  mname))))))
    (string-set! s 0 (char-upcase (string-ref s 0)))
    (string->symbol s)))

(define filename-cache (make-hash-table))

(define (file-name->module-name path)
  (if-let ((modname (filename-cache path)))
          modname
          (let* ((last-slash (string-index-right path
                                                 (lambda (c) (eq? c #\/))))
                 (fname (if last-slash
                            (string-drop path (+ last-slash 1))
                            path))
                 (mraw (if (string-suffix? ".ml" fname)
                           (string-drop-right fname 3)
                           (if (string-suffix? ".mli" fname)
                               (string-drop-right fname 4)
                               (error 'bad-filename
                                      (string-append "extension should be .ml or .mli: "
                                                     fname)))))
                 (modname (normalize-module-name mraw)))
            (hash-table-set! filename-cache path modname)
            modname)))

;; s7test.scm
(define (flatten lst)
    (map values (list (let flatten-1 ((lst lst))
                        (cond ((null? lst) (values))
                               ((not (pair? lst)) lst)
                               (else (values (flatten-1 (car lst))
                                             (flatten-1 (cdr lst)))))))))

(define (concatenate . args)
  (apply append (map (lambda (arg) (map values arg)) args)))

(define (nth n l)
  (if (or (> n (length l)) (< n 0))
    (error "Index out of bounds.")
    (if (eq? n 0)
      (car l)
      (nth (- n 1) (cdr l)))))

(define (hash-table-keys ht)
  (map car ht))

(define-macro* (if-let bindings true false)
  (let* ((binding-list (if (and (pair? bindings) (symbol? (car bindings)))
			   (list bindings)
			   bindings))
	 (variables (map car binding-list)))
    `(let ,binding-list
       (if (and ,@variables)
	   ,true
	   ,false))))

(define (dirname path)
  (let ((last-slash (string-index-right path (lambda (c) (eq? c #\/)))))
    (if last-slash
        (string-take path last-slash)
        path)))

(define (basename path)
  (let ((last-slash (string-index-right path (lambda (c) (eq? c #\/)))))
    (string-drop path (+ last-slash 1))))

(define (fs-glob->list pattern)
  ;;(with-let (sublet *libc* :pattern pattern)
  (let ((g (glob.make)))
    (glob pattern 0 g)
    (let ((res (glob.gl_pathv g)))
      (globfree g)
      res)))
;;)
