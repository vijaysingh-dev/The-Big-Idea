#!/usr/bin/perl
# Build a single EPUB from a numbered note vault (same structure as vault-fix-nav.pl expects,
# including its two extra shapes: notes nested one level deeper in subfolders, and a trailing
# non-numbered folder like "Assets" whose notes may lack a "<token>.<N> - <Title>" number).
#
# Usage: perl vault-to-epub.pl "<ROOT FOLDER>" "<Book Title>"
#
# Produces "<ROOT FOLDER>/<Book Title>.md" (intermediate) and
#          "<ROOT FOLDER>/<Book Title>.epub" (final, via pandoc).
#
# Requires pandoc on PATH (or edit $PANDOC below).

use strict;
use warnings;
use utf8;
binmode(STDOUT, ":utf8");

# usage: perl vault-to-epub.pl <ROOT FOLDER> <Book Title> [OUTPUT BASENAME] [COVER IMAGE]
#   ROOT FOLDER     numbered-note vault to build from
#   Book Title      dc:title metadata + book heading
#   OUTPUT BASENAME optional; file stem for the .md/.epub (defaults to Book Title).
#                   e.g. "High Level Design - Guide" -> "<ROOT>/High Level Design - Guide.epub"
#   COVER IMAGE     optional path to a cover PNG/JPG (passed to --epub-cover-image)
my $root  = $ARGV[0] or die "usage: perl vault-to-epub.pl <ROOT FOLDER> <Book Title> [OUTPUT BASENAME] [COVER IMAGE]\n";
my $title = $ARGV[1] or die "usage: perl vault-to-epub.pl <ROOT FOLDER> <Book Title> [OUTPUT BASENAME] [COVER IMAGE]\n";
$root =~ s{[/\\]+\z}{};
my $basename = (defined $ARGV[2] && length $ARGV[2]) ? $ARGV[2] : $title;
my $cover    = $ARGV[3];
die "cover image not found: $cover\n" if defined($cover) && length($cover) && !-f $cover;

my $PANDOC = "pandoc"; # assumes pandoc is on PATH; set full path if not

use File::Basename qw(dirname);
my $css = dirname(__FILE__) . "/vault-epub-style.css";

my $md_out   = "$root/$basename.md";
my $epub_out = "$root/$basename.epub";

# --- Discover index file, section dirs, and notes (same logic as vault-fix-nav.pl) ---
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

my @section_dirs = sort {
    my ($an) = ($a =~ /^(\d+)/); my ($bn) = ($b =~ /^(\d+)/);
    $an <=> $bn
} grep { -d "$root/$_" && /^\d+\s*-\s*.+/ } @root_files;
die "no numbered section folders found under $root\n" unless @section_dirs;

# Trailing non-numbered section folders (e.g. "Assets"), appended after the
# numbered ones in name order -- only if they actually hold markdown notes.
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
    my ($rel) = @_;
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

my %section_title; # "01" -> "Fundamentals" (or "Assets" -> "" for unnumbered)
my @order;          # [folder, name-without-ext]
my $has_nesting = 0;
for my $sec (@section_dirs) {
    my ($secnum, $sectitle) = ($sec =~ /^(\d+)\s*-\s*(.+)$/);
    if (defined $secnum) {
        $section_title{$secnum} = $sectitle;
    } else {
        $secnum = $sec;
        $section_title{$secnum} = '';
    }

    my @numbered = numbered_notes_under($sec);
    if (@numbered) {
        @numbered = sort { $a->{key} <=> $b->{key} } @numbered;
        for my $n (@numbered) {
            push @order, [$n->{folder}, $n->{name}];
            $has_nesting = 1 if $n->{folder} ne $sec;
        }
    } else {
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

# --- Anchor id + display-title maps ---
# heading_of carries the note's number (from its filename) for numbered notes,
# even when the note's own H1 text omits it -- so the in-book chapter heading
# (and the TOC entry pandoc derives from it) tells the reader where they are,
# instead of e.g. showing bare "LLD vs HLD" for "01.2 - LLD vs HLD.md". Notes
# with no number in their filename (e.g. a trailing "Assets" folder) are left
# undef here, so the note's own H1 text is kept verbatim.
my %anchor_of; my %title_of; my %heading_of;
for my $entry (@order) {
    my (undef, $name) = @$entry;
    my ($num) = ($name =~ /^(\S+\.\d+)/);
    if (defined $num) {
        (my $id = "sec" . lc($num)) =~ s/[^a-z0-9]+/-/g;
        $anchor_of{$name} = $id;
        (my $t = $name) =~ s/^\S+\.\d+\s*-\s*//;
        $title_of{$name} = $t;
        $heading_of{$name} = "$num \x{2014} $t";
    } else {
        (my $id = "sec-" . lc($name)) =~ s/[^a-z0-9]+/-/g;
        $anchor_of{$name} = $id;
        $title_of{$name} = $name;
    }
}
$anchor_of{$index_name} = "top-index";

sub resolve_wikilink {
    my ($target, $alias) = @_;
    $target =~ s{^(?:\.\./)*(?:[^/]+/)*}{}; # strip any folder prefix (relative or direct subfolder), any depth
    $target =~ s/^\s+|\s+$//g;
    my $id = $anchor_of{$target};
    my $display = (defined($alias) && length($alias)) ? $alias
                 : (defined($title_of{$target}) ? $title_of{$target} : $target);
    return defined($id) ? "[$display](#$id)" : $display;
}

sub convert_wikilinks {
    my ($text) = @_;
    $text =~ s{\[\[([^\]\|]+)\|([^\]]+)\]\]}{resolve_wikilink($1,$2)}ge;
    $text =~ s{\[\[([^\]\|]+)\]\]}{resolve_wikilink($1,undef)}ge;
    return $text;
}

# Neutralise inline markdown links whose target is an app-scheme URI the epub
# reader can't follow -- chiefly "obsidian://" deep links copied from the vault,
# which epubcheck rejects outright as an invalid URI. The link text is kept as
# plain text; genuine http(s)/mailto and in-book "#anchor" links are untouched.
sub strip_app_links {
    my ($text) = @_;
    $text =~ s{\[([^\]]+)\]\((?!https?:|mailto:|#)[a-z][a-z0-9+.-]*://[^)]*\)}{$1}gi;
    return $text;
}

# Shift every markdown ATX heading (# .. ######) in $text down by $delta levels,
# skipping lines inside fenced code blocks (so e.g. Python "# comment" lines are
# left untouched). Capped at H6 since HTML/epub has no deeper heading level.
sub shift_headings {
    my ($text, $delta) = @_;
    my @lines = split /\n/, $text, -1;
    my $in_code = 0;
    for my $line (@lines) {
        if ($line =~ /^\s*```/) {
            $in_code = !$in_code;
            next;
        }
        next if $in_code;
        if ($line =~ /^(#{1,6})(\s+\S.*)$/) {
            my $level = length($1) + $delta;
            $level = 6 if $level > 6;
            $level = 1 if $level < 1;
            $line = ('#' x $level) . $2;
        }
    }
    return join("\n", @lines);
}

# Strip standalone "---" horizontal-rule separator lines the vault format
# uses between sections -- redundant now that headings carry their own
# spacing/page breaks, and rendered as stray divider lines in the epub.
sub strip_hr {
    my ($text) = @_;
    $text =~ s/^-{3,}[ \t]*\n//mg;
    $text =~ s/\n{3,}/\n\n/g;
    return $text;
}

# Trim the index/title page down to just its genuinely readable prose, dropping
# the scaffolding blocks that only make sense inside the live vault. Three kinds
# of top-level ("## ") block go:
#   1. Any block containing a note-link table row ("| ... [[Note]] ..."): the
#      hand-maintained "Navigation" tables. Redundant once headings are leveled
#      correctly -- the epub's native --toc already shows Section > File > Heading.
#   2. Any block that is mostly a markdown table (>= half its non-blank body
#      lines start with "|"): "Suggested Pace", "What This Vault Assumes ...",
#      cross-vault maps -- reference tables that don't belong in a linear read.
#   3. Any block whose heading is vault-workflow meta rather than subject matter:
#      "How to Use ...", "The Method", "Learning Path", "Revision Strategy",
#      "Start here", etc. (see $META_HEADING).
# Conceptual blocks -- "Key Mental Models", "The one-paragraph map of the whole
# field" and the like -- are subject matter and are kept.
my $META_HEADING = qr/^\#\#\s+(?:
      how\s+to\s+use
    | the\s+method\b
    | learning\s+path
    | suggested\s+pace
    | revision\s+strategy
    | start\s+here
    | what\s+this\s+vault\s+assumes
    | assets?\b
)/ix;

sub strip_nav_tables {
    my ($text) = @_;
    my @parts = split /(?=^## )/m, $text;
    my $prefix = (@parts && $parts[0] !~ /^## /) ? shift(@parts) : '';
    my @kept;
    for my $p (@parts) {
        next if $p =~ /^\|.*\[\[/m;             # (1) navigation table
        next if $p =~ $META_HEADING;            # (3) workflow-meta heading
        my @body = grep { /\S/ } split /\n/, $p;
        shift @body;                            # drop the heading line itself
        if (@body) {
            my $table = grep { /^\s*\|/ } @body;
            next if $table * 2 >= @body;        # (2) mostly a table
        }
        push @kept, $p;
    }
    return $prefix . join('', @kept);
}

open(my $out, ">:encoding(UTF-8)", $md_out) or die "cannot write $md_out: $!";

# Title/overview page from the index file (metadata passed via pandoc CLI flags,
# not an embedded YAML block -- see the "---" normalization pass below for why).
{
    open(my $fh, "<:encoding(UTF-8)", "$root/$index_file") or die;
    local $/; my $content = <$fh>; close($fh);
    $content = strip_nav_tables($content);
    $content = convert_wikilinks($content);
    $content = strip_app_links($content);
    $content = strip_hr($content);
    # Tag the index H1 with the {#top-index} id so notes that link back to the
    # index ([[00 - Index ...]]) resolve instead of pointing at a missing anchor.
    $content =~ s/\A(?:\s*\n)*#[ \t]+(.+?)[ \t]*\n/# $1 {#top-index}\n/;
    print $out $content, "\n\n";
}

my $last_secnum = "";
for my $entry (@order) {
    my ($folder, $name) = @$entry;
    my ($topdir) = ($folder =~ m{^([^/]+)});
    my ($secnum) = ($topdir =~ /^(\d+)/);
    $secnum = $topdir unless defined $secnum;

    if ($secnum ne $last_secnum) {
        (my $anchor_id = lc($secnum)) =~ s/[^a-z0-9]+/-/g;
        my $heading = length($section_title{$secnum})
            ? "$secnum \x{2014} $section_title{$secnum}"
            : "$secnum";
        print $out "# $heading {#sec$anchor_id}\n\n";
        $last_secnum = $secnum;
    }

    open(my $fh, "<:encoding(UTF-8)", "$root/$folder/$name.md") or die "cannot open $folder/$name: $!";
    local $/; my $content = <$fh>; close($fh);

    my $id = $anchor_of{$name};

    # Strip the top nav line FIRST. In most vault styles it sits just after the
    # H1; in the "jsreact" style it sits ABOVE the H1 (with a "---" rule between
    # them) -- so remove the nav line and, if what remains starts with a "---"
    # rule and blank lines before the first heading, drop those too, leaving the
    # H1 as the first line for the heading rewrite below.
    $content =~ s/^(?:\*\*Up:?\*\*.*|\*\*Up\*\*:.*|Up:.*|>\s*\[\[.*)\n//m;
    $content =~ s/\A(?:[ \t]*\n)*(?:-{3,}[ \t]*\n(?:[ \t]*\n)*)?(?=\#[ \t])//;
    # Drop the "Revision tags" metadata line -- kept for the vault's own
    # revision workflow, not useful to an epub reader.
    $content =~ s/^>\s*\*\*Revision tags:?\*\*.*\n//mi;

    # Shift every heading in the note down one level (H1->H2, H2->H3, ...) so
    # the note's own sections nest under its (now H2) title instead of sitting
    # at the same level -- previously only the H1 title line was touched,
    # which flattened every note's sections into the section-level TOC.
    $content = shift_headings($content, 1);
    # The note's H1 (now the first line) is now H2. For numbered notes, replace
    # its text with the heading_of() display (not just tag its anchor id) so the
    # chapter heading always shows the note's number, even when the source
    # file's own H1 text omits it. Unnumbered notes keep their own H1 verbatim.
    if (defined $heading_of{$name}) {
        $content =~ s/\A##[ \t]+.+\n/## $heading_of{$name} {#$id}\n/;
    } else {
        $content =~ s/\A##[ \t]+(.+)\n/## $1 {#$id}\n/;
    }
    $content =~ s/\n+(?:---\n+)?(?:\*\*(?:Next|Prev):?\*\*[^\n]*|(?:Next|Prev):[^\n]*|_[^\n]*(?:Next|Prev|Related|Navigate)[^\n]*_)\s*\z//;
    $content =~ s/\s*\z/\n/;
    $content = convert_wikilinks($content);
    $content = strip_app_links($content);
    $content = strip_hr($content);

    print $out $content, "\n\n";
}

close($out);

# Ensure a blank line always follows a bare "---" HR line -- otherwise pandoc's
# yaml_metadata_block scanner can misfire deep in the document with a hard error.
{
    open(my $fh, "<:encoding(UTF-8)", $md_out) or die;
    local $/; my $content = <$fh>; close($fh);
    $content =~ s/^---\n(?!\n)/---\n\n/mg;
    open(my $fh2, ">:encoding(UTF-8)", $md_out) or die;
    print $fh2 $content;
    close($fh2);
}
print "Wrote $md_out\n";

my @cmd = (
    $PANDOC, $md_out,
    "-o", $epub_out,
    "--toc", "--toc-depth=3",
    "--split-level=2",
    "--css", $css,
    "--metadata", "title=$title",
    "--metadata", "lang=en",
    "-f", "markdown",
    "-t", "epub3",
);
push @cmd, "--epub-cover-image", $cover if defined($cover) && length($cover);
print "Running: @cmd\n";
system(@cmd) == 0 or die "pandoc failed (exit $?)\n";
print "Wrote $epub_out\n";
