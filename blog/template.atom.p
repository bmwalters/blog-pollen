<?xml version="1.0" encoding="utf-8"?>
@(require pollen/unstable/typography)
@(require pollen/file)
@(define site-author (select 'author metas))
@(define root-url (select 'root-url metas))
@(define posts (other-siblings here))
@(define (updated-date posts)
   (if (pair? posts)
       (let* ([p (car posts)]
              [p-path (get-source (pagenode->path p))]
              [p-metas (and p-path (get-metas p-path))]
              [created (and p-metas (select 'created p-metas))])
         (if created
             (string-append created "T00:00:00Z")
             "1970-01-01T00:00:00Z"))
       "1970-01-01T00:00:00Z"))
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>@(smart-quotes (select 'title metas))</title>
  <link href="@|root-url|@(symbol->string here)" rel="self" type="application/atom+xml"/>
  <link href="@|root-url|@(canonical-href (symbol->string (parent here)))" rel="alternate" type="text/html"/>
  <updated>@(updated-date posts)</updated>
  <author><name>@|site-author|</name></author>
  <id>@(select 'tag-uri metas)</id>
@(->html
  (map (lambda (p)
         (let* ([ps (symbol->string p)]
                [p-path (get-source (pagenode->path p))]
                [p-metas (and p-path (get-metas p-path))]
                [p-title (or (and p-metas (select 'title p-metas)) ps)]
                [p-created (and p-metas (select 'created p-metas))]
                [p-synopsis (or (and p-metas (select 'synopsis p-metas)) "")]
                [p-author (or (and p-metas (select 'author p-metas)) site-author)]
                [p-updated (if p-created
                               (string-append p-created "T00:00:00Z")
                               "1970-01-01T00:00:00Z")]
                [p-id (select 'tag-uri p-metas)]
                [p-doc (and p-path (cached-doc p-path))]
                [p-html (if p-doc (->html p-doc #:tag 'article) "")])
           `(entry
               (title ,p-title)
               (link [[href ,(string-append root-url (canonical-href ps))]
                      [rel "alternate"]
                      [type "text/html"]])
               (id ,p-id)
               (published ,p-updated)
               (updated ,p-updated)
               (summary [[type "text"]] ,p-synopsis)
               (content [[type "html"]] ,p-html))))
       posts))
</feed>
