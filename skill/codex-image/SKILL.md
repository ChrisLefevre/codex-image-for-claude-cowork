---
name: codex-image
description: Generate, vary or edit images with the user's Codex (ChatGPT) subscription on their Mac, from a chat, Claude Code or an unattended automation, without an image API key. Use for article covers, social posts, illustrations, landing page visuals, product shots.
---

# codex-image (for Claude Cowork)

Claude writes the brief and checks the result; Codex (with the user's ChatGPT
subscription) draws the image on the user's Mac. Everything goes through one command:

```
$HOME/.codex-image/bin/codex-image
```

Reply to the user in their language. Use this skill whenever the user, or an automation
you are running, needs an image, unless they ask for another tool.

## 1. Pick the execution route

| Where Claude runs | How to run a command on the Mac |
|---|---|
| In the cloud, linked to the Mac through the Claude desktop app (Cowork conversations and scheduled tasks, the main use) | Use the "Control your Mac" tool (osascript), wrapping each command in `do shell script "..."`. Load it with a tool search if it is deferred. |
| On the Mac (Claude Code, or a local shell tool) | Run the command directly in the shell. |

If neither is available, say the Mac is not reachable and stop (no other image tool
without the user's consent). A Linux VM shell that only sees mounted folders cannot run
Codex: it is not the Mac.

Before the first image of a session, run `codex-image doctor --json`. If `ready` is
false, report the failing checks and their `fix`, then stop.

## 2. Write the brief (the real work)

- Find ONE strong visual idea that carries the message (metaphor, contrast, tension),
  not a literal illustration. Avoid AI clichés: glowing blue robot, luminous brain,
  human and robot hands touching, circuit boards.
- Write it in English, 80 to 180 words: format, subject, scene, composition, light,
  palette, medium/style. Formats: 16:9 for an article cover, 1:1 or 4:5 for a post,
  9:16 for a story.
- End with `No text, no logos.` unless text is requested (then quote the exact text,
  its placement, once).
- Never brands, protected characters, or identifiable real people. One exception: the
  user's own face (or someone who consented) from a reference photo they provided.
- Through osascript: no double quotes and no backslashes in the brief.
- Clear request or unattended run: go straight to generation. Vague request with the
  user present: propose the idea in one or two sentences first.

## 3. Generate

Write the brief with a quoted heredoc and start the job in the background:

```
B=$(mktemp); cat > $B <<'EOF'
$imagegen <BRIEF>
EOF
$HOME/.codex-image/bin/codex-image generate $B --name <short-slug>
```

Through osascript, the same thing inside `do shell script "..."` (newlines are allowed).

Options: `--image /path/ref.png` attaches a reference (edit an existing image, or keep a
person's likeness: say in the brief "Use the attached photo as the identity reference").
`--plan plan.json` runs several directions (default 3 when the user asks for options,
max 8), each with its own brief file next to the plan:

```json
{"title": "Cover", "jobs": [
  {"id": "a-photo", "label": "Film photo", "prompt_file": "a.txt"},
  {"id": "b-graphic", "label": "Graphic composition", "prompt_file": "b.txt"}
]}
```

Directions must differ by a real choice (scene, medium, composition), not details.
To edit: new run with `--image <original.png>` and a brief that says exactly what to
change and what to keep identical. Never overwrite the original.

`generate` prints JSON with `out_dir`. Keep it.

## 4. Wait

An image takes about one minute. Poll with `codex-image wait <out_dir> 20` (it never
sleeps more than 25 s, the osascript limit) until `"status": "complete"`, about six
tries at most. On `failed`, read `<out_dir>/run/worker.log` and explain the error. Do not
relaunch automatically after an ambiguous timeout.

## 5. Finish, check, deliver

`codex-image finish <out_dir> <readable-name>` (add `--open` when the user is at the
Mac) creates a JPEG next to the PNG and prints its path and size.

Look at the image before delivering it:
- If Claude runs on the Mac, read the JPEG directly.
- From the cloud, the output folder (default `~/Desktop/codex-images`) must be shared
  with this conversation or task. Request access to it once if possible, stage the JPEG,
  read it, then send it to the user or use it in the automation.
- If the image cannot be retrieved, give its path and ask the user to look.

Check: the idea reads at first glance, composition, anatomy, unwanted text, defects.
One targeted repair at most per rejected image. Then answer in two lines: where the
file is, what it shows, and "Which one, and what should we change?" when the user is
present.

## Unattended automations

When nobody is watching (scheduled task, pipeline): do not ask questions, pick the
strongest idea, generate one image unless told otherwise, check it, use it in the next
step of the task, and log the file path and the brief in the final report. If Codex
fails (login expired, quota reached, Mac asleep), report it clearly and continue the
rest of the task without the image.
