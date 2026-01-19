# Unofficial bootstrappable build for Bun

I perceive a productivity gain from LLM-assisted coding and I wanted to use the technique on a few of my upcoming projects. The current landscape includes a wide array of tools, but after a bit of research I settled on OpenCode as the frontend that I wanted to try. Installing OpenCode proved no easy task however. OpenCode [depends](https://github.com/anomalyco/opencode/issues/3877) on the Bun suite of JavaScript tools. Neither OpenCode nor Bun were packaged for my distro. The aur unfortunately did not come to the rescue here—the latest revision failed to build. 

/Note: Bun was packaged for Arch Linux on 2025-12-30 🎉! However Debian, Fedora, and Ubuntu [still do not package it](https://repology.org/project/bun/information)./

I also uncovered an unfortunate dependency: there was no clearly documented process for /bootstrapping/ Bun; its build process unabashedly invokes the Bun CLI, assuming it was previously built. The development Dockerfiles and CI scripts for the Bun repo simply download the binary from a prior revision.

Sure, I trust binaries built by open source GitHub actions at a level of about 99%. However I /completely/ trust packages built by myself or signed by my distro's maintainers. I decided to pursue that incremental 1% (which I also suspected would be worthwhile [for others](https://github.com/oven-sh/bun/issues/22991) for whom the [supply chain](https://reproducible-builds.org/) is also not optimal).

## Exploratory work

I didn't have Bun on my system, but I did have Node. My first thought was to create a `bun-wrapper` script that would primarily log how and from where it was invoked, then also to try its best to fulfill the CLI contract expected by the build scripts using tools I did have. I reasoned that this approach would tease out the dependencies that the build scripts actually have on the system Bun install in a faster and more targeted way than grepping and reading through lots of build script code. In an ideal world, the script would evolve to have enough functionality to complete the build.

In the end a mixture of techniques was needed. The wrapper script was useful for getting the big picture of what subcommands were needed, but it was hard to fulfill the contract needed by the script's callers without reading them. Becoming more familiar with the build scripts also gave me some idea of the scale of the task (manageable) that I was previously only guessing at.

## Bun's filling

What follows is an edited version of [an RFC](https://github.com/oven-sh/bun/pull/25820) that I sent to the Bun maintainers detailing my approach.

I concluded that Bun's build scripts depend on Bun to fill three key roles:

* As a package manager.
* As a TypeScript runtime.
* As a bundler.

I developed a separate approach in each case to allow the build scripts to use widely available tools for these tasks.

(At some point I also ditched the wrapper script in favor of invoking replacement tools directly, swapping in those replacements across the board or via CMake defines.)

### Build-time package installation

This was the simplest change. It turns out that Bun's package.json has not diverged much from what Node and npm support. The only modification I needed was to replace the `workspace:<ver>` version specifier for workspace-local dependencies with simply `<ver>`. The behavior for both patterns seems to be the same and to match maintainer intent in both Bun and npm.

After that came the simple matter of introducing a new CMake option to defining some `-DNPM_EXECUTABLE`, which defaults to `${BUN_EXECUTABLE}` but can be set to `/path/to/npm` for bootstrapping.

One here-there-be-dragons encounter was in `cppbind.ts`. The script was helpfully(?) written to [shell out to `bun install`](https://github.com/oven-sh/bun/blob/main/src/codegen/cppbind.ts#L57-L78) in its own directory if it detected that package dependencies were not yet installed. I replaced this with CMake orchestration to [*declare* package installation as a dependency](https://github.com/bmwalters/bun/commit/5da4de10cdacc027f6649fc0fe24722722048fad) of this script in the build DAG.

### Interpreter / type stripping

Bun's JavaScript runtime exposes several methods and classes in the `Bun` namespace that the JS ecosystem, including the Bun build scripts, have started to rely on.

For the most part, it was easy to shift from APIs like `Bun.file` to the `node:fs` module. An exception was some complex classes like `Bun.Transpiler` for which my current best solution is to depend on a third-party package. It might be possible to package the underlying transpiler utility as a leaf that can be depended on by both codegen and the Bun runtime though.

Another handy feature of the Bun interpreter is that it can interpret TypeScript files without a prior explicit transpile step. I thought this might be tricky to replicate, but I was excited to learn that Node since v22.18 has supported [*type stripping*](https://nodejs.org/en/blog/release/v22.18.0#2025-07-31-version-22180-jod-lts-aduh95) to similarly interpret TS. After a few minor syntax changes (primarily to replace declarations that were actually used at runtime with real values, e.g. `declare unique symbol` --> `Symbol`), this feature worked great.

### Build-time bundling / transpiling

Several of the code generation scripts are responsible for taking code written in TypeScript and transpiling it to JavaScript. For example, the builtin modules provided by Bun for scripts to use are developed in TypeScript and may depend on other files, but when the builtins are provided to JavaScriptCore (the underlying runtime which powers Bun), these abstractions must have been previously bundled / transpiled away.

Bun's implementation seems to descend in part from esbuild, a pioneer in making tools for JavaScript run in a reasonable amount of time. I figured employing esbuild for build-time bundling would thus be both easier to plug in to the Bun repository and also less objectionable to the Bun maintainers than alternatives.

Drafting the initial set of code changes was not a complex task. Most bundler options in use were easy to map. Shelling out to `bun build` or invoking `Bun.build` in code could both be replaced with `esbuild.build`. Where the task became more tricky was in actually assembling the binary and subsequently to load the bundled code at runtime.

#### zig panic

The first post-codegen issue I encountered was a panic in the Zig compiler. One with no stack trace to boot.

My debugging strategy was to first eliminate many variables at the same time. I knew that Bun uses [a fork of the Zig compiler](https://github.com/oven-sh/zig), and I also knew that prebuilt binaries might lack debug info and may even fail subtly on a new machine.

To move forward, I created a [side patch series](https://github.com/bmwalters/bun/commits/dev/upstream-zig) (not part of my main submission) to enable defining a local Zig compiler to use for the build, configured in a similar way to local WebKit/JavaScriptCore. This required CMake changes, but also some more interesting hacks.

With upstream Zig in place of the fork, I had to patch out any features that Bun's Zig code had on private patches. In practice, there was only one such feature, but a big one. There's a long-running feature request in the Zig issue tracker to [add support for private struct fields](https://github.com/ziglang/zig/issues/9909). I'm not qualified to opine on that debate, but I can observe that the Bun team leans strongly in favor of the proposal given that they forked Zig, *added this feature*, and rely on it extensively in the Bun codebase. Reverting to upstream Zig required [undoing this dependency](https://github.com/bmwalters/bun/commit/4765fbd8c7a4a2d66e2dbb778638dc67db29616d), which was luckily possible with string substitution: I simply prefixed `#private` members as public `_members`.

One last puzzling change was a linker error. When assembling the final binary consisting of Zig and C++ object files, symbols couldn't be found. `nm` on `bun-zig.o` showed that no symbols were exported, and furthermore the binary file was simply empty. I flailed here for a long time but what ultimately fixed the issue was building `bun-zig.o` as a static archive instead of an object file 🤷.

Since I opted to eliminate many variables at the same time, I'm unfortunately not sure what the problem was with the original binary (whether in the oven-sh patches or a binary incompatibility or something else). But I was unblocked; the build succeeded.

#### "Unexpected end of script"

I had a freshly baked `bun-debug` binary, but it couldn't `assert.strictEqual(2 + 2, 4);`. Importing and using the `assert` builtin produced the following quite opaque error.

```
Error parsing builtin: Unexpected end of script
[followed by SIGABRT and core dump]
```

I spun my wheels a little by reading through assert.js and by [using the creduce tool to produce a minimal reproduction of assert.js](detour-to-creduce) in the hopes that a problem in ~400 bytes would be more easy to eyeball than one in ~22,000.

In the end though, the winning debugging strategy was compiling WebKit's JavaScriptCore from source and swapping it in place of the vendored binary (similarly to how I swapped in my own Zig above). Added debug logging revealed that the builtin in question was actually `internal/util/inspect.js` (which was prepended to, or perhaps a dependency of, assert.js).

The case was blown wide open when the logs showed that the [postprocessing phase of builtin bundling](https://github.com/oven-sh/bun/blob/27ff6aaae0e925659c8f82ab6a4be17ec9c35a4a/src/codegen/bundle-modules.ts#L239-L267) erroneously appended `})` to the end of the file with no preceding newline. For any bundled file which ended with a comment, this left the closing brackets commented out, hence the unexpected end of script.

# Success

After solving the problems above I had a working build system, and better yet a working binary!

I packaged the bootstrapped build commands as a [quick and dirty PKGBUILD](https://gist.github.com/bmwalters/090d55610d3b517bba5411335b0165fb) and successfully used the resulting build to run OpenCode.

```sh
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
```

In the end, the only regret I have from time spent on this project is some [poor decisionmaking when using LLMs to assist me on the work](browser-llm-tools). Overall, I'm happy to have achieved my goal.

A lesson to tae away is that when you have the gift of an open source dependency, jump first to building it from source and using either a debugger or logs rather than treating it as a black box.

# Upstreaming patches

As alluded to earlier, I sent [an RFC](https://github.com/oven-sh/bun/pull/25820) to the Bun team to test the waters on whether these patches might be upstreamable. I tried to always choose the more maintainable option when faced with implementation decisions, so there is a chance. However I recognize that this is a big change to the build system and I won't be disappointed if the answer is no.

In the mean time, feel free to check out my fork at [bmwalters/bun](https://github.com/bmwalters/bun/tree/codegen-runtime-agnostic) and to try it for yourself.
