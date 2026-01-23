#lang pollen

html {
  background-color: oldlace;
}

a {
  color: darkblue;
}

a:visited {
  color: darkred;
}

header {
  border-bottom: 0.5px solid black;
}

footer {
  border-top: 0.5px solid black;
}

.dt-published {
  font-style: italic;
}

body {
  font-family: serif, Verdana, Geneva, sans-serif;
  //font-size: 13pt;
  line-height: 1.5;
  text-align: justify;
}

body {
  max-width: min(60em, calc(100% - 2em));
  margin-left: auto;
  margin-right: auto;
}

main {
  max-width: 44em;
}

@"@"media (prefers-color-scheme: dark) {
  html {
    background-color: #24242e;
    color: seashell;
  }

  body {
    font-family: Verdana, Geneva, sans-serif;
    text-align: inherit;
  }

  main {
    max-width: 36em;
  }

  a {
    color: cornflowerblue;
  }

  a:visited {
    color: pink;
  }

  header, footer {
    border-color: seashell;
  }
}

header nav ul, footer nav ul {
  padding-left: 0;
  display: flex;
  justify-content: space-between;
}

header nav li, footer nav li {
  display: inline-block;
}

footer nav li:last-child {
  margin-left: auto;
}

.highlight pre {
  overflow-x: scroll;
}

/* Heading anchors */
.heading-anchor {
  opacity: 0;
  margin-left: 0.3em;
  text-decoration: none;
  font-weight: normal;
}

.heading-anchor::after {
  content: "#";
}

h2:hover .heading-anchor,
h3:hover .heading-anchor,
h4:hover .heading-anchor {
  opacity: 1;
}

.feed-link {
  padding-left: 19px;
  background: url("@(resource-ref-url "images/feed.svg")") no-repeat 0 50% / 14px 14px;
}
