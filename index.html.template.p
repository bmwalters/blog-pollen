@(require racket/function)
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
          <li><a href="/posts">Posts</a></li>
        </ul>
      </nav>
    </header>
    @(->html doc #:tag 'div #:attrs '((class "e-content")))
    <nav>
      @(letrec ([render-page (lambda (parent-path p)
                               (let* ([ps (symbol->string p)]) 
                                     ([page-path (if parent-path (build-path parent-path ps) ps)])
                                 `(li (a ((href ,page-path)) ,ps)
                                    ,@(maybe-render-pages (children p) page-path))))]
                [maybe-render-pages (lambda (pagelist parent-path)
                                      (if pagelist
                                        `((ul ,@(map (curry render-page parent-path) pagelist)))
                                        '()))])
          (->html (maybe-render-pages (other-siblings here) #f)))
    </nav>
  </main>
</body>
</html>
