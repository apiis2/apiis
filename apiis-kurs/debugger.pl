#!/usr/bin/perl
uses CGI;
scalar_a='Perl with a lot of errors';
%hs_b=(a=>1, b=>2, c->3);
foreach $l ('test1', 'test2', 'test3') 
  print "loop $l" . \n"; 

}
print $scalar_a
print %hs_b;
