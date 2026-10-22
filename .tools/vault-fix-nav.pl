#!/usr/bin/perl
# Fix Up/Prev/Next navigation lines across a numbered note vault.
#
# Expects this structure under ROOT:
#   ROOT/00 - Index*.md                  (or any single "*Index*.md" file directly in ROOT)
#   ROOT/<NN> - <Section Name>/<NN.N> - <Note Title>.md
#
# Two extra shapes are also supported, auto-detected per section:
#   - A section folder's notes may live one level deeper, in numbered/named
#     subfolders (e.g. "02 - Design-Patterns/01 - Creational/02.1 - X.md").
#     All numbered notes anywhere under a section are merged into one
#     numeric-ordered sequence regardless of which subfolder holds them.
#   - A trailing, non-numbered folder (e.g. "Assets") is picked up as a final
#     section. If its files don't carry a "<token>.<N> - <Title>" number, they
#     are ordered by their first-linked appearance in the Index file instead
#     (falling back to alphabetical for anything the Index doesn't mention).
#
# Nav-line style is auto-detected from the first note in the vault and applied
# consistently, so each vault's existing convention is preserved:
#   - "**Up**: ... **Prev**: ..."      (bold)
#   - "Up: ... | Prev: ..."            (plain)
#   - "> [[Index|<Alias>]] | Prev: ..." (blockquote, index linked via wikilink)
#   - "**Up:** [[Index]] | **Prev:** [[..]]" then "---" then the (unnumbered)
#     H1, then "---" then "**Next:** [[..]]" at the end            (jsreact)
#
# The "jsreact" style is the shared convention from the "JavaScript and React"
# vault. It differs structurally from the others: the top nav line sits ABOVE
# the H1 (with a "---" rule between them), the H1 has its "<NN.N> - " number
# stripped, and any content the note carried between its old H1 and its first
# "---" (e.g. "#tags" lines, a "> **In one line:**" blockquote) is preserved
# immediately after the new H1. Force it with the 2nd arg to bring every vault
# in line with the JS & React epubs. Notes whose nav currently sits only at the
# bottom (e.g. "_Prev: .. · Next: ..._") are handled: it is moved to the top.
#
# Links are bare "[[Name]]" (Obsidian resolves by unique filename), UNLESS the
# vault is flat (no section has nested subfolders) AND the detected style is
# not blockquote -- in that case the original "../Folder/Name" cross-section
# prefix behavior is preserved for full backward compatibility with vaults
# already processed by an earlier version of this script.
#
# For every note (in numeric NN.N order across all sections), rewrites:
#   - the H1 heading number to match its filename (fixes stale renumbering,
#     only when the heading already embeds a number -- a no-op otherwise)
#   - the top nav line right after the heading (drops any extra "Section N/M"
#     style labels -- only Up/Prev survive)
#   - a "**Section**: ..." stale line, if present, is removed
#   - a trailing block at the end of the file (Next/Prev/Related/Navigate, in
#     any style) is replaced with a single trailing Next line
#
# Idempotent: safe to re-run after the vault has already been fixed, or
# after inserting/removing/renaming notes (just re-run to recompute links).
#
# Usage: perl vault-fix-nav.pl "<ROOT FOLDER>" [bold|plain|quote|jsreact]
#
# The optional second argument forces a nav style instead of auto-detecting
# it from the vault's first note -- use this to bring a vault that currently
# uses one style (e.g. "quote") in line with the convention used elsewhere
# (e.g. "bold", to match another vault's epub).

use strict;
use warnings;
use utf8;
binmode(STDOUT, ":utf8");

my $root = $ARGV[0] or die "usage: perl vault-fix-nav.pl <ROOT FOLDER> [bold|plain|quote]\n";
$root =~ s{[/\\]+\z}{};
my $forced_style = $ARGV[1];
if (defined $forced_style && $forced_style !~ /^(?:bold|plain|quote|jsreact)$/) {
    die "unknown style '$forced_style' -- expected bold, plain, quote, or jsreact\n";
}

# --- Find the index file directly under ROOT ---
opendir(my $rdh, $root) or die "cannot open $root: $!";
my @root_files = readdir($rdh);
closedir($rdh);
my ($index_file) = grep { /index/i && /\.md$/ } @root_files;
die "no *Index*.md file found directly under $root\n" unless $index_file;
(my $index_name = $index_file) =~ s/\.md$//;

my $index_content = do {
    open(my $fh, "<:encoding(UTF-8)", "$root/$index_file") or die;
    local $/;
    <$fh>;
};

# --- Discover section directories: "<digits> - <name>" ---
my @section_dirs = sort {
    my ($an) = ($a =~ /^(\d+)/); my ($bn) = ($b =~ /^(\d+)/);
    $an <=> $bn
} grep { -d "$root/$_" && /^\d+\s*-\s*.+/ } @root_files;

die "no numbered section folders found under $root\n" unless @section_dirs;

# --- Discover trailing non-numbered section folders (e.g. "Assets") ---
my @extra_dirs;
for my $d (@root_files) {
    next unless -d "$root/$d";
    next if $d =~ /^\d+\s*-\s*.+/;
    next if $d =~ /^\./;
    opendir(my $tdh, "$root/$d") or next;
    my @f = readdir($tdh);
    closedir($tdh);
    push @extra_dirs, $d if grep { /\.md$/i } @f;
}
push @section_dirs, sort @extra_dirs;

# --- Recursively collect every numbered note anywhere under a section dir ---
sub numbered_notes_under {
    my ($rel) = @_; # path relative to root
    my @found;
    opendir(my $dh, "$root/$rel") or return @found;
    my @entries = grep { !/^\./ } readdir($dh);
    closedir($dh);
    for my $e (sort @entries) {
        my $full = "$rel/$e";
        if (-d "$root/$full") {
            push @found, numbered_notes_under($full);
        } elsif ($e =~ /^\S+\.(\d+)\s*-\s*.+\.md$/) {
            my $key = $1;
            (my $name = $e) =~ s/\.md$//;
            push @found, { folder => $rel, name => $name, key => $key };
        }
    }
    return @found;
}

my $has_nesting = 0; # any section whose notes live in a sub-subfolder?

# --- Discover notes within each section, numeric order across subfolders ---
my @order; # [folder, name-without-ext]
for my $sec (@section_dirs) {
    my @numbered = numbered_notes_under($sec);
    if (@numbered) {
        @numbered = sort { $a->{key} <=> $b->{key} } @numbered;
        for my $n (@numbered) {
            push @order, [$n->{folder}, $n->{name}];
            $has_nesting = 1 if $n->{folder} ne $sec;
        }
    } else {
        # No numbered notes anywhere in this section -- plain filenames.
        # Order by first appearance in the Index file, then alphabetically.
        opendir(my $dh, "$root/$sec") or next;
        my @files = grep { /\.md$/i } readdir($dh);
        closedir($dh);
        my @names = map { (my $n = $_) =~ s/\.md$//; $n } @files;
        my %pos;
        for my $n (@names) {
            my $idx = index($index_content, "[[$n");
            $pos{$n} = $idx >= 0 ? $idx : 1_000_000_000;
        }
        my @sorted = sort { $pos{$a} <=> $pos{$b} or $a cmp $b } @names;
        push @order, [$sec, $_] for @sorted;
    }
}

print "Discovered ", scalar(@order), " notes across ", scalar(@section_dirs), " sections.\n";

# --- Detect this vault's existing nav style from its first note (unless forced) ---
my $style; # 'bold' | 'plain' | 'quote'
if (defined $forced_style) {
    $style = $forced_style;
} else {
    my ($ffolder, $fname) = @{$order[0]};
    open(my $fh, "<:encoding(UTF-8)", "$root/$ffolder/$fname.md") or die;
    local $/;
    my $c = <$fh>;
    close($fh);
    if    ($c =~ /^\*\*Up:\*\*/m)   { $style = 'jsreact'; }
    elsif ($c =~ /^\*\*Up\*\*:/m)   { $style = 'bold'; }
    elsif ($c =~ /^>\s*\[\[/m)      { $style = 'quote'; }
    else                             { $style = 'plain'; }
}

# Bare links unless the vault is flat and using the old bold/plain styles --
# preserves exact prior behavior for vaults already processed. The jsreact
# style always uses bare links (matching the JS & React vault).
my $bare_links = $has_nesting || $style eq 'quote' || $style eq 'jsreact';

sub link_to {
    my ($cur_folder, $target_idx) = @_;
    return undef if $target_idx < 0 || $target_idx >= scalar(@order);
    my ($tfolder, $tname) = @{$order[$target_idx]};
    return "[[$tname]]" if $bare_links || $tfolder eq $cur_folder;
    return "[[../$tfolder/$tname]]";
}

sub build_up_line {
    my ($prev_link) = @_;
    if ($style eq 'jsreact') {
        my $l = "**Up:** [[$index_name]]";
        $l .= " | **Prev:** $prev_link" if defined $prev_link;
        return $l;
    } elsif ($style eq 'bold') {
        my $l = "**Up**: [[$index_name|Index]]";
        $l .= " **Prev**: $prev_link" if defined $prev_link;
        return $l;
    } elsif ($style eq 'quote') {
        my $l = "> [[$index_name|← Index]]";
        $l .= " | Prev: $prev_link" if defined $prev_link;
        return $l;
    } else {
        my $l = "Up: [[$index_name]]";
        $l .= " | Prev: $prev_link" if defined $prev_link;
        return $l;
    }
}

# Match a top nav line in any style this script knows how to emit or has seen:
#   **Up:** ...   |   **Up**: ...   |   Up: ...   |   > [[ ...
my $TOP_NAV_RE = qr/^(?:\*\*Up:?\*\*.*|\*\*Up\*\*:.*|Up:.*|>\s*\[\[.*)$/m;

# Match a trailing nav block (its own paragraph, optionally preceded by a "---"
# rule) in any style: **Next**:/**Prev**: , Next:/Prev: , _Prev: .. Next: .._ ,
# _Next: .._ , "_Prev: X · Next: Y_".
my $BOTTOM_NAV_RE = qr/\n+(?:---\n+)?(?:\*\*(?:Next|Prev):?\*\*[^\n]*|(?:Next|Prev):[^\n]*|_[^\n]*(?:Next|Prev|Related|Navigate)[^\n]*_)\s*\z/;

for my $i (0 .. $#order) {
    my ($folder, $name) = @{$order[$i]};
    my $path = "$root/$folder/$name.md";

    open(my $fh, "<:encoding(UTF-8)", $path) or die "cannot open $path: $!";
    local $/;
    my $content = <$fh>;
    close($fh);

    my $prev_link = link_to($folder, $i - 1);
    my $next_link = link_to($folder, $i + 1);
    my $up_line   = build_up_line($prev_link);

    if ($style eq 'jsreact') {
        # --- jsreact: nav ABOVE an unnumbered H1, "---" rules around it ---

        # Remove the existing top nav line wherever it currently sits.
        $content =~ s/$TOP_NAV_RE\n?//;
        # Remove stale "**Section**: ..." line if present
        $content =~ s/\n\*\*Section\*\*:[^\n]*\n/\n/;
        # Strip any existing trailing nav block...
        $content =~ s/$BOTTOM_NAV_RE//;
        # ...and a stray trailing "**Up:** ..."/"Up: ..." line some notes carry
        # in addition to their real top nav (a hand-editing artifact).
        $content =~ s/\n+(?:\*\*Up:?\*\*|Up:)[^\n]*\s*\z//;
        # ...then any bare "---" rule left dangling at the very end.
        $content =~ s/\n+-{3,}[ \t]*\s*\z//;
        $content =~ s/\s*\z/\n/;

        # Find the real H1: the FIRST markdown heading in the file (ignoring
        # fenced code blocks) -- and only accept it if it is a level-1 "# ".
        # This guards against notes that have no title of their own: a shell
        # "# comment" inside a code block (Backend's "Quick Reference" snippets),
        # or a doc that is all "## " sections. Those take the safe prepend path.
        my $h1_pos;      # byte offset of the H1 line
        {
            my $in_code = 0;
            my $off = 0;
            for my $line (split /(?<=\n)/, $content) {
                if ($line =~ /^\s*(?:```|~~~)/) {
                    $in_code = !$in_code;
                } elsif (!$in_code && $line =~ /^(\#{1,6})[ \t]/) {
                    $h1_pos = $off if length($1) == 1;  # first heading is an H1
                    last;                                # first heading, period
                }
                $off += length($line);
            }
        }

        if (!defined $h1_pos) {
            # No H1 at all -- don't restructure. Just guarantee the top nav
            # sits first (with a rule), keep the body verbatim, add Next.
            # Drop any leading blank lines and a leading "---" rule left behind
            # by a previous run's top block, so re-runs stay idempotent.
            $content =~ s/\A(?:[ \t]*\n)+//;
            $content =~ s/\A-{3,}[ \t]*\n(?:[ \t]*\n)*//;
            $content = "$up_line\n\n---\n\n" . $content;
            $content =~ s/\s*\z/\n/;
            $content .= "\n---\n\n**Next:** $next_link\n" if defined $next_link;
        } else {
            # Body = the H1 line and everything after it. Everything before it is
            # only ever stale nav lines, "---" rules and blank lines -- drop it.
            my $body = substr($content, $h1_pos);

            # Strip the H1's "<NN.N> - " / "<NN> - " number, keeping the title.
            $body =~ s/\A(\#[ \t]+)\S+?\.\d+\s*[—:\-]\s*(.+)$/$1$2/m
                or $body =~ s/\A(\#[ \t]+)\d+\s*[—:\-]\s*(.+)$/$1$2/m;

            ($body =~ /\A(\#[ \t]+.+)$/m) or die "no H1 line in $path\n";
            my $h1_line = $1;

            # If the first non-blank line after the H1 is a "---" rule, it
            # belonged to the old below-H1 nav (e.g. the AI vault) -- drop it. A
            # "---" that follows real content (Backend's "#tags" + "> **In one
            # line:**" block, HLD's "> **Revision tags:**" line) is the note's
            # own opening rule and is kept.
            $body =~ s/\A(\Q$h1_line\E\n)(?:[ \t]*\n)+-{3,}[ \t]*\n/$1/;

            # Normalize the gap right after the H1 to exactly one blank line.
            $body =~ s/\A(\Q$h1_line\E\n)(?:[ \t]*\n)+/$1\n/;

            # Reassemble: top nav, rule, then the body (H1 first).
            $content = "$up_line\n\n---\n\n" . $body;
            $content =~ s/\s*\z/\n/;

            # Append the trailing Next block.
            $content .= "\n---\n\n**Next:** $next_link\n" if defined $next_link;
        }
    } else {
        # --- bold / plain / quote: nav line in place, right after the H1 ---

        # Fix H1 heading number to match filename number (no-op if the heading
        # doesn't embed a number to begin with -- some vaults never number H1s)
        my ($correct_num) = ($name =~ /^(\d+\.\d+)/);
        if (defined $correct_num) {
            $content =~ s/^# \d+\.\d+(\s*[—:-]\s*)/# $correct_num$1/m;
        }

        # Remove stale "**Section**: ..." line if present
        $content =~ s/\n\*\*Section\*\*:[^\n]*\n/\n/;

        my $replaced = ($content =~ s/$TOP_NAV_RE/$up_line/);
        die "no Up: line found in $path -- is this file already in the expected shape?\n"
            unless $replaced;

        # Strip any existing trailing nav block (Next/Prev/Related/Navigate, any style)
        $content =~ s/$BOTTOM_NAV_RE//;
        $content =~ s/\s*\z/\n/;

        # Append fresh bottom Next block, matching the detected style
        if (defined $next_link) {
            $content .= $style eq 'plain'
                ? "---\n\nNext: $next_link\n"
                : "---\n**Next**: $next_link\n";
        }
    }

    open(my $out, ">:encoding(UTF-8)", $path) or die "cannot write $path: $!";
    print $out $content;
    close($out);
}

print "Done. Nav links fixed for all notes under $root (style=$style, bare_links=" . ($bare_links ? 1 : 0) . ")\n";
