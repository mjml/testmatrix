
unit module TestMatrix;

grammar Basic is export {

  rule value { <simple-value> | <value-list> }
	token simple-value { <blob> | <quoted-string> }
	rule value-list { '[' <value>+ % ',' ']' }
	token identifier { <[a..zA..Z_]> (<[\w]>)* }
	token quoted-string { "\"" <-["]>+ "\"" }
	token blob { <[\S]-[\,]-[\"]>+ }

	token filename { <plain-filename> | <quoted-filename> }
	token quoted-filename { \" <-["]-[\n]>* \" } 
	token plain-filename { <[a..zA..Z0..9_\-\.\/ ]>+ }
	
}

class BasicParser is export {
			
	method value ($/) { make ($<simple-value> // $<value-list>).made }
	method simple-value ($/) { make ($<blob> // $<quoted-string>).made; }
	method value-list ($/) { make $<value>.elems > 1 ?? $<value>».made !! [ <value>.made ]; }
	method quoted-string ($/) { make $/.Str.substr(1).chop(1); }
	method identifier ($/) { make $/.Str;  }
	method blob ($/) { make $/.Str;  }

  method filename ($/) { make ($<plain-filename> // $<quoted-filename>).Str }
	method plain-filename ($/) { make $/.Str }
  method quoted-filename ($/) { make $/.Str.substr(1).chop(1) }

}
