#lang racket

(module setup racket
  (provide (all-defined-out))
  (define command-char #\@))

(require txexpr)
(require pollen/unstable/pygments)
(require pollen/decode)
(require pollen/pagetree)
(require pollen/core)
(require pollen/file)
(require pollen/setup)
(require net/url)
(require racket/function)

(provide (all-defined-out))

(define (release-mode?)
  (equal? (getenv "POLLEN_RELEASE") "1"))

(define (root . exp)
  `(root ,@(decode-elements exp
                            #:exclude-tags '(pre)
                            #:txexpr-elements-proc decode-paragraphs
                            #:string-proc smart-quotes)))

(define (pre-code #:lang lang #:line-numbers? [line-numbers? #t] . exp)
  (apply highlight (string->symbol lang) #:line-numbers? line-numbers? exp))

(define (gh-pr dest)
  (let* [(path-parts (map path/param-path (url-path (string->url dest))))
         (pull-idx (index-of path-parts "pull"))
         (repo (take path-parts pull-idx))
         (prno (list-ref path-parts (+ pull-idx 1)))]
    (txexpr 'a `((href ,dest)) `(,(string-append (string-join repo "/") "#" prno)))))

(define (article-anchor dest . exp)
  (txexpr 'a `((href ,(string-append (symbol->string dest) ".html"))) exp))

; TODO: create inline style block when small enough
(define (resource-ref-stylesheet-elem #:path path . exp)
  (txexpr 'link `((rel "stylesheet") (href ,path))))

; TODO: create inline data url when small enough
(define (resource-ref-url . exp)
  "images/feed.svg")

; Transforms a path to canonical href form for URLs.
; Matches the project nginx config and must be updated when that changes.
; Only performs transformations in release mode (POLLEN_RELEASE=1).
(define (canonical-href path)
  (if (release-mode?)
      (let* ([s path]
             ; Strip trailing index.html
             [s (if (string-suffix? s "/index.html")
                    (substring s 0 (- (string-length s) 10))
                    (if (string=? s "index.html")
                        ""
                        s))]
             ; Strip trailing .html
             [s (if (string-suffix? s ".html")
                    (substring s 0 (- (string-length s) 5))
                    s)]
             ; Strip trailing / (if not literal /)
             [s (if (and (string-suffix? s "/")
                        (> (string-length s) 1))
                    (substring s 0 (- (string-length s) 1))
                    s)]
             ; Ensure root path is /
             [s (if (string=? s "") "/" s)])
        s)
      path))

(define (maybe-get-metas p)
  ; Try to get metas for a pagenode if a source file exists
  ; Uses current-directory which is set to the source file's directory during rendering
  (let* ([out-path (build-path (current-directory) (symbol->string p))]
         [src-path (get-source out-path)])
    (if src-path (get-metas src-path) #f)))

(define (maybe-render-pages pagelist #:h-entries? [h-entries? #f])
  (letrec ([page-name-is? (lambda (name p)
                            (let ([ps (symbol->string p)])
                              (or (string=? ps name)
                                  (string-suffix? ps (string-append "/" name)))))]
           [render-page (lambda (p)
                          (let ([ps (symbol->string p)])
                            (cond
                              [(page-name-is? "feed.atom" p)
                               `(li (a ((href ,ps) (class "feed-link")) "Feed"))]
                              [else
                               (let* ([p-metas (maybe-get-metas p)]
                                      [p-title (or (and p-metas (select 'title p-metas)) ps)]
                                      [p-created (and p-metas (select 'created p-metas))]
                                      [p-synopsis (and p-metas (select 'synopsis p-metas))]
                                      [p-url (canonical-href ps)]
                                      [p-children (or (children p) '())]
                                      [child-lis (map render-page p-children)]
                                      [li-attrs (if h-entries? '((class "h-entry")) '())])
                                 `(li ,li-attrs
                                      (p (a ((class "u-url p-name") (href ,p-url)) ,p-title)
                                         ,@(if p-created
                                               `(" " (time ((class "dt-published") (datetime ,p-created)) ,p-created))
                                               '()))
                                      ,@(if p-synopsis
                                            `((p ((class "p-summary")) ,p-synopsis))
                                            '())
                                      ,@(if (null? child-lis)
                                            '()
                                            `((ul ,@child-lis)))))])))])
    (if pagelist
        `((ul ,@(map render-page pagelist)))
        '())))
