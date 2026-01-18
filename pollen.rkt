#lang racket

(module setup racket
  (provide (all-defined-out))
  (define command-char #\@))

(require txexpr)
(require pollen/unstable/pygments)
(require pollen/decode)
(require pollen/pagetree)
(require net/url)
(require racket/function)

(provide (all-defined-out))

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

(define (maybe-render-pages pagelist)
  (letrec ([page-name-is? (lambda (name p)
                            (let ([ps (symbol->string p)])
                              (or (string=? ps name)
                                  (string-suffix? ps (string-append "/" name)))))]
           [render-page (lambda (p)
                          (let* ([ps (symbol->string p)]
                                 [p-children (or (children p) '())]
                                 [maybe-feed-page (findf (curry page-name-is? "feed.atom") p-children)]
                                 [filtered-children (filter (lambda (c)
                                                              (not (or (page-name-is? "index.html" c)
                                                                       (page-name-is? "feed.atom" c))))
                                                            p-children)])
                            `(li (a ((href ,ps)) ,ps)
                               ,@(if maybe-feed-page
                                     `(" " (a ((href ,(symbol->string maybe-feed-page))
                                               (class "feed-link"))
                                              "Feed"))
                                     '())
                               ,@(maybe-render-pages filtered-children))))])
    (if pagelist
        `((ul ,@(map render-page pagelist)))
        '())))
