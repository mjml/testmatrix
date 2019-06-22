#!/bin/perl6

#
# The purpose of this script is to scan the current directory for all .cpp files and look for '@' directives
# in their /* comment blocks */. These directives contain the necessary information for generating "Makefile.matrix",
# which is capable of generating all of the required test executables.
#
# Typically, directives provide ranges of compiler -DDEFINED_XXX style switches. Each of these ranges forms a
# product matrix that determines a large number of executables to be built and run.
#

#use Grammar::Tracer;

my $homedir = $*PROGRAM.dirname.IO;
my @default_cxxparams = [ "-I" ~ $homedir.Str, "-Iinclude" ];
my $build_dir = "./build";
my $include_dir = "include";

# A source file generates one of these using all the /** **/ comments found inside it
class TestGenerator {
	has $.sourcefn is rw;
	has $.prefix is rw;
	has @.cxxparams is rw = [join @default_cxxparams];
	has @.cxxheader is rw = [""];
	has @.ldparams is rw = [""];
	has @.inputs is rw = [""];
	has @.ops is rw = [];
	has @.texes is rw = [];
	has @.cases is rw = [];
}

# A single executable file that can run several tests
class TestExecutable {
	has $.uid is rw = "";
	has $.sourcefn is rw = "";
	has $.prefix is rw = "";
	has $.cxxparams is rw = "";
	has $.cxxheader is rw = "";
	has $.ldparams is rw = "";
	has $.deps is rw = "";
	
	method exename { $!uid.chars > 0 ?? $!prefix ~ '-' ~ $!uid !! $!prefix }
	method exepath { $build_dir ~ "/" ~ self.exename }
	method objname { (so $!sourcefn ~~ /\.[cpp|cxx|cc]$/) ?? self.exename ~ ".obj" !! self.exename ~ ".o" }
	method objpath { $build_dir ~ "/" ~ self.objname }
	method cxxheaderpath { $include_dir ~ "/" ~ self.exename ~ "_include.h" }
}

# A single test case that has an input and is scheduled to be run with other tests
class TestCase {
	has $.uid is rw = "";
	has $.inputfile is rw = "";
	has TestExecutable $.texe is rw;
	
	method label { $!texe.exename ~ "-run" ~ $!uid }
}

sub infix:<|~|> (Str $a, Str $b) {
	when ($a eq "") { return $b; }
	when ($b eq "") { return $a; }
	if (so $a ~~ /\s$$/) or (so $b ~~ /^\s/) { return $a ~ $b; }
	else { return $a ~ " " ~ $b; } 
}
sub infix:< <~> > (Str $a, Str $b) {
	when ($a eq "") { return $b; }
	when ($b eq "") { return $a; }
	if (so $a ~~ /\n$$/) or (so $b ~~ /^\n/) { return $a ~ $b; }
	else { return $a ~ "\n" ~ $b; }
}

my @generators = [];
my @texes = [];
my @cases = [];
	

grammar TestInfo {
	
	rule TOP { ^ <statement-list> $ }
	rule statement-list { [ <statement> ] * }
	rule statement { <include-statement> | <cxxparams-statement> | <ldparams-statement> | <input-statement> | <define-variants-statement> }
	
	rule include-statement { '@include' <simple-value> }
	rule cxxparams-statement { '@cxxparams' <value> }	
	rule ldparams-statement { '@ldparams' <value> }
	rule input-statement { '@input' <simple-value> }
	rule define-variants-statement { '@define-variants' <identifier> <value>  }
	
	rule value-list { '[' <value> [ ',' <value> ] * ']' }
	token value { <simple-value> | <value-list> }
	token simple-value { <blob> | <quoted-string> }
	token identifier { <[a..zA..Z_]> (<[\w]>)* }
	token quoted-string { "\"" <-["]>+ "\"" }
	token blob { <[\S]-[\,]-[\"]>+ }
	
	method error(--> ::TestInfo:D) {
		return self;
	}
	
}
class Metaparser {

	has $.rootfn is rw;
	has $.filename is rw;
	has @.ops is rw;
	
	method include-statement($/) {
		my $grammar = TestInfo.new;
		my $inner = Metaparser.new(:rootfn<$!rootfn>);
		my $fn = $<simple-value>.Str;
		my $fh = open($fn) or warning("Couldn't open @included file " ~ $fn) and return;
		sub {
			$grammar.parse($fh.slurp, actions => $inner);
			@.ops.append($inner.ops);
		}();
	}
	method cxxparams-statement($/) {
		$<value> ==> map({$_.made}) ==> my @values;
		@.ops.append: sub (TestGenerator $gen is rw) {
			$gen.cxxparams = $gen.cxxparams X|~| @values;
		}
	}
	method input-statement($/) {
		$<value> ==> map({$_.made}) ==> my @values;
		@.ops.append: sub (TestGenerator $gen is rw) {
			$gen.inputs.append: @values;
		}
	}
	method ldparams-statement($/) {
		$<value> ==> map({$_.made}) ==> my @values;
		@.ops.append: sub (TestGenerator $gen is rw) {
			$gen.ldparams = $gen.ldparams X|~| @values;
		}
	}
	method define-variants-statement($/) {
		my $id = $<identifier>.made;
		my @values = $<value>.made;
		@.ops.append: sub (TestGenerator $gen is rw) {
			#old style: we're putting these in their own include file now
			#$gen.cxxparams = $gen.cxxparams X|~| map({ "-D" ~ $id ~ "=" ~ $_ }, @values);
			$gen.cxxheader = $gen.cxxheader X<~> map({ "#define " ~ $id ~ ' ' ~ $_ }, @values);
		}
	}
	method filename ($/) { make ($<blob> // $<quoted-string>).made; }
	method value ($/) { make ($<simple-value> // $<value-list>).made  }
	method simple-value ($/) { make ($<blob> // $<quoted-string>).made; }
	method value-list ($/) { make $<value>.elems > 1 ?? $<value>».made !! [ <value>.made ]; }
	method quoted-string ($/) { make $/.Str.substr(1).chop(1); }
	method identifier ($/) { make $/.Str;  }
	method blob ($/) { make $/.Str;  }

}

sub error (Str $str) {
	say "\e[31mError\e[0m: " ~ $str;
}

sub warning (Str $str) {
	say "\e[38;5;166mWarning\e[0m: " ~ $str;
}

my Str $makefile = "";

for sort dir('.', test => { .IO.f && $_ ~~ /test.*\.[cxx|cpp|cc|c]/ }) -> $filename { # loop over test?? cpp files
	#my $filename = "test1.cpp".IO;
  my TestGenerator $gen = TestGenerator.new( sourcefn => $filename.Str, prefix => ($filename.Str ~~ /(.*)\.[cxx|cpp|cc|c]/)[0].Str );
  my $fh = $filename.open;
  for $fh.comb(/\/\*\*(.+)\*\*\//, True) -> $match {
	  my $comment = $match[0];
		my $grammar = TestInfo.new;
		my $parser = Metaparser.new;
	  $comment ~~ s:g/^^ \s* [ \/\*\* | \*\*\/ | \* ] \s*?\n?//; # removes comment marks
		$grammar.parse($comment, actions => $parser);
		$gen.ops.append( $parser.ops );
  }
	
	$gen.ops ==> map({ $_($gen) });

	($gen.cxxheader X, $gen.cxxparams X, $gen.ldparams).kv
	==> map(-> $i,($ch,$cc,$ld) { TestExecutable.new(uid=>$i, cxxheader=>$ch, sourcefn=>$gen.sourcefn, prefix=>$gen.prefix, cxxparams=>$cc, ldparams=>$ld) })
	==> my @t;
	$gen.texes = @t;
	@texes.append: @t;

	for @t -> $texe {
		my $fh = open(:w, $texe.cxxheaderpath);
		$fh.print("// include file for " ~ $texe.exename ~ "\n\n");
		$fh.print($texe.cxxheader ~ "\n");
		$fh.close();
	}
	
	
	my $multicase = $gen.inputs.elems > 1;
	$gen.texes X, ([1...10000] Z, $gen.inputs)
	==> map(-> ($texe,($i, $in)) { TestCase.new(uid=>($multicase??$i!!""), texe=>$texe, inputfile=>$in) })
	==> my @c;
	$gen.cases = @c;
	@cases.append: @c;

}

@texes
	==> map({ (.objpath, .sourcefn, .cxxheaderpath, .cxxparams, .sourcefn, .objpath) })
	==> map({ sprintf("%s: %s\n\t\$(CXX) \$(CXXPARAMS) -include %s %s -c %s -o %s", $_) }) 
	==> my @objrules;

@texes
	==> map({ (.exepath, .objpath, .ldparams, .exepath, .objpath) })
	==> map({ sprintf("%s: %s\n\t\$(CXX) \$(LDPARAMS) %s -o %s %s", $_) })
	==> my @exerules;
	
@cases
	==> map({ ( .label, .texe.exepath, .texe.exepath, .inputfile ) })
	==> map({ sprintf("%s: %s\n\t./%s %s", $_) })
	==> my @caserules;

$makefile ~= "@test: " ~ (@cases>>.label) ~ "\n\n";
$makefile ~= "@tests: " ~ (@texes>>.exepath) ~ "\n\n";
$makefile ~= "@clean: \n\trm -rf " ~ @texes>>.exepath ~ " " ~ @texes>>.objpath ~ " " ~ @texes>>.cxxheaderpath ~ "\n\n";
$makefile ~= join("\n\n", @objrules, @exerules, @caserules);
say $makefile;
