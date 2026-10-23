# Git Cheatsheet

---

## Basic commands

```bash
# ─── Status ───────────────────────────────────────────────────────────
git status                      # detailed
git status --short              # short (M=modified, A=added, ?=untracked)
git diff                        # unstaged changes
git diff --staged               # staged changes (what goes into the commit)
git diff --stat                 # short summary of changes

# ─── Logs ─────────────────────────────────────────────────────────────
git log --oneline --decorate -20    # last 20, short form
git log --oneline --graph --all     # all branches as a graph
git show HEAD                       # details of the last commit

# ─── Branches ─────────────────────────────────────────────────────────
git branch                      # list branches
git branch -a                   # all branches (including remote)
git checkout -b feature/my-fix  # new branch + switch to it
git switch main                 # switch to main (Git 2.23+)

# ─── Staging and commit ───────────────────────────────────────────────
git add notes_app/models.py     # add a specific file
git add -p                      # interactive staging (in chunks)
git commit -m "feat: add ChatMessage model"
git commit --amend              # amend the last commit (local only!)

# ─── Remote ───────────────────────────────────────────────────────────
git remote -v                   # remote URL
git fetch origin                # update remote info
git pull origin main            # fetch + merge
git push origin feature/my-fix  # push the branch

# ─── Stash ────────────────────────────────────────────────────────────
git stash                       # temporarily save changes
git stash list                  # list stash entries
git stash pop                   # restore the last stash
git stash drop stash@{0}        # delete a stash

# ─── Undo ─────────────────────────────────────────────────────────────
git checkout -- file.py         # discard unstaged changes in a file
git restore --staged file.py    # unstage a file
git reset HEAD~1                # undo the last commit (changes are kept)
git revert HEAD                 # undo a commit with a new commit (safe)
```

---

## Useful scenarios

```bash
# See what changed in a specific commit:
git show abc1234

# Find the commit in which a line appeared:
git log -S "socket_timeout" --oneline

# See who changed each line of a file and when:
git blame notes_project/settings.py

# Compare two branches:
git diff main..feature/my-fix

# Reset a file to its state in HEAD:
git checkout HEAD -- notes_app/consumers.py

# Cherry-pick — take a specific commit from another branch:
git cherry-pick abc1234
```

---

## Commit message convention

```
feat: add GroupChatConsumer WebSocket support
fix: resolve TimeoutError in RedisChannelLayer
docs: add deployment checklist
refactor: move ORM queries to selectors.py
test: add WebsocketCommunicator tests for consumers
chore: update requirements.txt dependencies

# Structure:
# <type>: <short description>
# (blank line)
# Optional longer explanation
#
# Types: feat, fix, docs, refactor, test, chore, style, perf
```

---

## .gitignore for a Django project

```gitignore
# Python
__pycache__/
*.py[cod]
*.egg-info/
dist/
build/
.venv/
venv/

# Django
*.sqlite3
/staticfiles/
/media/
local_settings.py

# Environment — NEVER commit!
.env
*.env

# Docker
docker-compose.override.yml

# IDE
.vscode/
.idea/
*.swp
```
