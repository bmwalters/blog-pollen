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
      @(letrec ([render-page (lambda (p)
                              `(li ,(symbol->string p)
                                   ,(list-pages (or (children p) '()))))]
                [list-pages (lambda (pagelist)
                                `(ul ,@@(map render-page pagelist)))])
          (->html (list-pages (other-siblings here))))
    </nav>
  </main>
</body>
</html>
