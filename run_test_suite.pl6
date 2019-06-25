#!/bin/perl6

use TestMatrix;

my $builddir = "./build";
my $outputdir = "./output";
my $manifestfn = "manifest.txt";
my Int $parlimit = 1;
my $mr_run = 0;
my Bool $console_mode = $*OUT.t;
my $current_cline = 0;
my $console_lock = Lock.new;
my Promise @work = [];

my Proc::Async @testprocs;

sub console_print (+@values) {
	$console_lock.lock();
	print join(' ', @values);
	$*OUT.flush;
	$current_cline++;
	$console_lock.unlock();	
}

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
	rule run { 'run' '{' 'exec' <filename>   <args-decl>?  <input-decl>?  <output-decl>? '}' }
	rule args-decl { 'args' <value> }
	rule input-decl { 'input' <filename> }
	rule output-decl { 'output' <filename> }
}

class ManifestParser is BasicParser {
  method run ($/) {
		my ($execfile, $inputfile, $outputfile) = ($<filename>, $<input-decl>, $<output-decl>)>>.made;
		my @args = $<args-decl>.made if $<args-decl>;
		my $sargs = join(' ', @args) || "";
		my $testname;
		sub { $execfile ~~ /\.\/build\/(.*)/; $testname = $0.Str }();
		$inputfile ==> map({ "-f " ~ $_ }) ==> @args;
		my $proc = Proc::Async.new( $execfile, $sargs );
		my $oh = $outputfile.IO.open(:w);
		$proc.bind-stdout($oh);
		$proc.bind-stderr($oh);
		$console_lock.lock();
		my $cline = $current_cline;
		my $label = sprintf("[ %s %s > %s ]", $testname, $sargs, $outputfile);
		console_print sprintf("[\e[38;2;200;100;0mBUSY\e[0m] %s\n", $label) if $console_mode;
		my $promise = $proc.start;
		close($oh);
		$promise.then: { $console_lock.lock; on_test_finished($_.result , $testname, $current_cline - $cline); $console_lock.unlock; };
		@work.append: $promise;
		$console_lock.unlock();
	}
	method args-decl ($/) { make $<value>.made }
	method input-decl ($/) { make $<filename>.made }
	method output-decl ($/) { make $<filename>.made }
	
}

sub on_test_finished (Proc $p, Str $testname, Int $h) {
	if ($console_mode) {
		my $code = $p.exitcode || $p.signal;
		if $code == 0 {
			$console_lock.protect: { printf("\e7\e[%sA\e[1C\e[38;2;0;180;0mPASS\e[0m\e8", $h) }
		} else {
			$console_lock.protect: { printf("\e7\e[%sA\e[1C\e[38;2;180;0;0mFAIL\e[0m\e8", $h) }
		}
	} else {
		# need to pass the label in here
		my $label = "";
		if $p.exitcode == 0 {
			console_print sprintf("[PASS] %s", $label);
		} else {
			console_print sprintf("[FAIL] %s", $label);
		}
	}
}

my $manifest = ($builddir ~ '/' ~ $manifestfn).IO.open() or die "Couldn't find manifest.txt";
my $grmr = TestManifest.new;
$grmr.parse($manifest.slurp(), actions => ManifestParser.new);
$manifest.close;

console_print("Waiting for tests to finish...\n");

await(@work);

printf("\e7\e[1A                                   \e8");
say "Done.";
