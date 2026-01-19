#lang pollen

@define-meta[title]{Detour: to creduce}
@define-meta[author]{Bradley Walters}
@define-meta[created]{2026-01-17}
@define-meta[synopsis]{An introduction to the creduce tool plus a reusable LLM agent skill definition.}
@define-meta[tag-uri]{tag:walters.app,2026:detour-to-creduce}
@; TODO: @license{}... but does that apply to the rendered content or this source file (or both?)

@a[#:href "https://github.com/csmith-project/creduce"]{creduce} is a tool to automatically create a minimal reproduction case from interesting code. I thought I had a use case for exactly that when I was working to @article-a['bootstrapping-bun]{make Bun bootstrappable}.

While debugging a tricky @code{SIGABRT} when loading Bun's @code{assert.js} builtin from WebKit JavaScriptCore, I assumed there must be some syntax incompatibility hidden inside the huge JS file. If this were the case then creduce would be the perfect tool for the job.

creduce in its basic usage takes two command line arguments: an interestingness-test script and a file which exhibits the interesting property. (In my case, the property is "causes an error when loaded as a JSC builtin"). It then applies transformations to reduce the byte count of the input file while preserving said interesting property until a fixed point is reached.

Here's the interestingness test that I ended up with in my case:

@pre-code[#:lang "js" #:line-numbers? #f]{
$ cat reduce-test1.sh
#!/bin/sh
ulimit -c 0 \
&& sed 's/@"@"//g' < assert.js | node \
&& cp assert.js /work/bun/build/debug/js/node/assert.js \
&& /work/bun/build/debug/bun-debug -e \
  'import assert from "assert"; console.log(assert);' \
  2>&1 | rg "Unexpected end of script"

$ creduce --not-c reduce-test1.sh assert.js
...
}

The purpose of each condition is as follows:

@ol{
  @li{@code{ulimit}: not part of the check; prevent dumping core on SIGABRT (slow).}
  @li{@code{sed}: ensure the test case can parse as normal JavaScript; @"@" syntax is only for JSC builtins.}
  @li{@code{cp}: swap the test case in for our builtin.}
  @li{@code{bun-debug}: ensure the error continues to occur.}
}

In practice I began with (4) alone and added (1) and (2) as the test grew slow or failed to constrain the output.

And here's the minimized result:

@pre-code[#:lang "js" #:line-numbers? #f]{
(function (){
	a = Object.assign
	assert = {}
	Object.defineProperty(assert, "", {
	get()
	{
	@"@"createInternalModuleById(         5               )}
     ,   enumerable: true }
       )
	function b() {}
	a(b, assert)
	}
	 )
}

Not bad compared to a ~22,000 line file!

In the end though this debugging strategy did not bear fruit for my particular problem. Visually inspecting the result confirmed that nothing about the syntax of the code was likely to be the direct cause of the crash.

I was glad to get some practice with creduce though.

@h2{Agent Skill}

creduce currently has no man page. As a quick workaround, I've packaged the creduce docs as an @a[#:href "https://opencode.ai/docs/skills"]{agent skill} to be used in future projects. The skill consists of three files: @code{SKILL.md}, @code{using.html}, and @code{creduce.html} (history). It can be installed with this command:

@pre-code[#:lang "sh" #:line-numbers? #f]{
$ mkdir -p ~/.claude/skills/creduce \
&& echo '---
name: creduce
description: create a minimal reproduction case from interesting code
---

* Detailed usage: using.html
* History & credits: creduce.html' > ~/.claude/skills/creduce/SKILL.md \
&& curl -LsS --compressed 'https://web.archive.org/web/20230530222757id_/https://embed.cs.utah.edu/creduce/using/' | python3 -c "import sys, html; print(html.unescape(sys.stdin.read().strip()))" > ~/.claude/skills/creduce/using.html \
&& curl -LsS --compressed 'https://web.archive.org/web/20230530222757id_/https://embed.cs.utah.edu/creduce/'       | python3 -c "import sys, html; print(html.unescape(sys.stdin.read().strip()))" > ~/.claude/skills/creduce/creduce.html
}

@h2{Clang 21 Port}

I also discovered that upstream creduce supports LLVM 18 at the latest. While there are open PRs for LLVM 19 and LLVM 20 support, the world has now moved on to LLVM 21 and the project did not build.

Solving this problem was a simple LLM-assisted matter of feeding each compiler error into the model and asking for the root cause of the error plus a fix recommendation. I believe this saved time over reading changelogs and poring over header files myself.

I opted to provide compiler errors one-at-a-time to manage the context size. What also made this approach work well was copying both the LLVM 20 and LLVM 21 headers into the project directory so the model could see what signatures changed between versions.

I submitted the resulting patches in PR @gh-pr{https://github.com/csmith-project/creduce/pull/289}.
