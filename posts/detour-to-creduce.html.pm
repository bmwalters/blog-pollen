#lang pollen

@slug{detour-to-creduce}
@title{Detour: to creduce}
@created{2026-01-04}
@synopsis{An introduction to the creduce tool plus a reusable LLM agent skill definition for it.}
@; TODO: @license{}... but does that apply to the rendered content or this source file (or both?)

creduce is a tool to automatically create a minimal reproduction case from interesting code.

I thought I had a use case for exactly this when I was working on @article-anchor['bootstrapping-bun]{making Bun bootstrappable} (porting its build scripts from Bun itself to widely available tools).

Here's the reduction script I built up, followed by a description of each check:

@code[#:lang "js"]{
$ cat reduce-test1.sh
#!/bin/sh
ulimit -c 0 && \
sed 's/@"@"//g' < assert.js | node && \
cp assert.js /work/bun/build/debug/js/node/assert.js && \
/work/bun/build/debug/bun-debug -e 'import assert from "assert"; console.log(assert);' 2>&1 | rg "Unexpected end of script"
$ creduce --not-c reduce-test1.sh assert.js
...
}

@ol{
  @li{Not part of the check; prevent dumping core on SIGABRT (slow).}
  @li{Ensure the test case is parseable as JavaScript. Could have used jsc. Needs to strip @"@" syntax for JSC builtins.}
  @li{Swap the test case in for our builtin and ensure the error continues to reproduce.}
}

Of course in practice I began with (3) alone and added (1) and (2) as I learned :)

And here's the output:

@details{
  @summary{Reduced failure case}
  @code[#:lang "js"]{
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
}

Beautiful, compared to a ~22,000 line file.

In the end though this debugging strategy did not bear fruit for my particular problem. Visually inspecting the minimal code confirmed that nothing about the shape of the code was likely to be the direct cause of the crash.

I was glad to get some practice with creduce though.

@h2{Agent Skill}

creduce currently has no man page. As a quick workaround, I've packaged the creduce docs as an [[agent skill]] to be used in future projects. The skill consists of three files: `SKILL.md`, `using.html`, and `creduce.html` (history). It can be installed with this command:

@code[#:lang "sh"]{
mkdir -p ~/.claude/skills/creduce && \
echo '---
name: creduce
description: create a minimal reproduction case from interesting code
---

* Detailed usage: using.html
* History & credits: creduce.html' > ~/.claude/skills/creduce/SKILL.md && \
curl -LsS --compressed 'https://web.archive.org/web/20230530222757id_/https://embed.cs.utah.edu/creduce/using/' | python3 -c "import sys, html; print(html.unescape(sys.stdin.read().strip()))" > ~/.claude/skills/creduce/using.html && \
curl -LsS --compressed 'https://web.archive.org/web/20230530222757id_/https://embed.cs.utah.edu/creduce/' | python3 -c "import sys, html; print(html.unescape(sys.stdin.read().strip()))" > ~/.claude/skills/creduce/creduce.html
}

@h2{Clang 21 Port}

I also discovered that upstream creduce supports LLVM 18 at the latest. While there are open PRs for LLVM 19 and LLVM 20 support, the world has now moved on to LLVM 21, with which the project did not bild.

Solving this problem was a simple LLM-assisted matter of feeding each compiler error into the model and asking for the root cause of the error and the how to fix. I believe this saved time over reading changelogs and poring over header files myself.

I opted to provide compiler errors one-at-a-time to finely control the context. What made this approach work well was copying both the LLVM 20 and LLVM 21 headers into the project directory so the model could see what signatures changed between versions.

I submitted the resulting patches in PR @gh-pr{https://github.com/csmith-project/creduce/pull/289}.
