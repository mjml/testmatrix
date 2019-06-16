#!/bin/perl6

#
# The purpose of this script is to scan the current directory for all .cpp files and look for '@' directives
# in their /* comment blocks */. These directives contain the necessary information for generating "Makefile.matrix",
# which is capable of generating all of the required test executables.
#
# Typically, directives provide ranges of compiler -DDEFINED_XXX style switches. Each of these ranges forms a
# product matrix that determines a large number of executables to be built and run.
#

use Grammar::Tracer;

class TestGenerator {
	has $.filename is rw;
	has $.prefix is rw;
  has %.directives is rw;
	has @.axes is rw;
}

my @generators;

grammar TestInfo {
	
	rule TOP { ^ <statement-list> $ }
	rule statement-list { [<simple-statement> | <block-statement>] * }
	rule simple-statement { [| <identifier> | <keyword>] ':' <value> }
	rule block-statement { [| <identifier> | <keyword> ] <block> }
	token identifier { <[a..zA..Z_]> (<[\w]>|<[-]><[a..zA..Z]>)* }
	token keyword { '@' ('include' | 'compilerswitch-axis' | 'input-axis' | 'input-regex-axis' | 'input-dir' | 'include-dir' | 'testtype' )}
	token value { <blob> | <quoted-string> | <listexpr> | <block> }
	token quoted-string { '\"' <-["]>+ '\"' }
	rule value-list { <value> [ ',' <value> ] * }
	token blob { \S+ }
	rule listexpr { '[' <value-list> ']' }
	rule block { '{' <statement-list> '}' }
	
	method error(--> ::TestInfo:D) {
		return self;
	}
	
}

class Metaparser {
	
	method TOP ($/) { $/; }
	method statement-list ($/) { make [,] $<statement>.made;  }
	method statement ($/) {
		my $u = ;
	}
	method identifier ($/) { }
	method keyword ($/) { }
	method value ($/) { }
	method quoted-string ($/) { }
	method value-list ($/) { }
	method blob ($/) { }
	method listexpr ($/) { }
	method block ($/) { }

}

sub error (Str $str) {
	say "\e[31mError\e[0m: " ~ $str;
}

sub warning (Str $str) {
	say "\e[38;5;166mWarning\e[0m: " ~ $str;
}

sub parse_directives(Str $str) returns Hash {
	my %directives;
  for split(/\n/, $str) -> $kv {
    my ($k, $v) = split(/\:\s*/, $kv);
    next if !$v or !$k;
		when $k ~~ "include" {
			my $includefn = $v;
			(my $fh = open($includefn)) or (warning("Couldn't include $includefn") and next);
			my %included = parse_directives($fh.slurp);
			%directives{keys %included} = values %included;
	  }
    %directives{$k} = $v;
  }
	return %directives;
}

##
# Act I: In which source files are scanned and directives are parsed from block comments.
##
for sort dir('.', test => { .IO.f && $_ ~~ /test.+\.cpp/ }) -> $filename { # loop over test?? cpp files
	
  next unless $filename ~~ /.*\.cpp$/;
  
  my $gen = TestGenerator.new;
  my $fh = $filename.IO.open;
	
  for $fh.comb(/\/\*\*(.+)\*\*\//, True) -> $match {
	  my $comment = $match[0];
	  $comment ~~ s:g/^^ \s* [ \/\*\* | \*\*\/ | \* ] \s*?\n?//;
		#$gen.directives = parse_directives($comment);
		say $comment;
		say TestInfo.parse($comment, actions => Metaparser);
  }
  
  if ($gen.directives.elems > 0) {
    say "$filename: ", $gen.directives;
  }
  
	$gen.filename = $filename.Str;
	$filename ~~ m/(.*?)\.\w+$/;
	$gen.directives{"prefix"} = $0.Str;
	
  @generators.append: $gen;
  
}


##
# Act II: Wherein directives are processed and additional information and directives are imported.
##
for @generators -> $gen {
	
  for $gen.directives.kv -> $k, $v  {
		
		# Generate a determinate axis of compile-switch variants
		when $k ~~ "compileswitch-axis" {
			my $hashstr = $v;
		}
		# Generates a determinate axis based on a list of filenames
		when $k ~~ "input-axis" {
			my $regex = $v;
	  }
		# Generate an indeterminate axis of input-file variants that match a regex
		when $k ~~ "input-regex-axis" {
			my $regex = $v;
		}
		# Adds a directory to the list of directories searched for input files using @inputfile-axis and @inputfile-regex-axis
		when $k ~~ "input-dir" {
			my $dirname = $v;
		}
		# Adds a directory to the list of directories search for include files using @include 
		when $k ~~ "include-dir" {
			my $dirname = $v;
		}
		
  }
	
}


##
# Act III: Hitherto no output has been generated, and henceforth the Makefile creation process will be elucidated.
##
for @generators -> $gen {

	my %targets;
	
	for $gen.directives.kv -> $k, $v {
		
		
		
	}
	
}
