# 04. Files, Permissions, and Users

## Why this matters

Linux is a multi-user system. Several people, several programs, and several services can all work on one server. To keep them from getting in each other's way and from accessing each other's data, Linux uses a permissions system.

As a Python/Django developer, you'll regularly run into `Permission denied` errors. To fix them, you need to understand how permissions work.

---

## A simple explanation

> Imagine that every file is a folder of documents. Permissions are the locks: who can read, who can edit, who can run.

Every file and directory in Linux has:
- an **owner** (user/owner) — usually whoever created the file
- a **group** (group) — a set of users with shared permissions
- **permissions** (permissions) — what can be done with the file

---

## How to read permissions

Run `ls -la` and you'll see lines like this:

```text
-rwxr-xr--  1  student  www-data  4096  Jun 10 12:00  manage.py
^            ^     ^        ^        ^                    ^
type+perms  links owner   group    size                  name
```

### The first character — the file type

| Character | Type |
|---|---|
| `-` | Regular file |
| `d` | Directory |
| `l` | Symbolic link |

### The next 9 characters — the permissions

```text
rwxr-xr--
^^^       — owner permissions (owner)
   ^^^    — group permissions (group)
      ^^^ — permissions for everyone else (others)
```

### What r, w, x mean

| Character | Name | For a file | For a directory |
|---|---|---|---|
| `r` | read | Can read the contents | Can see the list of files |
| `w` | write | Can modify and delete | Can create/delete files |
| `x` | execute | Can run it as a program | Can enter it with `cd` |
| `-` | no permission | — | — |

### A worked example

```text
-rwxr-xr--

-    = regular file
rwx  = the owner can: read, write, execute
r-x  = the group can: read, execute (write — NO)
r--  = everyone else can: only read
```

---

## Numeric permissions (octal)

Permissions are often written as numbers:

| Character | Number |
|---|---|
| `r` | 4 |
| `w` | 2 |
| `x` | 1 |
| `-` | 0 |

The permissions for each set are the sum of the numbers:

```text
rwx = 4+2+1 = 7
r-x = 4+0+1 = 5
r-- = 4+0+0 = 4
--- = 0+0+0 = 0
```

**Typical combinations:**

| Number | Characters | Meaning |
|---|---|---|
| `755` | `rwxr-xr-x` | Owner: everything; Group and Others: read and execute |
| `644` | `rw-r--r--` | Owner: read+write; Everyone: read only |
| `600` | `rw-------` | Only the owner can read and write |
| `777` | `rwxrwxrwx` | Everyone can do everything (dangerous!) |

---

## The chmod command — changing permissions

```bash
chmod +x script.sh          # add the execute permission for everyone
chmod -x script.sh          # remove the execute permission
chmod 755 script.sh         # set specific permissions
chmod 644 settings.py       # typical for config files
chmod -R 755 /var/www/      # recursively for a directory
```

**Explanation:**
```bash
chmod +x script.sh
```
`chmod` — change mode. `+x` — add (`+`) the execute permission (`x`). Without it, Linux will refuse to run the file as a script.

```bash
chmod 600 ~/.ssh/id_rsa
```
A private SSH key must have `600` permissions — only the owner can read it. If the permissions are broader, SSH will refuse to connect.

---

## The chown command — changing the owner

```bash
chown student file.txt              # change the owner
chown student:www-data file.txt     # change the owner and group
chown -R www-data /var/www/         # recursively
```

**When you need it:**
If you copied files via `scp` or `sudo`, root may become the owner. Then Nginx or Gunicorn won't be able to read the files.

---

## What sudo is

```bash
sudo apt update
sudo systemctl restart nginx
sudo nano /etc/nginx/nginx.conf
```

`sudo` — Superuser Do. Lets you run a command with superuser (root) privileges, even if you're a regular user.

> Imagine you're renting an apartment. Regular commands are what you can do in your own room. `sudo` is asking the landlord (root) to do something in the shared areas.

**Why you shouldn't work as root all the time:**

1. A mistake in a command can destroy the system without warning
2. Programs started as root have access to everything
3. If a service is hacked, the attacker gets root privileges
4. The normal working mode is as a regular user

---

## The whoami and id commands

```bash
whoami          # the current user's name
id              # uid, gid, and all of the user's groups
id student      # the groups of a specific user
```

---

## A practical example — a Django project on a server

```bash
# View the project files' permissions
ls -la /var/www/myapp/

# Make the startup script executable
chmod +x /var/www/myapp/start.sh

# Hand the files over to the Nginx user
sudo chown -R www-data:www-data /var/www/myapp/static/

# Make the config accessible only to the owner
chmod 600 /var/www/myapp/.env
```

---

## Common beginner mistakes

**Mistake 1:** `Permission denied` when running a script
> Run `chmod +x script.sh`

**Mistake 2:** `Permission denied` when working with Nginx/static
> Check that the Nginx process (`www-data`) has read permission on the directory

**Mistake 3:** Setting `chmod 777` on all files "just to make sure it works"
> This is dangerous. Any program on the server will be able to modify your files. Use the minimum necessary permissions.

**Mistake 4:** The SSH key isn't accepted
> Check: `chmod 600 ~/.ssh/id_rsa` and `chmod 700 ~/.ssh/`

---

## Practical exercise

### Task 1
```bash
touch test_file.py
ls -la test_file.py
```
What permissions does the newly created file have? What does each character mean?

### Task 2
```bash
chmod +x test_file.py
ls -la test_file.py
chmod 644 test_file.py
ls -la test_file.py
chmod 755 test_file.py
ls -la test_file.py
```
Follow how the permissions change after each command.

### Task 3
```bash
mkdir secret_config
touch secret_config/.env
echo "SECRET_KEY=abc123" > secret_config/.env
chmod 700 secret_config/
chmod 600 secret_config/.env
ls -la secret_config/
ls -la secret_config/.env
```
Explain what you did and why these permissions are the right choice for secret files.

---

## Self-check

- [ ] I can read the output of `ls -la` and explain each permission character
- [ ] I understand the difference between `r`, `w`, `x` for files and directories
- [ ] I know the numeric form of permissions: `755`, `644`, `600`
- [ ] I can change permissions with `chmod`
- [ ] I can change the owner with `chown`
- [ ] I understand what `sudo` is and why you shouldn't be root all the time

---

## Short summary

Permissions protect files from unauthorized access. Every file has an owner, a group, and permissions (r/w/x) for three categories. `chmod` changes permissions, `chown` changes the owner, `sudo` grants temporary root privileges. The next step is processes, ports, and services.
