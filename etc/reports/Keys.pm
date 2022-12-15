sub test {
  my $self= shift;
  my $d=shift;
  if (substr($d,0,1)=~/[ABCDEFG]/) {
    return '#22dd44';
  } else {
    return '#aa1122';
  } 
}
1;

