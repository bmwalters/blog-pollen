<!doctype html>
<html lang="en-US">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width">
  <title>Posts</title>
  @(->html (resource-ref-stylesheet-elem #:path "../stylesheet.css"))
</head>
<body>
  <main class="h-card">
    <header>
      <nav>
        <ul>
          <li><a class="p-name p-author u-url" href="/">Bradley Walters</a></li>
        </ul>
      </nav>
    </header>
    @(->html doc #:tag 'div)
    <nav>
      @(->html (maybe-render-pages (cddr (get-pagetree "index.ptree")) #:h-entries? #t))
    </nav>
  </main>
</body>
</html>
