#lang racket/base

(module setup racket/base
  (provide (all-defined-out))
  (define command-char #\@))

(require txexpr)
(require pollen/unstable/pygments)

(provide (all-defined-out))

(define (code #:lang lang . exp)
  (apply highlight (string->symbol lang) exp))

(define (gh-pr dest)
  (txexpr 'a '() '("Hello World")))
