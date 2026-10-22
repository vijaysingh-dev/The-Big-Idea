> Shell used: **bash**. Most of this also works in zsh, which is the default shell on macOS.

---

## 1. Mental Model

- **Kernel:** the core of the OS that manages CPU, memory, disks and processes.
- **Shell:** a program (bash, zsh) that reads your commands and asks the kernel to run them.
- **Terminal:** the window that displays the shell. It isn't the shell itself.
- **Everything is a file:** devices (`/dev/sda`), processes (`/proc/<pid>`) and sockets all appear as files, so the same tools (`cat`, `grep`) work on all of them.

### How a command runs
1. The shell expands the line: variables, globs (`*.log`), `$(...)`, quotes.
2. It looks for the command: alias → function → **builtin** (part of the shell, like `cd`) → an executable found in `$PATH`.
3. It **forks** (creates a copy of itself as a child process) and **execs** (replaces that child with the program).
4. It waits, then stores the **exit code** in `$?`. **0 = success**, anything else = failure.

```bash
type ls          # what is "ls": alias, builtin or a file?
which python3    # which file in PATH runs
echo $PATH       # dirs searched, in order, separated by ":"
```
- `cd` must be a builtin: a child process changing directory wouldn't affect your shell.

### Filesystem layout (FHS: Filesystem Hierarchy Standard)
| Path | Holds |
|---|---|
| `/etc` | System config files |
| `/var/log` | Logs |
| `/usr/bin`, `/bin` | Programs |
| `/home/<user>` | User files (`~`) |
| `/tmp` | Temp files, often cleared on reboot |
| `/proc` | Live kernel/process info (virtual, not on disk) |
| `/dev` | Devices |
| `/opt` | Third-party software |

---

## 2. Files: Beyond the Basics

```bash
ls -lah             # long format, hidden files, human-readable sizes
ls -lt | head       # newest first
stat file           # size, permissions, timestamps, inode
file mystery.bin    # detect real file type (ignores extension)
tree -L 2           # directory tree, 2 levels deep
mkdir -p a/b/c      # create parents; no error if it exists
cp -r src/ dst/     # copy directory
rm -rf dir          # ⚠ no undo, no trash
```

### find (search by name, type, size, time, then act)
```bash
find . -name "*.log"                 # by name (quote the glob!)
find . -iname "readme*"              # case-insensitive
find . -type f -size +100M           # files over 100 MB
find /var/log -mtime -1              # modified in the last 24h
find . -type d -name node_modules -prune -o -name "*.js" -print   # skip a dir
find . -name "*.tmp" -delete
find . -name "*.py" -exec wc -l {} +     # run a command on results ({} = the files)
```
- `-mtime -1` = less than 1 day ago; `+7` = more than 7 days ago.
- 🧠 Prod: `find /var/log/app -name "*.gz" -mtime +30 -delete` is a classic cron cleanup job.

### Links
```bash
ln -s /opt/app/v2.3 /opt/app/current   # symlink (soft link)
ln file hardlink                        # hard link
```
- **Inode:** the record holding a file's data location and metadata. A filename is just a pointer to an inode.
- **Hard link:** another name for the same inode. The data survives until every name is deleted.
- **Symlink:** a small file containing a path. It breaks if the target moves.
- 🧠 Prod: release directories + a `current` symlink. Deploys switch the symlink in one step, and rollback means pointing it back.

### xargs (turn input lines into arguments)
```bash
find . -name "*.log" -print0 | xargs -0 rm         # -print0/-0 handle spaces in names
cat urls.txt | xargs -n 1 -P 8 curl -sO            # 8 downloads in parallel
grep -l "TODO" -r src | xargs sed -i 's/TODO/FIXME/g'
```

---

## 3. Permissions & Ownership

```
-rwxr-x---  1 vijay devs  4096  app.sh
│└┬┘└┬┘└┬┘     owner group
│ u  g  o
type (- file, d dir, l link)
```
| | File | Directory |
|---|---|---|
| `r` (4) | read contents | list names |
| `w` (2) | modify | create/delete files inside |
| `x` (1) | execute | enter (`cd`) |

```bash
chmod 755 script.sh        # rwx r-x r-x
chmod 600 ~/.ssh/id_ed25519  # private key: owner only (ssh refuses otherwise)
chmod u+x,g-w file         # symbolic form
chmod -R 750 dir
chown vijay:devs file
sudo -u postgres psql      # run as another user
umask                      # default permissions mask (022 → new files 644, dirs 755)
```
- Octal math: 7 = 4+2+1 = rwx, 5 = r-x, 6 = rw-.
- Special bits:
  - **setuid** (`4xxx`): the program runs as its owner (that's how `passwd` edits root-owned files).
  - **setgid on a dir** (`2xxx`): new files inherit the dir's group (shared team folders).
  - **sticky bit** (`1xxx`, shown as `t`): only a file's owner can delete it (`/tmp`).
- 🧠 Prod: `chmod 777` is never the fix. Find which user the process runs as (`ps -o user= -p PID`) and grant just that.

---

## 4. I/O Redirection & Pipes

Every process starts with three **file descriptors** (fd, numbered handles to open files/streams):
**0 = stdin** (input), **1 = stdout** (normal output), **2 = stderr** (errors).

```bash
cmd > out.txt          # stdout to file (overwrite)
cmd >> out.txt         # append
cmd 2> err.txt         # stderr only
cmd > all.txt 2>&1     # both into one file (order matters!)
cmd &> all.txt         # bash shorthand for the line above
cmd 2>/dev/null        # discard errors (/dev/null swallows everything)
cmd < input.txt        # file as stdin
cmd1 | cmd2            # stdout of cmd1 → stdin of cmd2
cmd |& cmd2            # pipe stdout + stderr
cmd | tee out.txt      # show on screen AND save
cmd | sudo tee /etc/x  # write a root-owned file (sudo cmd > file fails: redirect runs as you)
```
- `2>&1` means "send fd 2 to wherever fd 1 currently points". `cmd 2>&1 > f` still sends errors to the screen, because fd 1 hadn't been redirected yet when 2 was copied.

### Here-doc / here-string / process substitution
```bash
cat <<EOF > config.yml          # here-doc: multi-line input
host: $HOST
EOF
cat <<'EOF'                     # quoted 'EOF' → no variable expansion
$literal
EOF
grep foo <<< "$text"            # here-string: one string as stdin
diff <(sort a.txt) <(sort b.txt)  # process substitution: command output used as a file
```

---

## 5. Text Processing (the real power)

### grep
```bash
grep -rn "error" /var/log/app        # recursive, show line numbers
grep -i -v "debug" app.log           # case-insensitive, invert (exclude)
grep -E "timeout|refused" app.log    # -E: extended regex (|, +, ?, {n})
grep -o "user_id=[0-9]*" app.log     # print only the matching part
grep -c "500" access.log             # count matching lines
grep -l "TODO" -r src                # only filenames
grep -A 3 -B 2 "Exception" app.log   # 3 lines After, 2 Before (context)
grep -w "id" file                    # whole word only
```
- `rg` (ripgrep) is a much faster grep that respects `.gitignore`. Worth installing.

### cut / sort / uniq / wc / tr / head / tail
```bash
cut -d',' -f1,3 data.csv          # fields 1 & 3, comma delimiter
sort -t',' -k2 -n data.csv        # sort by column 2, numerically
sort -rh                          # reverse, human sizes (1K < 1M < 1G)
sort | uniq -c | sort -rn         # ★ frequency count, most common first
uniq -d                           # only duplicates (input must be sorted!)
wc -l file                        # line count
tr 'a-z' 'A-Z'                    # translate characters
tr -d '\r'                        # strip Windows line endings
head -n 20 / tail -n 50 file
tail -f app.log                   # follow live
tail -F app.log                   # follow even across log rotation
```

### sed (stream editor: find/replace, delete lines)
```bash
sed 's/foo/bar/' file          # first match per line
sed 's/foo/bar/g' file         # all matches
sed -i 's/foo/bar/g' file      # edit in place (macOS: sed -i '' ...)
sed -i.bak 's/a/b/g' file      # in place, keeping a backup
sed -n '10,20p' file           # print lines 10–20
sed '/^#/d' config             # delete comment lines
sed 's|/old/path|/new/path|g'  # any delimiter avoids escaping /
```

### awk (column-aware mini-language)
Structure: `awk 'pattern { action }'`. `$1, $2…` are fields, `$0` is the whole line, `NR` is the line number, `NF` is the field count.
```bash
awk '{print $1}' access.log                     # first column
awk -F',' '{print $2, $4}' data.csv              # custom delimiter
awk '$9 == 500' access.log                       # rows where column 9 is 500
awk '{sum += $5} END {print sum}' file           # sum a column
awk '{c[$1]++} END {for (k in c) print c[k], k}' access.log   # count per key
awk 'NR > 1' file.csv                            # skip header
awk 'length($0) > 200' file                      # long lines
```

### jq (JSON on the command line)
```bash
curl -s api/users | jq '.'                          # pretty print
jq '.items[] | {id, name}' data.json                # reshape
jq -r '.items[] | select(.status=="failed") | .id'  # filter; -r = raw strings
```

### ★ Classic log pipelines
```bash
# Top 10 client IPs in an nginx access log
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head

# Count of each HTTP status code
awk '{print $9}' access.log | sort | uniq -c

# Errors per minute
grep ERROR app.log | cut -c1-16 | uniq -c

# Which files take the most space here
du -sh * | sort -rh | head
```

---

## 6. Processes & Jobs

- **Process:** a running program with a **PID** (process ID). Each process has a parent (**PPID**).
```bash
ps aux                      # all processes
ps aux | grep [n]ginx       # [n] trick: hides the grep line itself
pgrep -fl gunicorn          # find PIDs by name
top / htop                  # live view (htop is friendlier)
pstree -p                   # parent/child tree
```

### Signals (messages sent to a process)
| Signal | # | Meaning |
|---|---|---|
| `SIGTERM` | 15 | "Please stop": the default for `kill`; the app can clean up |
| `SIGKILL` | 9 | Forced kill: can't be caught, no cleanup |
| `SIGINT` | 2 | Ctrl+C |
| `SIGHUP` | 1 | Terminal closed; by convention many daemons reload config on it |
| `SIGSTOP`/`SIGCONT` | 19/18 | Pause / resume |

```bash
kill PID          # SIGTERM
kill -9 PID       # last resort only
pkill -f "python worker.py"
kill -HUP $(pgrep nginx)   # reload config
```
- 🧠 Prod: always try SIGTERM and wait before SIGKILL. Kubernetes and Docker send SIGTERM, wait a grace period (30s by default), then SIGKILL. Apps should catch SIGTERM to finish in-flight requests (**graceful shutdown**).

### Jobs (background work in your shell)
```bash
long_task &        # run in background
jobs               # list background jobs
fg %1 / bg %1      # bring to foreground / resume in background
Ctrl+Z             # pause the foreground job
nohup cmd > out.log 2>&1 &   # survives logout (ignores SIGHUP)
disown %1          # detach an already-running job from the shell
```
- For anything long on a server, use **tmux** (section 13), not `nohup`.

### Exit codes & chaining
```bash
cmd1 && cmd2      # run cmd2 only if cmd1 succeeded
cmd1 || cmd2      # run cmd2 only if cmd1 failed
cmd1 ; cmd2       # run both regardless
echo $?           # exit code of the last command
```
- Common codes: 0 ok, 1 general error, 2 misuse, 126 not executable, 127 command not found, 128+N killed by signal N (137 = 128+9 = SIGKILL; in containers this usually means OOM-killed: the kernel killed it for using too much memory).

---

## 7. Environment & Shell Config

```bash
NAME=vijay            # shell variable (this shell only; no spaces around =)
export API_URL=...    # environment variable: inherited by child processes
env                   # list env vars
API_URL=x ./app       # set only for this one command
unset NAME
```
- **Startup files:** `~/.bashrc` runs for interactive shells (put aliases and functions here). `~/.bash_profile` / `~/.profile` run for login shells (usually just `source ~/.bashrc`). zsh uses `~/.zshrc`.
- `source file` (or `. file`) runs a file **in the current shell**, so its variables stay. `./file` runs in a child shell, and its variables disappear afterwards.
```bash
alias ll='ls -lah'
alias gs='git status'
export PATH="$HOME/.local/bin:$PATH"   # prepend, don't overwrite
```
- 🧠 Prod: secrets go in env vars or a secret manager, never in scripts or git. `.env` files are loaded with `set -a; source .env; set +a`.

---

## 8. Shell Scripting: Advanced

### Script skeleton
```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

main() {
  local input="${1:?usage: $0 <file>}"
  ...
}
main "$@"
```
- **Shebang** (`#!`) picks the interpreter. `/usr/bin/env bash` finds bash wherever it's installed.
- **Strict mode** (`set -euo pipefail`):
  - `-e`: exit on the first failing command.
  - `-u`: error on undefined variables (catches typos like `$DIR` vs `$DIRR`).
  - `-o pipefail`: a pipeline fails if **any** part fails (by default only the last command counts).
- 🧠 Without `-u`, `rm -rf "$BUILD_DIR/"` with a typo'd variable becomes `rm -rf /`. This has wiped real servers.
- Run `chmod +x script.sh`, then `./script.sh`.

### Quoting (the #1 source of bash bugs)
```bash
echo "$var"     # double quotes: variables expand, spaces preserved   ✅ default
echo '$var'     # single quotes: completely literal
echo $var       # unquoted: split on spaces + glob-expanded           ❌
for f in "$@"   # all args, each kept intact
```
- **Rule:** always quote variables: `"$file"`, `"${arr[@]}"`.

### Parameter expansion
```bash
${var:-default}    # default if unset/empty
${var:=default}    # also assign it
${var:?msg}        # error out if unset
${#var}            # length
${var#prefix}      # remove shortest prefix match  (## = longest)
${var%suffix}      # remove shortest suffix match  (%% = longest)
${var/old/new}     # replace first (// = all)
${var^^} ${var,,}  # upper / lower case
${var:0:5}         # substring

file="report.tar.gz"
echo "${file%%.*}"   # report
echo "${file#*.}"    # tar.gz
echo "${file##*.}"   # gz
```

### Tests & conditionals
```bash
if [[ -f "$f" && -r "$f" ]]; then ...; fi
[[ "$s" == prod* ]]          # glob match
[[ "$s" =~ ^v[0-9]+$ ]]      # regex match
(( count > 10 ))             # arithmetic comparison
```
- Prefer `[[ ]]` (bash) over `[ ]`: it's safer with empty vars and supports `&&`, `||`, `=~`.
- File tests: `-f` file, `-d` dir, `-e` exists, `-s` non-empty, `-x` executable, `-r` readable.
- String tests: `-z` empty, `-n` non-empty. Numbers: `-eq -ne -lt -gt` inside `[[ ]]`, or use `(( ))`.

```bash
case "$env" in
  prod|production) url=... ;;
  staging)         url=... ;;
  *) echo "unknown env" >&2; exit 1 ;;
esac
```

### Arithmetic
```bash
(( i++ ))
total=$(( a * b + 2 ))
echo "scale=2; 10/3" | bc     # bash is integers only; use bc for decimals
```

### Loops
```bash
for f in *.csv; do echo "$f"; done
for i in {1..10}; do ...; done
for ((i=0; i<5; i++)); do ...; done

# ★ The correct way to read a file line by line
while IFS= read -r line; do
  echo "$line"
done < input.txt

# Read command output without losing variables to a subshell
while read -r pid name; do ...; done < <(ps -eo pid,comm)
```
- `IFS=` keeps leading/trailing spaces, and `-r` keeps backslashes. Never use `for line in $(cat file)`: it splits on spaces, not lines.
- `cmd | while read ...` runs the loop in a **subshell** (a child copy of the shell), so variables set inside vanish afterwards. Use `< <(cmd)` instead.

### Arrays
```bash
arr=(a b "c d")
echo "${arr[0]}"  "${arr[@]}"  "${#arr[@]}"   # first, all, count
arr+=(e)
for x in "${arr[@]}"; do ...; done

declare -A ports=([web]=80 [db]=5432)         # associative array (a map, bash 4+)
echo "${ports[db]}"
for k in "${!ports[@]}"; do echo "$k=${ports[$k]}"; done
```

### Functions
```bash
log() { echo "[$(date +%T)] $*" >&2; }      # logs to stderr, keeps stdout clean
get_version() {
  local v
  v=$(git describe --tags) || return 1
  echo "$v"                                  # "return a value" = print it
}
version=$(get_version)
```
- `return N` only sets an exit code (0–255). To return data, `echo` it and capture with `$(...)`.
- Always declare `local` variables inside functions; otherwise they're global.

### Arguments
```bash
$0 script name, $1..$9 args, $# count, "$@" all args, $$ current PID, $! last background PID

while getopts "e:vh" opt; do          # -e takes a value, -v and -h are flags
  case $opt in
    e) env=$OPTARG ;;
    v) verbose=1 ;;
    h|*) usage; exit 1 ;;
  esac
done
shift $((OPTIND - 1))                 # remaining positional args
```

### trap (cleanup on exit or signal)
```bash
tmp=$(mktemp -d)                      # safe unique temp dir
trap 'rm -rf "$tmp"' EXIT             # runs however the script exits
trap 'echo "interrupted"; exit 130' INT TERM
```

### Debugging & linting
```bash
bash -x script.sh       # print each command before running it
set -x / set +x         # trace just one section
bash -n script.sh       # syntax check only
shellcheck script.sh    # ★ linter: catches quoting bugs and more; use it always
```
- 🧠 When bash isn't enough: past ~100–200 lines, or once you need real data structures, error handling or tests, senior engineers switch to Python. Bash is glue.

---

## 9. Networking

```bash
curl -s https://api.x.com/health                 # -s silent
curl -i URL                                      # include response headers
curl -X POST -H "Content-Type: application/json" -d '{"a":1}' URL
curl -o file.zip -L URL                          # -L follow redirects
curl -w "%{http_code} %{time_total}\n" -o /dev/null -s URL   # status + latency
wget -c URL                                      # resume a download

ping -c 4 host            # reachable? (ICMP may be blocked by firewalls)
dig +short example.com    # DNS lookup (nslookup is the older tool)
ss -tulpn                 # listening ports + owning process (replaces netstat)
nc -zv host 5432          # is a TCP port open? (netcat)
curl ifconfig.me          # your public IP
traceroute host           # network path, hop by hop
```

### SSH
```bash
ssh-keygen -t ed25519 -C "vijay@laptop"   # create a key pair
ssh-copy-id user@server                   # install your public key on the server
ssh user@server 'df -h'                   # run one remote command
ssh -L 5433:localhost:5432 user@bastion   # local port forward: localhost:5433 → remote DB
ssh -J user@bastion user@private-host     # jump through a bastion host
```
- A **bastion host** is the single hardened server exposed to the internet; private servers are reachable only through it.
- `~/.ssh/config` saves typing:
```
Host prod
  HostName 10.0.1.20
  User ubuntu
  IdentityFile ~/.ssh/prod_key
  ProxyJump bastion
```
Then just run `ssh prod`.

### Copying files
```bash
scp file user@host:/path/
rsync -avz --progress src/ user@host:/dst/    # only sends differences; resumable
rsync -avz --delete src/ dst/                 # mirror (⚠ deletes extras in dst)
```
- Trailing slash matters in rsync: `src/` copies the contents; `src` copies the folder itself.

---

## 10. System, Services & Logs

```bash
uname -a / cat /etc/os-release    # kernel / distro
uptime                            # load averages: 1, 5, 15 min
free -h                           # memory
nproc                             # CPU cores
df -h                             # disk space per filesystem
du -sh /var/log/*                 # size per item
lsblk                             # block devices (disks and partitions)
dmesg -T | tail                   # kernel messages (OOM kills, disk errors)
```
- **Load average:** the average number of processes running or waiting. Compare it with `nproc`: a load of 8 on 8 cores is fully busy; 16 on 8 cores means a queue is building.
- `free`: "available" is the number that matters. Linux uses spare RAM as disk cache, so a low "free" value is normal.

### systemd (the service manager on most distros)
```bash
systemctl status nginx
sudo systemctl start|stop|restart|reload nginx
sudo systemctl enable nginx         # start on boot
systemctl list-units --failed
journalctl -u nginx -f              # follow a service's logs
journalctl -u app --since "1 hour ago" -p err
```
- Minimal unit file `/etc/systemd/system/app.service`:
```ini
[Unit]
Description=My API
After=network.target

[Service]
User=app
WorkingDirectory=/opt/app/current
ExecStart=/opt/app/current/venv/bin/gunicorn app:app
Restart=on-failure
EnvironmentFile=/etc/app/env

[Install]
WantedBy=multi-user.target
```
Then `sudo systemctl daemon-reload && sudo systemctl enable --now app`.

### cron (scheduled jobs)
```bash
crontab -e          # edit your jobs
crontab -l          # list
```
```
# m  h  dom mon dow  command
  */5 *  *   *   *   /opt/scripts/health.sh >> /var/log/health.log 2>&1
  30  2  *   *   0   /opt/scripts/backup.sh          # Sundays 02:30
```
- cron runs with a **minimal environment**: use absolute paths, and always redirect output or you'll never see the errors.
- Use crontab.guru to check expressions.
- 🧠 Prod: overlapping runs are a classic bug. Wrap jobs with `flock -n /tmp/job.lock cmd` so only one copy runs at a time.

---

## 11. Disks & Archives

```bash
tar -czf backup.tar.gz dir/       # create (c), gzip (z), file (f)
tar -xzf backup.tar.gz -C /dst    # extract into /dst
tar -tzf backup.tar.gz            # list contents
gzip / gunzip file                # single file
zcat app.log.gz | grep ERROR      # read compressed logs directly (also zgrep)
```
- Mnemonic: **c**reate / e**x**tract / lis**t**, **z** = gzip, **f** = file.

### "Disk full" playbook
```bash
df -h                                   # which filesystem is full?
du -xh / --max-depth=1 | sort -rh | head   # biggest dirs (-x: stay on this disk)
lsof +L1                                # deleted files still held open
df -i                                   # out of inodes? (too many small files)
```
- Classic trap: you delete a huge log but space isn't freed, because a running process still holds the file open. Restart the process, or truncate instead of deleting: `> app.log` or `truncate -s 0 app.log`.

---

## 12. Packages

| Distro | Install | Update index | Search |
|---|---|---|---|
| Debian/Ubuntu | `sudo apt install pkg` | `sudo apt update` | `apt search` |
| RHEL/Fedora/Amazon Linux | `sudo dnf install pkg` (`yum` on older) | automatic | `dnf search` |
| Alpine (Docker images) | `apk add pkg` | `apk update` | `apk search` |
| macOS | `brew install pkg` | `brew update` | `brew search` |

- 🧠 In Dockerfiles: `apt-get update && apt-get install -y --no-install-recommends pkg && rm -rf /var/lib/apt/lists/*` in **one** `RUN` line keeps the image small.

---

## 13. Productivity

### History & editing
| Keys | Action |
|---|---|
| `Ctrl+R` | Search history (press again for older matches) |
| `Ctrl+A` / `Ctrl+E` | Start / end of line |
| `Ctrl+W` / `Ctrl+U` | Delete word / to start of line |
| `Ctrl+L` | Clear screen |
| `!!` | Repeat the last command (`sudo !!`) |
| `!$` / `Alt+.` | Last argument of the previous command |
| `cd -` | Back to the previous directory |

### Expansion shortcuts
```bash
mkdir -p proj/{src,tests,docs}     # brace expansion → 3 dirs
cp config.yml{,.bak}               # → cp config.yml config.yml.bak
echo {01..05}                      # 01 02 03 04 05
shopt -s globstar; ls **/*.py      # recursive glob
```

### tmux (keeps sessions alive after disconnects)
```bash
tmux new -s deploy      # new named session
Ctrl+B then D           # detach (it keeps running)
tmux ls                 # list sessions
tmux attach -t deploy   # reattach
Ctrl+B then %  /  "     # split pane vertical / horizontal
```
- 🧠 Always run long migrations or backups on a server inside tmux. If SSH drops, the job survives.

### Other useful tools
- `watch -n 2 'kubectl get pods'`: rerun a command every 2s.
- `time cmd`: how long a command took.
- `diff -u a b` or `colordiff`: compare files.
- `fzf`: fuzzy finder (supercharges `Ctrl+R`).
- `bat`, `fd`, `rg`, `htop`, `ncdu`: modern replacements for cat, find, grep, top and du.

---

## 14. Production Debugging Toolkit

| Question | Command |
|---|---|
| What's using port 8080? | `sudo ss -tulpn \| grep 8080` or `sudo lsof -i :8080` |
| Which files does PID 1234 have open? | `lsof -p 1234` |
| What is this process doing right now? | `strace -p 1234 -f` (system calls: the requests a program makes to the kernel) |
| Why is the box slow? | `top` → CPU/memory, `vmstat 1` → swapping/IO wait, `iostat -x 1` → disk |
| Did the kernel kill my app? | `dmesg -T \| grep -i oom` |
| Process environment / start command | `cat /proc/1234/environ \| tr '\0' '\n'`, `cat /proc/1234/cmdline` |
| Can I reach the DB? | `nc -zv db-host 5432`, then `dig db-host` |
| Errors in the last hour | `journalctl -u app --since "1h ago" -p err` |

- **IO wait** (`wa` in top/vmstat): CPU time spent waiting on disk. High values mean the disk is the bottleneck, not the CPU.
- **Swap:** disk used as overflow RAM. Heavy swapping makes everything slow.

---

## 15. Pitfalls Checklist

- [ ] Unquoted variables (`$file` instead of `"$file"`)
- [ ] No `set -euo pipefail` in scripts
- [ ] `for line in $(cat file)` instead of `while IFS= read -r`
- [ ] `cmd 2>&1 > file` (wrong order)
- [ ] `sudo cmd > /root/file` (the redirect isn't run as root; use `tee`)
- [ ] `kill -9` as the first resort
- [ ] Deleting an open log file and expecting the space back
- [ ] cron jobs with relative paths and no output redirect
- [ ] `rsync --delete` with the wrong trailing slash
- [ ] Editing a config with `sed -i` without a backup or test first
- [ ] Long jobs over SSH without tmux

---

## Practice Path
1. Take a real nginx/app log and answer: top IPs, status-code counts, slowest endpoints (awk/sort/uniq).
2. Write a backup script: strict mode, `getopts`, `trap` cleanup, `tar`, `rsync` to another dir, log to stderr. Pass `shellcheck` with zero warnings.
3. Run it as a systemd timer or cron job with `flock`.
4. On a VM: create a systemd service for a small app, break it on purpose, and debug it with `journalctl`, `ss`, `lsof`.
