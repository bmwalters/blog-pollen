<!doctype html>
<html lang="en-US">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width">
  <title>@(select 'title metas)</title>
  @(->html (resource-ref-stylesheet-elem #:path "../stylesheet.css"))
  <link rel="alternate" type="application/atom+xml" href="feed.atom" title="@(select 'author metas)' Blog Feed">
</head>
<body class="h-feed">
  <main>
    <header>
      <nav>
        <ul>
          <li><a class="p-author u-url h-card" href="/">Bradley Walters</a></li>
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
