# Git Cheatsheet

---

## Базові команди

```bash
# ─── Стан ─────────────────────────────────────────────────────────────
git status                      # детально
git status --short              # коротко (M=modified, A=added, ?=untracked)
git diff                        # unstaged зміни
git diff --staged               # staged зміни (що піде в commit)
git diff --stat                 # короткий summary змін

# ─── Логи ─────────────────────────────────────────────────────────────
git log --oneline --decorate -20    # останні 20 коротко
git log --oneline --graph --all     # всі гілки у вигляді графу
git show HEAD                       # останній commit деталі

# ─── Гілки ────────────────────────────────────────────────────────────
git branch                      # список гілок
git branch -a                   # всі гілки (включно з remote)
git checkout -b feature/my-fix  # нова гілка + перейти
git switch main                 # перейти на main (Git 2.23+)

# ─── Staging і commit ─────────────────────────────────────────────────
git add notes_app/models.py     # додати конкретний файл
git add -p                      # інтерактивний staging (по частинах)
git commit -m "feat: add ChatMessage model"
git commit --amend              # змінити останній commit (тільки локально!)

# ─── Remote ───────────────────────────────────────────────────────────
git remote -v                   # remote URL
git fetch origin                # оновити info про remote
git pull origin main            # fetch + merge
git push origin feature/my-fix  # відправити гілку

# ─── Stash ────────────────────────────────────────────────────────────
git stash                       # тимчасово зберегти зміни
git stash list                  # список stash записів
git stash pop                   # відновити останній stash
git stash drop stash@{0}        # видалити stash

# ─── Скасування ───────────────────────────────────────────────────────
git checkout -- file.py         # скасувати unstaged зміни у файлі
git restore --staged file.py    # unstage файл
git reset HEAD~1                # скасувати останній commit (зміни залишаються)
git revert HEAD                 # скасувати commit новим commit (безпечно)
```

---

## Корисні сценарії

```bash
# Подивитися що змінилось у конкретному commit:
git show abc1234

# Знайти в якому commit з'явився рядок:
git log -S "socket_timeout" --oneline

# Переглянути хто і коли змінив кожен рядок файлу:
git blame notes_project/settings.py

# Порівняти дві гілки:
git diff main..feature/my-fix

# Скинути файл до стану у HEAD:
git checkout HEAD -- notes_app/consumers.py

# Cherry-pick — взяти конкретний commit з іншої гілки:
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

# Структура:
# <type>: <short description>
# (пустий рядок)
# Опціональне довше пояснення
#
# Types: feat, fix, docs, refactor, test, chore, style, perf
```

---

## .gitignore для Django проєкту

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

# Environment — НІКОЛИ не комітити!
.env
*.env

# Docker
docker-compose.override.yml

# IDE
.vscode/
.idea/
*.swp
```
