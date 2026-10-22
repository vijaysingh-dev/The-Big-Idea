**Up:** [[00 - Index (Backend)]] | **Prev:** [[Docker]]

---

## 1. Vim Modes

Vim mainly has these modes:

``` text
NORMAL     → Navigate, delete, copy, paste, commands
INSERT     → Type/edit text
VISUAL     → Select text
COMMAND    → Execute commands such as save, quit, search
```

### Switching Modes

``` text
i       → Insert before cursor
a       → Insert after cursor
I       → Insert at beginning of line
A       → Insert at end of line
o       → Open a new line below
O       → Open a new line above

Esc     → Return to Normal mode
:       → Enter Command mode
v       → Visual mode
V       → Visual Line mode
Ctrl+v  → Visual Block mode
```

------------------------------------------------------------------------

## 2. Open / Create Files

``` bash
# Open a file
vim filename.txt

# Open multiple files
vim file1.txt file2.txt

# Open a file at a specific line
vim +25 filename.txt

# Open Vim without a file
vim
```

------------------------------------------------------------------------

## 3. Save / Quit

These commands are entered from Normal mode using `:`.

``` vim
:w              " Save
:q              " Quit
:wq             " Save and quit
:x              " Save and quit
:q!             " Quit without saving
:w!             " Force save
:wq!            " Force save and quit
```

Common shortcuts:

``` text
ZZ              → Save and quit
ZQ              → Quit without saving
```

------------------------------------------------------------------------

## 4. Basic Navigation

From Normal mode:

``` text
h       → Left
j       → Down
k       → Up
l       → Right
```

### Faster Navigation

``` text
w       → Next word
b       → Previous word
e       → End of word

0       → Beginning of line
^       → First non-whitespace character
$       → End of line

gg      → Beginning of file
G       → End of file

:n      → Go to line n
25G     → Go to line 25
```

Example:

``` text
25G     → Jump directly to line 25
```

------------------------------------------------------------------------

## 5. Scrolling

``` text
Ctrl+f  → Page down
Ctrl+b  → Page up

Ctrl+d  → Half-page down
Ctrl+u  → Half-page up

Ctrl+e  → Scroll down one line
Ctrl+y  → Scroll up one line

zz      → Center current line
zt      → Move current line to top
zb      → Move current line to bottom
```

------------------------------------------------------------------------

## 6. Insert / Edit Text

From Normal mode:

``` text
i       → Insert before cursor
a       → Insert after cursor

I       → Insert at beginning of line
A       → Insert at end of line

o       → New line below
O       → New line above
```

------------------------------------------------------------------------

## 7. Delete

``` text
x       → Delete character under cursor
X       → Delete character before cursor

dw      → Delete word
d$      → Delete to end of line
d0      → Delete to beginning of line

dd      → Delete entire line

D       → Delete from cursor to end of line
```

### Delete Multiple Lines

``` text
3dd     → Delete 3 lines
5dd     → Delete 5 lines
```

General pattern:

``` text
[number][command]
```

Example:

``` text
10dd    → Delete 10 lines
```

------------------------------------------------------------------------

## 8. Copy / Yank

Vim calls copying **yanking**.

``` text
yy      → Copy current line

yw      → Copy word
y$      → Copy to end of line
y0      → Copy to beginning of line
```

Multiple lines:

``` text
3yy     → Copy 3 lines
```

------------------------------------------------------------------------

## 9. Paste

``` text
p       → Paste after cursor
P       → Paste before cursor
```

Example:

``` text
dd      → Delete/cut current line
p       → Paste it below
P       → Paste it above
```

------------------------------------------------------------------------

## 10. Undo / Redo

``` text
u       → Undo

Ctrl+r  → Redo
```

Undo multiple changes:

``` text
3u      → Undo 3 changes
```

------------------------------------------------------------------------

## 11. Replace Characters

``` text
r       → Replace one character
R       → Enter replace mode
```

Example:

``` text
rx      → Replace current character with x
```

------------------------------------------------------------------------

## 12. Search

``` text
/pattern        → Search forward
?pattern        → Search backward

n               → Next match
N               → Previous match
```

Example:

``` vim
/error
```

This searches for `error`.

### Search Word Under Cursor

``` text
*       → Search next occurrence of current word
#       → Search previous occurrence of current word
```

------------------------------------------------------------------------

## 13. Find Characters on a Line

``` text
f<char>      → Find character forward
F<char>      → Find character backward

t<char>      → Move before character forward
T<char>      → Move before character backward

;            → Repeat last f/F/t/T
,            → Repeat in opposite direction
```

Example:

``` text
f,           → Find next comma
```

------------------------------------------------------------------------

## 14. Search and Replace

### Replace First Match on Current Line

``` vim
:s/old/new/
```

### Replace All Matches on Current Line

``` vim
:s/old/new/g
```

### Replace Throughout the File

``` vim
:%s/old/new/g
```

### Replace Throughout the File with Confirmation

``` vim
:%s/old/new/gc
```

The `c` asks for confirmation for each replacement.

------------------------------------------------------------------------

## 15. Visual Mode

### Character Selection

``` text
v
```

Move the cursor to select text.

Then:

``` text
d       → Delete selection
y       → Copy selection
c       → Change selection
```

### Line Selection

``` text
V
```

Select entire lines.

### Block Selection

``` text
Ctrl+v
```

Useful for editing columns of text.

------------------------------------------------------------------------

## 16. Indentation

``` text
>>      → Indent current line
<<      → Unindent current line
```

Multiple lines:

``` text
3>>     → Indent 3 lines
3<<     → Unindent 3 lines
```

In Visual mode:

``` text
>       → Indent selection
<       → Unindent selection
```

------------------------------------------------------------------------

## 17. Repeat Last Command

``` text
.
```

The `.` command repeats the last change.

Example:

``` text
dd      → Delete a line
.       → Delete another line
.       → Delete another line
```

This is one of Vim's most useful commands.

------------------------------------------------------------------------

## 18. Change Text

``` text
cw      → Change word
cc      → Change entire line
c$      → Change to end of line
c0      → Change to beginning of line
C       → Change to end of line
```

Example:

``` text
cw
```

Deletes the current word and enters Insert mode.

------------------------------------------------------------------------

## 19. Move by Paragraph / Section

``` text
{       → Previous paragraph
}       → Next paragraph
```

Useful when navigating large files.

------------------------------------------------------------------------

## 20. Matching Brackets

Place the cursor on:

``` text
( ) [ ] { }
```

Then:

``` text
%
```

Vim jumps to the matching bracket.

Very useful when working with code.

------------------------------------------------------------------------

## 21. Marks

Marks let you remember a location.

``` text
ma      → Create mark "a"
'a      → Jump to mark "a"
```

Example:

``` text
ma
```

Move somewhere else, then:

``` text
'a
```

to return to that line.

------------------------------------------------------------------------

## 22. Multiple Windows

### Split Horizontally

``` vim
:split
```

or:

``` vim
:sp
```

### Split Vertically

``` vim
:vsplit
```

or:

``` vim
:vsp
```

### Move Between Windows

``` text
Ctrl+w h     → Move left
Ctrl+w j     → Move down
Ctrl+w k     → Move up
Ctrl+w l     → Move right
```

### Close Current Window

``` vim
:q
```

------------------------------------------------------------------------

## 23. Multiple Tabs

``` vim
:tabnew
```

Create a new tab.

``` vim
:tabnew filename.txt
```

Open a file in a new tab.

Navigate:

``` text
gt          → Next tab
gT          → Previous tab
```

Or:

``` vim
:tabnext
:tabprevious
```

------------------------------------------------------------------------

## 24. Buffers

A buffer is Vim's in-memory representation of a file.

``` vim
:buffers
```

List buffers.

``` vim
:bnext
```

Next buffer.

``` vim
:bprevious
```

Previous buffer.

``` vim
:buffer 2
```

Switch to buffer 2.

------------------------------------------------------------------------

## 25. File Explorer

Vim has a built-in file explorer called **netrw**.

``` vim
:Explore
```

or:

``` vim
:E
```

Useful commands inside netrw:

``` text
Enter       → Open file/directory
-           → Go up one directory
d           → Create directory
%           → Create file
D           → Delete
R           → Rename
```

------------------------------------------------------------------------

## 26. Run Shell Commands

From Vim:

``` vim
:!ls
```

Run `ls`.

``` vim
:!pwd
```

Show current directory.

``` vim
:!python script.py
```

Run a Python script.

You can also open a shell:

``` vim
:terminal
```

------------------------------------------------------------------------

## 27. Current Working Directory

``` vim
:pwd
```

Show current directory.

``` vim
:cd /path/to/project
```

Change directory.

``` vim
:cd ..
```

Move to parent directory.

------------------------------------------------------------------------

## 28. Useful File Commands

``` vim
:e filename
```

Open/edit another file.

``` vim
:w filename
```

Save current buffer as another filename.

``` vim
:saveas filename
```

Save as another file.

``` vim
:r filename
```

Insert contents of another file at the cursor.

------------------------------------------------------------------------

## 29. Line Numbers

### Show Line Numbers

``` vim
:set number
```

or:

``` vim
:set nu
```

### Hide Line Numbers

``` vim
:set nonumber
```

or:

``` vim
:set nonu
```

### Relative Line Numbers

``` vim
:set relativenumber
```

Useful for commands such as:

``` text
5j      → Move down 5 lines
5dd     → Delete 5 lines
```

------------------------------------------------------------------------

## 30. Useful Settings

``` vim
:set number
:set relativenumber
:set ignorecase
:set smartcase
:set expandtab
:set tabstop=4
:set shiftwidth=4
```

For example:

``` vim
:set tabstop=4
```

sets a tab width of 4 spaces.

------------------------------------------------------------------------

## 31. Command History

``` text
:       → Enter Command mode

↑       → Previous command
↓       → Next command
```

You can also view command history:

``` vim
:history
```

------------------------------------------------------------------------

## 32. Common Vim Workflow

### Open a file

``` bash
vim app.py
```

### Navigate

``` text
gg          → Beginning of file
/keyword    → Search
n           → Next match
```

### Edit

``` text
i           → Insert
Esc         → Normal mode
```

### Save

``` vim
:w
```

### Exit

``` vim
:q
```

Or simply:

``` vim
:wq
```

------------------------------------------------------------------------

# Most Important Commands to Memorize

If you're starting with Vim, focus on these first:

``` text
MODE
Esc             → Normal mode
i               → Insert
v               → Visual
:               → Command mode

NAVIGATION
h j k l         → Left / Down / Up / Right
w / b           → Next / previous word
0 / $           → Start / end of line
gg / G          → Start / end of file

EDITING
x               → Delete character
dd              → Delete line
yy              → Copy line
p               → Paste
u               → Undo
Ctrl+r          → Redo
.               → Repeat last change

SEARCH
/pattern        → Search
n               → Next match
N               → Previous match
*               → Search word under cursor

SAVE / EXIT
:w              → Save
:q              → Quit
:wq             → Save + quit
:q!             → Quit without saving
```

# Vim Mental Model

A useful way to think about Vim is:

``` text
              ┌──────────────┐
              │    NORMAL    │
              │   Navigate   │
              │   Commands   │
              └──────┬───────┘
                     │
            i / a / o│
                     ↓
              ┌──────────────┐
              │    INSERT    │
              │  Type text   │
              └──────┬───────┘
                     │
                   Esc
                     │
                     ↓
                  NORMAL
```

Most of your time should eventually be spent in **Normal mode**, using
commands to manipulate text rather than constantly reaching for the
mouse.

# Quick Cheat Sheet

``` text
                    NAVIGATION
h j k l             ← ↓ ↑ →
w / b               Next / previous word
0 / $               Start / end of line
gg / G              Start / end of file
25G                 Go to line 25

                    INSERT
i                   Insert
a                   Append
o / O               New line below / above
Esc                 Normal mode

                    DELETE
x                   Character
dw                  Word
dd                  Line
D                   To end of line

                    COPY / PASTE
yy                  Copy line
p / P               Paste after / before

                    CHANGE
cw                  Change word
cc                  Change line
C                   Change to end of line

                    UNDO / REDO
u                   Undo
Ctrl+r              Redo
.                   Repeat

                    SEARCH
/pattern            Search forward
?pattern            Search backward
n / N               Next / previous
*                   Search current word

                    SAVE / EXIT
:w                  Save
:q                  Quit
:wq                 Save + quit
:q!                 Quit without saving

                    WINDOWS
:split              Horizontal split
:vsplit             Vertical split
Ctrl+w + h/j/k/l    Navigate windows

                    TABS
:tabnew             New tab
gt                  Next tab
gT                  Previous tab

                    SHELL
:!command           Run shell command
:terminal           Open terminal
```
