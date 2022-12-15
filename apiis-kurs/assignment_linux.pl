#!/usr/bin/perl
while (! $a) {
  $i++;
  open(OUT, ">>test.output");
  print OUT "$i\n";
  close (OUT);
  sleep (2);
  last if ($i == 30);
}
