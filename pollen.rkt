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
(require net/base64)
(require racket/function)
(require racket/string)
(provide (all-defined-out))

; Converts a string to a URL-friendly slug for use as an anchor ID.
; - Converts to lowercase
; - Replaces spaces with hyphens
; - Removes non-alphanumeric characters (except hyphens)
; - Collapses multiple hyphens into one
; - Trims leading/trailing hyphens
(define (string->slug str)
  (let* ([s (string-downcase str)]
         [s (string-replace s " " "-")]
         [s (regexp-replace* #rx"[^a-z0-9-]" s "")]
         [s (regexp-replace* #rx"-+" s "-")]
         [s (string-trim s "-")])
    s))

; Helper to extract plain text content from a txexpr or mixed content list.
(define (elements->string elems)
  (apply string-append
         (map (lambda (e)
                (cond
                  [(string? e) e]
                  [(txexpr? e) (elements->string (get-elements e))]
                  [else ""]))
              elems)))

; Creates a heading element with an anchor link that appears on hover.
; The anchor is hidden from screen readers via aria-hidden; the # is added via CSS.
(define (heading-with-anchor tag . content)
  (let* ([text (elements->string content)]
         [slug (string->slug text)])
    (txexpr tag `((id ,slug))
            (append content
                    (list " "
                          (txexpr 'a `((class "heading-anchor") (href ,(string-append "#" slug)) (aria-hidden "true")) '()))))))

; Heading tag functions with anchor links
(define (h2 . content) (apply heading-with-anchor 'h2 content))
(define (h3 . content) (apply heading-with-anchor 'h3 content))
(define (h4 . content) (apply heading-with-anchor 'h4 content))

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

(define (article-a dest . exp)
  (txexpr 'a `((href ,(canonical-href (string-append (symbol->string dest) ".html")))) exp))

; Maximum size in bytes for inlining resources
(define inline-resource-max-size 4096)

; Creates a stylesheet reference, inlining the CSS if small enough.
; In release mode and when the stylesheet is below inline-resource-max-size,
; emits an inline <style> block instead of a <link> element.
(define (resource-ref-stylesheet-elem #:path path . exp)
  (define (get-content path)
    (define full-path (build-path (current-directory) path))
    (define src-path (get-source full-path))
    (cond
      [src-path (get-doc src-path)]
      [(file-exists? full-path) (file->string full-path)]
      [else #f]))
  (define content (and (release-mode?) (get-content path)))
  (if (and content (<= (string-length content) inline-resource-max-size))
      (txexpr 'style '() (list content))
      (txexpr 'link `((rel "stylesheet") (href ,path)))))

; Returns a URL for a resource, using a data URI if small enough in release mode.
(define (resource-ref-url path)
  (define (path->mime-type path)
    (define ext (path-get-extension (if (path? path) path (string->path path))))
    (case ext
      [(#".svg") "image/svg+xml"]
      [(#".png") "image/png"]
      [(#".jpg" #".jpeg") "image/jpeg"]
      [(#".gif") "image/gif"]
      [(#".webp") "image/webp"]
      [(#".ico") "image/x-icon"]
      [else "application/octet-stream"]))
  (define (get-content path)
    (define full-path (build-path (current-directory) path))
    (define src-path (get-source full-path))
    (cond
      [src-path (let ([content (get-doc src-path)])
                  (if (string? content)
                      (string->bytes/utf-8 content)
                      content))]
      [(file-exists? full-path) (file->bytes full-path)]
      [else #f]))
  (define (make-data-uri content mime-type)
    (define base64-content (base64-encode content #""))
    (string-append "data:" mime-type ";base64," (bytes->string/utf-8 base64-content)))
  (define content (and (release-mode?) (get-content path)))
  (if (and content (<= (bytes-length content) inline-resource-max-size))
      (make-data-uri content (path->mime-type path))
      path))

; Transforms a path to canonical href form for URLs.
; Matches the project nginx config and must be updated when that changes.
; Only performs transformations in release mode (POLLEN_RELEASE=1).
; Strategy:
;   - dir/index.html → dir/ (trailing slash for directories)
;   - index.html → ./ (relative to current directory)
;   - file.html → file (no extension for top-level pages)
(define (canonical-href path)
  (if (release-mode?)
      (cond
        ; dir/index.html → dir/
        [(string-suffix? path "/index.html")
         (substring path 0 (- (string-length path) 10))]
        ; index.html → ./ (relative current directory)
        [(string=? path "index.html") "./"]
        ; file.html → file (no trailing slash)
        [(string-suffix? path ".html")
         (substring path 0 (- (string-length path) 5))]
        ; Pass through as-is
        [else path])
      path))

; Inverse of pollen/pagetree's path->pagenode.
; Converts a pagenode to a source path by stripping the relative-to prefix
; and running the result through get-source.
(define (pagenode->path p [relative-to (current-directory)])
  (let* ([p-str (if (symbol? p) (symbol->string p) p)]
         [full-path (build-path (current-project-root) p-str)]
         [rel-path (find-relative-path relative-to full-path)])
    rel-path))

(define (maybe-render-pages pagelist #:h-entries? [h-entries? #t])
  (letrec ([page-name-is? (lambda (name p)
                            (let ([ps (symbol->string p)])
                              (or (string=? ps name)
                                  (string-suffix? ps (string-append "/" name)))))]
           [render-page (lambda (p)
                          (let* ([ps (symbol->string p)]
                                 [pp (pagenode->path ps)])
                            (cond
                              [(page-name-is? "feed.atom" p)
                               `(li (a ((href ,(path->string pp)) (class "feed-link")) "Feed"))]
                              [else
                               (let* ([p-metas (get-metas (get-source pp))]
                                      [p-title (or (and p-metas (select 'title p-metas)) ps)]
                                      [p-created (and p-metas (select 'created p-metas))]
                                      [p-synopsis (and p-metas (select 'synopsis p-metas))]
                                      [p-url (canonical-href (path->string pp))]
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
