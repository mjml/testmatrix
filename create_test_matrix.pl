#!/bin/perl6

#
# The purpose of this script is to scan the current directory for all .cpp files and look for '@' directives
# in their /* comment blocks */. These directives contain the necessary information for generating "Makefile.matrix",
# which is capable of generating all of the required test executables.
#
# Typically, directives provide ranges of compiler -DDEFINED_XXX style switches. Each of these ranges forms a
# product matrix that determines a large number of executables to be built and run.
#

class TestGenerator {
  has %.directives is rw;
}

my @generators;

##
# Act I: In which source files are scanned and directives are parsed from comments.
##
for sort dir('.', test => { .IO.f && $_ ~~ /test.+\.cpp/ }) -> $file { # loop over test?? cpp files

  next unless $file ~~ /.*\.cpp/;

  my $gen = TestGenerator.new;

  my $fh = open :r, $file;
  my $text = $fh.slurp;

  for $text ~~ m:g/\/\*(.+)\*\// -> $match {
    my $comment = $match[0];
    $comment ~~ s:g/^^.*?\*.*?\@\s*//;
    $comment ~~ s/\n\s*?\n//;
    for split(/\n/, $comment) -> $kv {
      my ($k, $v) = split(/\:\s*/, $kv);
      next if !$v or !$k;
      $generator.directives{$k} = $v;
    }
  }

  if ($gen.directives.elems > 0) {
    say "$file: ", $gen.directives;
  }

  @generators.append: $gen;

}


##
# Act II: Wherein directives are processed and additional information is imported.
##
for @generators -> $gen {

  for $gen.directives.kv -> ($k, $v)  {
    when $k is "@include" {
      next unless open :r, $v;
      my $fh = $_;
      
      close: $fh;
    }
  }

}



##
# Act III: Heretofore no output has been generated, and henceforth the Makefile creation process will be elucidated.
##
