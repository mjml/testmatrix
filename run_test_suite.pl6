#!/bin/perl6

use TestMatrix;
use Grammar::Tracer;

my $builddir = "./build";
my $outputdir = "./output";
my $manifestfn = "manifest.txt";
my Int $parlimit = 1;
my $mr_run = 0;
my Bool $console_mode = $*OUT.t;
my $current_cline = 0;

my Proc::Async @testprocs;

if (grep({ not (.IO.e && .IO.d) }, [ $builddir, $outputdir ] ))  {
	say "CWD is not currently in the proper testing environment.";
	say "Couldn't find " ~ (@_.elems > 1 ?? "directories " !! "directory ") ~ @_;
	die;
}

given ($builddir ~ '/' ~ $manifestfn).IO {
	die "Couldn't find manifest.txt" if not .e;
}

given join(' ', @*ARGS) {
	if /\-j ' ' (\d+)/ { $parlimit = Int($0) || 1 }
	if /\-t/ { #etc..
	}
}

grammar TestManifest is TestMatrix::Basic {
	has @.ops is rw = [];
	rule TOP { <run> * }
	rule run {
		'run' '{'
		'exec' <filename> 
		[ 'args' <value> ]?
		[ 'input' <filename> ]?
		[ 'output' <filename> ]? '}'
	}
}

class ManifestParser is BasicParser {
  method run ($/) {
		my ($execfile, $inputfile, $outputfile) = $<filename>>>.made;
		say "inputfile is " ~ $inputfile;
		say "outputfile is " ~ $outputfile;
		my @args = $<value>>>.made;
		$inputfile ==> map({ "-f " ~ $_ }) ==> @args;
		given Proc::Async.new( $execfile, @args ) {
			my $fh = $outputfile.IO.open(:w);
			react {
				my $cline = $current_cline;
				
				whenever $_.Supply.lines -> $s { $fh.print($s) }
				whenever $_.start { on_test_finished($_, $current_cline - $cline)  }
			}
		}
	}
	
}

sub on_test_finished (Promise $p, Int $h) {
	
}

my $manifest = ($builddir ~ '/' ~ $manifestfn).IO.open() or die "Couldn't find manifest.txt";
my $grmr = TestManifest.new;
$grmr.parse($manifest.slurp(), actions => ManifestParser.new);
$manifest.close;

