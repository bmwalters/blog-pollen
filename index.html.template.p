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
      <ul>
        <li>Pages @(current-pagetree)
          <ul>
            <li>asdf</li>
          </ul>
        </li>
      </ul>
    </nav>
  </main>
</body>
</html>
