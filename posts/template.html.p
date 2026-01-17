<!doctype html>
<html lang="en-US" class="h-entry">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width">
  <title class="p-name">@(select 'title metas)</title>
  <meta name="description" content="@(select 'synopsis metas)">
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
    <article>
      <p>
        <time class="dt-published" datetime="@(select 'created metas)">@(select 'created metas)</time>
      </p>
      @(->html doc #:tag 'div #:attrs '((class "e-content")))
    </article>
    <footer>
      <nav>
        <ul>
          <li><a href="">Discuss on Hacker News</a></li>
          <li><a class="feed-link" href="feed.atom">Feed</a></li>
        </ul>
      </nav>
    </footer>
  </main>
</body>
</html>
