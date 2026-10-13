# codex-image for Claude Cowork

**Let Claude (the desktop app, Cowork mode) create images inside its tasks and automations, with your ChatGPT subscription, on your Mac.**

[Version française](README.md)

## Why Cowork, not Claude Code

For Claude Code, Codex image generation already exists ([JunSeo99's codex-imagegen](https://github.com/JunSeo99/claude-skill-codex-imagegen)): Claude Code runs on your Mac and calls Codex directly.

The Claude app (Cowork) is different. Claude works in the cloud: it cannot see your Mac, cannot run Codex, and its scheduled tasks run without you. So whenever an automation needed an image (article cover, post visual, newsletter illustration), a human had to step in: open another tool, retype a prompt, download the file, hand it back to Claude.

This repository is the bridge. From the cloud, Claude drives your Mac through the "Control your Mac" extension, runs Codex, waits for the image, gets it back through the shared folder, checks it and uses it in the rest of the task. Without you, including in a scheduled task running at night.

What was added to make it work from Cowork:
- one command (`codex-image`) with JSON answers, callable from AppleScript;
- waiting split into slices of 25 s max, the limit of one "Control your Mac" call;
- briefs passed as files, with no quotes or backslashes that would break AppleScript;
- the image brought back into the conversation through the shared folder;
- an unattended mode for scheduled tasks (no questions, one repair at most, file path reported);
- automatic choice of the right Codex version, because the PATH seen by AppleScript is not your Terminal's.

Claude Code can use it too (the skill can run the command directly), but that is not its purpose.

<p align="center"><img src="assets/example.jpg" width="360" alt="Image generated end to end by Claude through codex-image"></p>

```
Claude in the cloud (Cowork conversation or scheduled task)
   │  writes the brief, drives the Mac through "Control your Mac"
   ▼
Your Mac ── codex-image ── Codex CLI ── your ChatGPT subscription
   │  PNG + JPEG in ~/Desktop/codex-images
   ▼
Claude gets the image back through the shared folder, checks it and uses it (article, post, email…)
```

## Requirements

- A **Mac** (Apple Silicon or Intel).
- A **ChatGPT subscription**. The entry plan (about $6 a month) is enough; that is what was tested. No API key, no per-image billing. Image quotas depend on your plan and prices vary by country.
- **The Claude desktop app** (Cowork) open on the Mac, with the "Control your Mac" extension enabled. Claude Code works too, as a bonus.
- About **2 GB free** on disk.

The installer checks and installs the rest: Command Line Tools, Python 3.9+, Node 18+, Codex CLI 0.153.4+.

## Install

```bash
git clone https://github.com/ChrisLefevre/codex-image-for-claude-cowork.git
cd codex-image-for-claude-cowork
scripts/doctor.sh      # diagnosis only, changes nothing
scripts/install.sh     # installs what is missing, asking before each step
```

The doctor checks macOS, disk space, Command Line Tools, Python, Node, Codex version, Codex login with ChatGPT, the `codex-imagegen` skill, the Codex 0.162 patch and the output folder. It also catches the most common trap: **an old Codex (often from Homebrew) earlier in the PATH than the right one**. codex-image always uses the most recent version it finds.

The installer:
1. installs Node and Codex CLI if needed (`npm install -g @openai/codex@latest`);
2. runs `codex login` (sign in with your ChatGPT account in the browser);
3. installs [JunSeo99's codex-imagegen skill](https://github.com/JunSeo99/claude-skill-codex-imagegen) (MIT);
4. applies the Codex 0.162 compatibility patch (see below);
5. installs `~/.codex-image/bin/codex-image` and its config;
6. copies the `codex-image` skill to `~/.claude/skills` for Claude Code.

Use `scripts/install.sh --output ~/Pictures/codex-images` to change the image folder (default `~/Desktop/codex-images`).

Then:
- **Claude app**: import `dist/codex-image.zip` in the app's skills settings. This is what makes image generation available in all your Cowork conversations and tasks.
- **Share the image folder** with the conversation or task in the Claude desktop app ("+" button, "Add folder"), so Claude can read the images back.

Test:

```bash
echo "A red apple on a white table, square 1:1. No text." | ~/.codex-image/bin/codex-image generate - --name test
~/.codex-image/bin/codex-image wait ~/Desktop/codex-images/<date>-test
~/.codex-image/bin/codex-image finish ~/Desktop/codex-images/<date>-test apple --open
```

## The codex-image command

Every subcommand answers in JSON so an automation can parse the result.

| Command | Purpose |
|---|---|
| `codex-image generate BRIEF \| - [--name slug] [--image ref.png] [--plan plan.json]` | Starts a background job, returns `out_dir` |
| `codex-image wait DIR [seconds]` | Waits (25 s max) then prints the status |
| `codex-image status DIR` | Job status, without calling Codex |
| `codex-image finish DIR [name] [--open]` | Creates the JPEG, returns paths and size |
| `codex-image doctor [--json]` | Full diagnosis |

## In an automation

See [examples/automations.md](examples/automations.md) for scheduled task prompts. In unattended mode the skill asks no questions, picks one strong idea, generates one image, checks it, allows one repair at most and logs the file path. If Codex fails (Mac asleep, login expired, quota reached), the task goes on without the image and says so.

## The Codex 0.162 patch

From Codex CLI 0.162, Codex no longer always returns the image path in its structured answer. The image exists, but the original launcher fails and loses it. `patches/codex-cli-0.162.patch` recovers the PNG that appeared during the run, checking that it lives in Codex's folder, is a real PNG and is newer than the launch. Run batches sequentially (`--workers 1`) when several generations run at once. If upstream fixes it, the installer detects it and skips the patch.

## Troubleshooting

- **"Operation not permitted" when Claude drives the Mac**: macOS protects Desktop, Documents and Downloads. Allow the Claude app in System Settings, Privacy & Security, Files and Folders (or Full Disk Access), or pick an output folder outside those places with `--output`.
- **"codex did not return an existing PNG"**: the 0.162 patch is missing. Run `scripts/install.sh` again.
- **Codex still too old after an update**: two installs coexist (Homebrew and npm). `scripts/doctor.sh` shows which one is used.
- **Generation fails**: read `<folder>/run/worker.log`. Usually an expired login (`codex login`) or the plan's quota.

## Limits

- **macOS only** for now.
- Cloud control relies on the Claude desktop app's "Control your Mac" extension: the app must be open and the Mac awake. These Claude features may change.
- Codex manages the image model: it cannot be chosen and resolution is not guaranteed (about 1254 × 1254 square in tests).
- Follow OpenAI's policies and image rights: no brands, no protected characters, no real person without consent.

## Uninstall

```bash
rm -rf ~/.codex-image ~/.claude/skills/codex-image /usr/local/bin/codex-image
```

## Credits

- Generation: OpenAI [Codex CLI](https://github.com/openai/codex).
- Image launcher: [claude-skill-codex-imagegen](https://github.com/JunSeo99/claude-skill-codex-imagegen) by JunSeo99, MIT.
- codex-image (Claude orchestration, doctor, installer, 0.162 patch): Chris Lefevre, MIT.

Independent project, not affiliated with Anthropic or OpenAI.
