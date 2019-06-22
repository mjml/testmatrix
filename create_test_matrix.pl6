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

my $homedir = $*PROGRAM.absolute.IO.resolve.dirname.IO;

# A source file generates one of these using all the /** **/ comments found inside it
class TestGenerator {
	has $.sourcefn is rw;
	has $.prefix is rw;
	has @.ccparams is rw = [""];
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
	has $.ccparams is rw = "";
	has $.ldparams is rw = "";
	has $.deps is rw = "";
	
	method exename { $!uid.chars > 0 ?? $!prefix ~ '-' ~ $!uid !! $!prefix }
	method objname { (so $!sourcefn ~~ /\.[cpp|cxx|cc]$/) ?? self.exename ~ ".obj" !! self.exename ~ ".o" }
}

# A single test case that has an input and is scheduled to be run with other tests
class TestCase {
	has $.uid is rw = "";
	has $.inputfile is rw = "";
	has TestExecutable $.texe is rw;
}

sub infix:<|~|> (Str $a, Str $b) {
	when ($a eq "") { return $b; }
	when ($b eq "") { return $a; }
	if (so $a ~~ /\s$$/) or (so $b ~~ /^\s/) { return $a ~ $b; }
	else { return $a ~ " " ~ $b; } 
}

my @generators = [];
my @texes = [];
my @cases = [];
	

grammar TestInfo {
	
	rule TOP { ^ <statement-list> $ }
	rule statement-list { [ <statement> ] * }
	rule statement { <include-statement> | <ccparams-statement> | <ldparams-statement> | <input-statement> | <define-variants-statement> }
	
	rule include-statement { '@include' <simple-value> }
	rule ccparams-statement { '@ccparams' <value> }	
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
		(my $fh = open($fn)) or (warning("Couldn't open @included file " ~ $fn) and return);
		sub {
			$grammar.parse($fh.slurp, actions => $inner);
			@.ops.append($inner.ops);
		}();
	}
	method ccparams-statement($/) {
		$<value> ==> map({$_.made}) ==> my @values;
		@.ops.append: sub (TestGenerator $gen is rw) {
			$gen.ccparams = $gen.ccparams X|~| @values;
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
			$gen.ccparams = $gen.ccparams X|~| map({ "-D" ~ $id ~ "=" ~ $_ }, @values); 
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
	
	($gen.ccparams X, $gen.ldparams).kv
	==> map(-> $i,($cc,$ld)	{ TestExecutable.new(uid=>$i, sourcefn=>$gen.sourcefn, prefix=>$gen.prefix, ccparams=>$cc, ldparams=>$ld) })
	==> my @t;
	$gen.texes = @t;
	@texes.append: @t;

	($gen.texes X, $gen.inputs).kv
	==> map(-> $i, ($texe, $in) { TestCase.new(uid=>$i, texe=>$texe, inputfile=>$in) })
	==> @cases;

}


@texes
	==> map({ (.objname, .sourcefn, .ccparams, .sourcefn, .objname) })
	==> map({ sprintf("%s: %s\n\t\$(CXX) \$(CXXPARAMS) %s -c %s -o %s", $_) }) 
	==> my @objrules;

@texes
	==> map({ (.exename, .objname, .ldparams, .exename, .objname) })
	==> map({ sprintf("%s: %s\n\t\$(CXX) \$(LDPARAMS) %s -o %s %s", $_) })
	==> my @exerules;
	
@cases
	==> map({ ( .texe.exename, .texe.exename, .texe.exename, .inputfile ) })
	==> map({ sprintf("%s-run: %s\n\t./%s %s", $_) })
	==> my @caserules;

$makefile ~= "@tests: " ~ (@cases ==> map({ $_.texe.exename ~ "-run" })) ~ "\n\n";
$makefile ~= "@clean: \n\trm -rf " ~ @texes>>.exename ~ " " ~ @texes>>.objname ~ "\n\n";
$makefile ~= join("\n\n", @objrules, @exerules, @caserules);
say $makefile;
