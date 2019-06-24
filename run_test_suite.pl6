#!/bin/perl6

my $builddir = "./build";
my $outputdir = "./output";
my $manifestfn = "manifest.txt";
my Int $parlimit = 1;
my $mr_run = 0;
my Bool $console_mode = True;

if (grep({ not (.IO.e && .IO.d) }, [ $builddir, $outputdir ] ))  {
	
	say "Couldn't find " ~ (@_.elems > 1 ?? "directories " !! "directory ") ~ @_;
}

given join(' ', @*ARGS) {
	if /\-j ' ' (\d+)/ {
    $parlimit = Int($0) || 1;
	}
	if /\-t/ {
	}
}

grammar TestManifest {
	rule TOP { <run> * }
	rule run { 'run' <filename> [ 'args' <value> ]? [ 'input' <filename> ]? [ 'output' <filename> ]? }
	token filename { <plain-filename> | <quoted-filename> }
	token quoted-filename { \" <-["]-["]-[\n]>* \" }  # " <- annoying syntax coloring bugfix
	token plain-filename { <[a..zA..Z0..9_\-\. ]>+ }
}

my $manifest = ($builddir ~ '/' ~ $manifestfn).IO.open() or die "Couldn't find manifest.txt";
my $grmr = TestManifest.new;
$grmr.parse($manifest.slurp());

