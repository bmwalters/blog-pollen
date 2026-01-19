#lang pollen

@define-meta[title]{Bootstrapping Bun}
@define-meta[author]{Bradley Walters}
@define-meta[created]{2026-01-18}
@define-meta[synopsis]{My journey building the Bun JavaScript runtime from source.}
@define-meta[tag-uri]{tag:walters.app,2026:bootstrapping-bun}

I wanted to try @a[#:href "https://opencode.ai/"]{OpenCode} for LLM-assisted coding. I found that it wasn't easy to install—my distro packaged neither OpenCode itself, nor Bun, the JavaScript runtime @a[#:href "https://github.com/anomalyco/opencode/issues/3877"]{used by} OpenCode. The aur didn't come to the rescue either as the latest revision of the Bun package failed to build.

@em{Note: Bun was packaged for Arch Linux on 2025-12-30 🎉! However Debian, Fedora, and Ubuntu @a[#:href "https://repology.org/project/bun/information"]{still do not package it}.}

I also uncovered an unfortunate dependency: there was no clearly documented process for @em{bootstrapping} Bun; its build process unabashedly invokes the Bun CLI, assuming it was previously built. The development Dockerfiles and CI scripts for the Bun repo simply download the binary from a prior revision.

I'll admit that I 99% trust binaries built by open source GitHub actions. However I @em{completely} trust packages built by myself or signed by my distro's maintainers. I decided to pursue that incremental 1% (since maybe @a[#:href "https://github.com/oven-sh/bun/issues/22991"]{others} could find it useful too).

@h2{Exploratory work}

I didn't have Bun on my system, but I did have Node. My first thought was to create some @code{bun-wrapper} script that would snitch on how and from where it was invoked. The script would also evolve to try to @em{fulfill} the calls it was receiving using alternative tools. I reasoned that this way of logging the dependencies that the build scripts have on Bun @em{in practice} would be faster than reading through lots of code.

In the end a mixture of techniques was needed. The wrapper script was useful for getting the big picture of what subcommands were needed, but it was hard to produce the output expected by the script's callers without reading the callsites. Becoming more familiar with the build scripts also gave me some idea of the scale of the task that I was previously only guessing at (it seemed manageable).

@h2{Bun's filling}

What follows is an edited version of @a[#:href "https://github.com/oven-sh/bun/pull/25820"]{an RFC} that I sent to the Bun maintainers detailing my end approach.

I concluded that Bun's build scripts depend on Bun to fill three key roles:

@ul{
@li{As a package manager.}
@li{As a TypeScript runtime.}
@li{As a bundler.}}

In each case I found the most suitable replacement tools for the tasks.

(At some point I also ditched the wrapper script in favor of invoking replacement tools directly, modifying build scripts to invoke them directly or in place of Bun via CMake defines.)

@h3{Build-time package installation}

First I tackled any use cases the build scripts had for installing npm dependencies. This was the simplest change.

It turns out that Bun's @code{package.json} has not diverged much from what Node and npm support. The only modification I needed was to replace the @code{workspace:<ver>} version specifier for workspace-local dependencies with simply @code{<ver>}. The behavior for both patterns seems to be the same and to match maintainer intent in both Bun and npm.

After that came the simple matter of introducing a new CMake option to allow defining @code{-DNPM_EXECUTABLE}, which defaults to @code{${BUN_EXECUTABLE}} but can be set to @code{/path/to/npm} for bootstrapping.

One here-there-be-dragons encounter was in @code{cppbind.ts}. The script was helpfully(?) written to @a[#:href "https://github.com/oven-sh/bun/blob/c47f84348a7ac99107b280660a2d89d646ea40b2/src/codegen/cppbind.ts#L57-L78"]{shell out to @code{bun install}} in its own directory if it detected that package dependencies were not yet installed. I replaced this with CMake orchestration to @a[#:href "https://github.com/bmwalters/bun/commit/5da4de10cdacc027f6649fc0fe24722722048fad"]{@strong{declare} package installation as a dependency} of this script in the build DAG.

@h3{Interpreter / type stripping}

The next task was to figure out how to interpret the TypeScript source files which comprise Bun's build scripts.

I observed that Bun's runtime exposes several methods and classes in the @code{Bun} namespace that the JS ecosystem, including the Bun build scripts, have started to rely on.

For the most part, it was easy to shift from APIs like @code{Bun.file} to the @code{node:fs} module. An exception was some complex classes like @code{Bun.Transpiler} for which my current best solution is to depend on a third-party package. It might be possible to package the underlying transpiler utility as a leaf that can be depended on by both codegen and the Bun runtime though.

Another handy feature of the Bun interpreter is that it can interpret TypeScript files without a prior explicit transpile step. I thought this might be tricky to replicate, but I was excited to learn that Node since v22.18 has supported @a[#:href "https://nodejs.org/en/blog/release/v22.18.0#2025-07-31-version-22180-jod-lts-aduh95"]{@strong{type stripping}} to similarly interpret TS. After a few minor syntax changes (primarily to replace declarations that were actually used at runtime with real values, e.g. @code{declare unique symbol} → @code{Symbol}), this feature worked great.

@h3{Build-time bundling / transpiling}

Finally I tackled Bun's bundling use case.

Several of the code generation scripts are responsible for taking code written in TypeScript and transpiling it to JavaScript. For example, the builtin modules provided by Bun for scripts to use are developed in TypeScript and may depend on other files, but when the builtins are provided to JavaScriptCore (the underlying runtime which powers Bun), these abstractions must have been previously bundled / transpiled away.

Bun's implementation seems to descend in part from esbuild, a pioneer in making tools for JavaScript run in a reasonable amount of time. I figured employing esbuild for build-time bundling would thus be both easier to plug in to the Bun repository and also less objectionable than alternatives to the Bun maintainers.

Drafting the initial set of code changes was not a complex task. Most bundler options in use were easy to map. Shelling out to @code{bun build} or invoking @code{Bun.build} in code could both be substituted with @code{esbuild.build}. Where the task became more tricky was in actually assembling the binary and subsequently to load the bundled code at runtime.

@h4{zig panic}

The first post-codegen issue I encountered was a panic in the Zig compiler. One with no stack trace to boot.

My debugging strategy was to eliminate many variables at the same time. I knew that Bun uses @a[#:href "https://github.com/oven-sh/zig"]{a fork of the Zig compiler}, and I also knew that prebuilt binaries might lack debug info and may even fail subtly on a new machine.

To move forward, I created a @a[#:href "https://github.com/bmwalters/bun/commits/dev/upstream-zig"]{side patch series} (not part of my RFC submission) to enable defining a local Zig compiler to use for the build in a similar way to how local WebKit/JavaScriptCore is configured. This required CMake changes, but also some more interesting hacks:

With upstream Zig in place of the fork, I had to patch out any features that Bun's Zig code had on private patches. In practice, there was only one such feature, but a big one. There's a long-running feature request in the Zig issue tracker to @a[#:href "https://github.com/ziglang/zig/issues/9909"]{add support for private struct fields}. I'm not qualified to opine on that debate, but I can observe that the Bun team leans strongly in favor of the proposal given that they @strong{forked Zig, added this feature, and rely on it extensively} in the Bun codebase. Reverting to upstream Zig required @a[#:href "https://github.com/bmwalters/bun/commit/4765fbd8c7a4a2d66e2dbb778638dc67db29616d"]{undoing this dependency}, which was luckily possible with string substitution: I simply prefixed @code{#private} members as public @code{_members}.

One last puzzling change was a linker error. When assembling the final binary consisting of Zig and C++ object files, symbols couldn't be found. @code{nm} on @code{bun-zig.o} showed that no symbols were exported, and furthermore the binary file was simply empty. I flailed here for a long time but what ultimately fixed the issue was building @code{bun-zig.o} as a static archive instead of an object file 🤷.

Since I opted to eliminate many variables at the same time, I'm unfortunately not sure what the problem was with the original binary (whether in the oven-sh patches or a binary incompatibility or something else). But I was unblocked; the build succeeded.

@h4{"Unexpected end of script"}

I had a freshly baked @code{bun-debug} binary, but it couldn't @code{assert.strictEqual(2 + 2, 4)}. Importing and using the @code{assert} builtin produced the following quite opaque error.

@pre-code[#:lang "txt" #:line-numbers? #f]{
Error parsing builtin: Unexpected end of script
[followed by SIGABRT and core dump]
}

I spun my wheels a little by reading through assert.js and by [using the creduce tool to produce a @article-a['detour-to-creduce]{minimal reproduction of assert.js} in the hopes that a problem in ~400 bytes would be more easy to eyeball than one in ~22,000.

In the end though, the winning debugging strategy was compiling WebKit's JavaScriptCore from source and swapping it in place of the vendored binary (similarly to how I swapped in my own Zig above). Added debug logging revealed that the builtin in question was actually @code{internal/util/inspect.js} (which was prepended to, or perhaps a dependency of, assert.js).

The case was blown wide open when the logs showed that the @a[#:href "https://github.com/oven-sh/bun/blob/27ff6aaae0e925659c8f82ab6a4be17ec9c35a4a/src/codegen/bundle-modules.ts#L239-L267"]{postprocessing phase of builtin bundling} erroneously appended @code{@"}")} to the end of the file with no preceding newline. For any bundled file which ended with a comment, this left the closing brackets commented out, hence the unexpected end of script.

@h2{Success}

After solving the problems above I had a working build system, and better yet a working binary!

I packaged the bootstrapped build commands as a @a[#:href "https://gist.github.com/bmwalters/090d55610d3b517bba5411335b0165fb"]{quick and dirty PKGBUILD} and successfully used the resulting build to run OpenCode. Without further ado, here's the bootstrapped Bun build command for use with my fork:

@pre-code[#:lang "sh" #:line-numbers? #f]{
node ./scripts/build.mjs \
	-GNinja \
	-DCMAKE_BUILD_TYPE=Release \
	-B build/release \
	--log-level=NOTICE \
	-DBUN_EXECUTABLE="$(which node)" \
	-DNPM_EXECUTABLE="$(which npm)" \
	-DZIG_EXECUTABLE="$(which zig)" \
	-DENABLE_ASAN=OFF \
	-DCACHE_STRATEGY=none
}

In the end, the only regret I have from time spent on this project is some @article-a['browser-llm-tools]{poor decisionmaking when using LLMs to assist me on the work}. Overall, I'm happy to have achieved my goal.

A lesson to take away is that when you have the gift of an open source dependency, jump first to building it from source and using either a debugger or logs rather than treating it as a black box.

@h2{Upstreaming patches}

As alluded to earlier, I sent @a[#:href "https://github.com/oven-sh/bun/pull/25820"]{an RFC} to the Bun team to test the waters on whether these patches might be upstreamable. I tried to always choose the more maintainable option when faced with implementation decisions, so there is a chance. However I recognize that this is a big change to the build system and I won't be disappointed if the answer is no.

In the mean time, feel free to check out my fork at @a[#:href "https://github.com/bmwalters/bun/tree/codegen-runtime-agnostic"]{bmwalters/bun} and to try it for yourself.
