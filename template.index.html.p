<!doctype html>
<html lang="en-US">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width">
  <title>@(select 'title metas)</title>
  @(->html (resource-ref-stylesheet-elem #:path "stylesheet.css"))
  <link rel="alternate" type="application/atom+xml" href="posts/feed.atom" title="@(select 'author metas)' Blog Feed">
</head>
<body>
  <main class="h-card">
    <header>
      <nav>
        <ul>
          <li><a class="p-name p-author u-url" href="/">@(select 'author metas)</a></li>
        </ul>
      </nav>
    </header>
    @(->html doc #:tag 'div)
    <nav>
      @(->html (maybe-render-pages (other-siblings here)))
    </nav>
  </main>
</body>
</html>
