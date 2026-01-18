@(require racket/function racket/string)
<!doctype html>
<html lang="en-US" class="h-entry">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width">
  <title class="p-name">@(select 'title metas)</title>
  @(->html (resource-ref-stylesheet-elem #:path "../stylesheet.css"))
</head>
<body>
  <main>
    <header>
      <nav>
        <ul>
          <li><a class="p-author h-card" href="/">Bradley Walters</a></li>
        </ul>
      </nav>
    </header>
    @(->html doc #:tag 'div #:attrs '((class "e-content")))
    <nav>
      @(letrec ([page-name-is? (lambda (name p)
                                  (let ([ps (symbol->string p)])
                                    (or (string=? ps name)
                                        (string-suffix? ps (string-append "/" name)))))]
                [render-page (lambda (p)
                               (let* ([ps (symbol->string p)] [p-children (or (children p) '())]
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
                                    ,@(maybe-render-pages filtered-children))))]
                [maybe-render-pages (lambda (pagelist)
                                      (if pagelist
                                        `((ul ,@(map render-page pagelist)))
                                        '()))])
          (->html (maybe-render-pages (other-siblings here))))
    </nav>
  </main>
</body>
</html>
