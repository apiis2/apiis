#!/usr/bin/perl -w
foreach $a ('1122334455 aa bb','00111115','1aab','bb ca db','llcld\)ld') {
  print $a."\n" if ($a=~/^.*c.*b$/); 
}
