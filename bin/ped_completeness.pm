###########################################################
# ped_completeness.pm is used by Create_inbreedig_tables.pm
# to run parallel with 1 to 6 generations
###########################################################
sub ped_completeness {

    my $i = shift @_;
    my $start_animal;
    $j = 0;
    print "\n# start pedicompleteness for $i generations\n";
    $maxgen = $i;
    open( OUT, ">tmp$i.txt" );
    foreach $start_animal ( keys %ped ) {
        next if !$main::ped{$start_animal}[2];

        #my $start_animal= "44250"; print "doing animal $start_animal\n";
        my $its_sire  = $main::ped{$start_animal}[0];
        my $its_dam   = $main::ped{$start_animal}[1];
        my $sire_comp = 0;
        my $dam_comp  = 0;

        # SIRE
        if ( defined $its_sire ) {
            $completeness = .5 / ( 2**( 1 - 1 ) );
            $gen_counter = 1;
            my ($status) = &get_ped_mem($its_sire);
        }
        else {
            $completeness = 0;
        }
        $sire_comp = $completeness / $maxgen;

        # DAM
        if ( defined $its_dam ) {
            $completeness = .5 / ( 2**( 1 - 1 ) );
            $gen_counter = 1;
            my ($status) = &get_ped_mem($its_dam);
        }
        else {
            $completeness = 0;
        }
        $dam_comp = $completeness / $maxgen;
        my $indiv_comp = 0;

        # the result:
        if ( $sire_comp + $dam_comp > 0 ) {
            $indiv_comp =
                ( 4 * $sire_comp * $dam_comp ) / ( $sire_comp + $dam_comp );
        }
        # store per birth year:
        my $year =
              $i . '|'
            . $main::ped{$start_animal}[4] . '|'
            . $main::ped{$start_animal}[2];
        print OUT "$year" . '#' . "$indiv_comp" . '#' . "$start_animal\n";

    }
    close OUT;
}

1;
__END__

