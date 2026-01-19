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
	  <li><a class="p-author h-card" href="/">@(select 'author metas)</a></li>
	  <li><a href=".">Posts</a></li>
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
          @(let ([hn-id (select-from-metas 'hn-id metas)])
             (if hn-id
                 (->html `(li (a [[href ,(string-append "https://news.ycombinator.com/item?id=" hn-id)]] "Discuss on Hacker News")))
                 ""))
          <li><a class="feed-link" href="feed.atom">Feed</a></li>
        </ul>
      </nav>
    </footer>
  </main>
</body>
</html>
