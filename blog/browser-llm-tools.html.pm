#lang pollen

@define-meta[title]{Review: in-browser agentic coding}
@define-meta[author]{Bradley Walters}
@define-meta[created]{2026-01-05}
@define-meta[synopsis]{Lessons learned using LLM assistance for recent work (bootstrapping Bun).}
@define-meta[tag-uri]{tag:walters.app,2026:browser-llm-tools}

I recently worked on @article-a['bootstrapping-bun]{making Bun bootstrappable}, i.e. to remove the Bun repo's build scripts' reliance on a previously built binary. I used LLMs / coding agents to implement changes, troubleshoot problems, and suggest implementation choices and commit messages to varying degrees during that project. The experience left me with some regrets but also with some lessons learned.

@h2{GitHub Copilot + Codespaces}

Given the purpose of the project as a whole was to try to avoid binary native dependencies, I decided to first give a browser-based solution to my LLM-assistance-needs a try. I also figured I should at least be aware of how they've developed over the years. I picked up the free trial of GitHub Copilot and used it along with the free tier of GitHub Codespaces. I was able to be productive in this environment but only while wading through serious issues.

The biggest issue, and a blocker for agent-assisted development, is that the terminal tool seemed *broken*. Regardless of which model I tried, the symptoms were consistent: the first terminal tool call would run the command successfully and provide its output to the agent, but any terminal tool call made after that would fail with `ENOPRO: No file system provider found`, sending the agent into a depressive spiral. The only workaround I found to fix this was to delete the terminal (with the trash icon) after each command invocation. This meant that every command effectively required a human in the loop regardless of permission settings.

It didn't occur to me at the time to try deploying my own VSCode with more debugging enabled, but I also doubt that the issue would have been quick to solve, and I don't really want to hack on VSCode @a[#:href "https://github.com/blink-editor/blink"]{more than I already have}.

That was the biggest issue, but even if that were resolved I don't think I'd return to browser-based coding environments. I need them to be much more modifiable and introspectable given how many papercuts there were. As another example, markdown responses would occasionally fail to render, leaving me wondering about the agent's all-important conclusions (right click > Copy worked around this). And it would be impossible to untrain the @kbd{ctrl} + @kbd{w} (delete word) reflex that has already lost me minutes of time in Codespaces.

Lesson: Browser-based coding environments don't prioritize hackability.

@h3{Low cost model disappointment}

After I ran out of premium credits I first tried and quickly discarded the low cost models available in Copilot.

@ul{
@li{Gemini 3 Pro: bad prompt adherence}
@li{Grok Code Fast: not thinking very long; picking greedy solutions without reasoning through them or catching mistakes}
@li{GPT-4.1 and GPT-4o: simply unable to solve complex problems (these models were what originally gave me a poor impression of LLM-assisted coding)}}

@h2{Claude Code for Web}

With my Copilot usage exhausted I purchased Claude Pro and gave Claude Code for Web a try (remember: trying to avoid closed source native dependencies). Its tool use and problem solving strategies were similar to using Claude models through Copilot, but I was unfortunately not able to be productive at all with the tool given the inability to ssh into the machine the agent works in.

My type of project is not what the tool is designed for. For an agent to work on this task for a long time, a human needs to periodically inject insights that can't be found in the repo, and often the human needs to examine the machine to form these insights.

@h3{General agent-assisted coding pain points}

A couple times while working on a particular long-running problem, I'd catch myself repeatedly checking in on the agent, approving its permission requests, but ultimately not steering the agent to ensure real progress was being made. I lost a few hours this way.

A memorable example was when I needed to configure esbuild to produce output in the right format for Bun's JavaScriptCore builtins. I gave the model this task, but the model kept waffling between assuming the output should be esm, cjs, and an iife (or that the presence or lack of export statements was good or bad).

This wasn't an issue with a lack of specificity in the prompt, but it may well have been a compaction issue as these failed cases were within long-running agent sessions. I've realized though that even if I were to fix the context issues, I was bit by a more subtle prompt issue: I gave the model unclear (and insufficiently incremental) deliverables. In my experience are necessary for today's frontier models in complex tasks.

Another case in which I felt myself more prodded by the agent than vice versa was when I was working on a task that exhibited a slow feedback loop—i.e. a full rebuild of JS + C++ + Zig. The time and fatigue add up quickly when this is the case.

This is also not a problem that can be solved by prompting or context management alone given that models with their current capabilities will not start one-shotting more problems if we simply inform them that the tests take a long time. They still need to form incremental hypotheses and perform inner development loop cycles to make progress.

It seems the lesson here is simply to invest in the inner loop even if it feels like a departure from the main project goal. In this project, I could have spent more time on learning the CMake dependency tree and possibly on implementing more incremental build and live-reload features.

@h2{OpenCode}

Partway through the project, Bun was packaged for Arch Linux by maintainer @a[#:href "https://github.com/carlsmedstad" #:class "h-card p-name u-url"]{Carl Smedstad} (thank you!). While in some sense the project was scooped by this development, I was happy to now be unblocked to try out OpenCode on the bootstrapping effort itself.

I had a great experience with OpenCode in contrast to the browser-based tools, and in comparison to my use of Cursor at my day job. OpenCode seemed to manage context much better than Claude Code for Web, approaching usage limits at a much slower pace. I also appreciated its guardrails in tool use, such as prompting the model to re-read a file before making edits if the file has changed.

It seems like the OpenCode team either cares strongly about UX or has an intuitive feel for how a coding agent of today should work. Either way I look forward to continuing to use their tool.

@h2{Summary}

Lessons:

@ul{
@li{Browser-based coding environments, whether agent-driven or review-driven, are insufficiently hackable for my use cases.}
@li{Investing in inner loop performance (build, compile, test) is a worthwile productivity win even for unrelated projects.}
@li{OpenCode is nice.}}
