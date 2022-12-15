##############################################################################
# $Id: Popreport.pm,v 1.33 2021/05/27 20:02:46 ulf Exp $
##############################################################################

$VERSION = '$Revision: 1.33 $';

=head1 NAME

popreport.pm

=head1 DESCRIPTION

Stores common subroutines for creating the population/inbreeding reports.

=cut


use strict;
use warnings;
use Graph;
use Graph::Writer::Dot;
use Mail::Sendmail;
use Apiis::Misc qw( MaskForLatex );

##############################################################################

=head2 print_list

   B<print_list> prints as input passed messages to the file.

   input: 1. the message to print 2. the filename to print into (in the
   current directory)

   output: none

   The file is closed after every print as it is accessed from different
   programs.

=cut

sub print_list {
    my ( $msg, $file ) = @_;
    return if !defined $msg;
    return if !defined $file;
    return if !-f $file;
    my $indent = ' ' x 21 . '==> ';
    if ($file) {
        open my $OUT, '>>:encoding(utf-8)', $file
            or warn "Cannot open file $file: $!\n";
        my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
            localtime(time);
        $year += 1900;
        $mon++;
        my $curr_hour = sprintf '%.2u:%.2u:%.2u', $hour, $min, $sec;
        printf $OUT "%s%s %s\n", $indent, $curr_hour, $msg;
        close $OUT;
    }
}

##############################################################################

=head2 print_tex_item

   B<print_tex_item> prints the passed messages as an LaTeX \item to the file

   input: 1. the message to print 2. the filename to print into (in the
   current directory)

   output: none

   The file is closed after every print as it is accessed from different
   programs.

=cut

sub print_tex_item {
    my ( $msg, $file ) = @_;
    return if !defined $msg;
    return if !defined $file;
    if ($file) {
        open my $TEXOUT, '>>:encoding(utf-8)', $file or warn "Cannot open file $file: $!\n";
        printf $TEXOUT '\item %s', $msg . "\n";
        close $TEXOUT;
    }
}

##############################################################################
sub test_sire_eq_dam {
    my $cfg = shift;
    my $pedref = $cfg->{ped};
    my $extended = $cfg->{extended};
    my %sire_eq_dam;
    ANIMAL:
    for my $animal ( keys %{$pedref} ) {
        next ANIMAL if $animal == 1;    # base animal
        next ANIMAL if $animal == 2;    # base animal

        SIRE_DAM: {
            my $sire = $pedref->{$animal}[0];
            last SIRE_DAM if !$sire;
            my $dam = $pedref->{$animal}[1];
            last SIRE_DAM if !$dam;
            $sire_eq_dam{$animal} = $sire if $sire eq $dam;
        }
    }

    # notification:
    if ( scalar keys %sire_eq_dam ) {
        my @elines;
        my $i;

        my ( $max, $max_errs );
        $max = $max_errs = $cfg->{'max_errors'};
        my $no_sire_eq_dams = scalar keys %sire_eq_dam;
        my $addmsg = " (max. $max displayed)" if $max < $no_sire_eq_dams;

        push @elines,
            sprintf "%u animals have the same animal as sire and dam%s:",
            $no_sire_eq_dams, ( $addmsg || '' );
        push @elines, '\begin{verbatim}';

        my $note;
        SIRE_EQ_DAM:
        for my $animal ( sort { $a <=> $b } keys %sire_eq_dam ) {
            last SIRE_EQ_DAM if $max-- <= 0;
            
            my $ext_animal;
            my $ext_parent;
            $ext_animal = decode_animal( $animal, $cfg );
            $ext_parent = decode_animal( $sire_eq_dam{$animal}, $cfg );

            if ($extended) {
                push @elines,
                    sprintf "animal: %s (int: %s) sire/dam: %s (int: %s)",
                    $ext_animal, $animal,
                    ( defined $ext_parent ? $ext_parent : 'empty' ),
                    $sire_eq_dam{$animal};
            }
            else {
                push @elines, sprintf "animal: %s sire/dam: %s",
                    $ext_animal, ( defined $ext_parent ? $ext_parent : 'empty' );
            }

            # special case (parents are 0):
            if ( defined $ext_parent and $ext_parent == 0 ) {
                $note = "Hint: Undefined sires or dams should be left empty "
                    . "or marked as 'unknown'. 0 (zero) is treated as a valid Id"
                    . "\\\\The input format of the pedigree file is described in detail at: ";
                my $note2 = "http://popreport.tzv.fal.de/doc/poprep-manual.html.LyXconv/index.html";
                $note .= "\\hyperref{$note2}{}{}{$note2}";
            }
        }
        if ( ( $max <= 0 ) and ( $max_errs < $no_sire_eq_dams ) ) {
            push @elines, sprintf '.... %u additional lines not displayed',
                $no_sire_eq_dams - $max_errs;
        }
        push @elines, '\end{verbatim}';
        push @elines, $note if $note;

        push @{ $cfg->{err_mesgs} }, join( "\n", @elines );
    }
}
##############################################################################
sub test_parent_is_known {
    my $cfg      = shift;
    my $pedref   = $cfg->{ped};
    my $listfile = $cfg->{listfile};
    my $count    = 0;

    ANIMAL2:
    for my $animal ( keys %{$pedref} ) {
        next ANIMAL2 if $animal == 1;    # base animal
        next ANIMAL2 if $animal == 2;    # base animal
        my %parents;
        $parents{'sire'} = $pedref->{$animal}[0];
        $parents{'dam'}  = $pedref->{$animal}[1];

        PARENT:
        for my $key ( keys %parents ) {
            my $parent = $parents{$key};
            next PARENT if !defined $parent;
            next PARENT if $parent == 1;
            next PARENT if $parent == 2;
            next PARENT if exists $pedref->{$parent};    # ok

            # parent is defined but not as animal,
            # create new animal with unknown sire/dam:
            $pedref->{$parent}[0] = 1;
            $pedref->{$parent}[1] = 2;
            $pedref->{$parent}[3] = $cfg->{'male_code'} if $key eq 'sire';
            $pedref->{$parent}[3] = $cfg->{'female_code'} if $key eq 'dam';
            $pedref->{$parent}[5] = 1;
            $count++;
        }
    }
    if ($count) {
        my $msg = "INFO: $count base parents had no entry as animal! Created.";
        print_list( $msg, $listfile );
        my $texlist = $listfile;
        $texlist =~ s/lst$/tex/;
        print_tex_item( $msg, $texlist );
    }
}
##############################################################################

sub test_loop {
    my ( $animal, $stack_ref, $cfg ) = @_;
    my $listfile = $cfg->{'listfile'};
    return if !defined $animal;
    return if $cfg->{err_stat_die};
    my $pedref = $cfg->{ped};
    return if $pedref->{$animal}[5];    # clean

    # end of chain for sire, if he is clean:
    my $sire = $pedref->{$animal}[0];
    my $clean_sire = $pedref->{$sire}[5] if defined $sire;

    # end of chain for dam, if she is clean:
    my $dam = $pedref->{$animal}[1];
    my $clean_dam = $pedref->{$dam}[5] if defined $dam;

    # both parents are clean:
    if ( $clean_sire and $clean_dam ) {
        $pedref->{$animal}[5] = 1;      # animal is also clean
        return;
    }
    my $found;
    if ( defined $sire and grep {/^${sire}$/} @{$stack_ref} ) {
        push @{$stack_ref}, $sire;
        $found++;
    }
    if ( defined $dam and grep {/^${dam}$/} @{$stack_ref} ) {
        push @{$stack_ref}, $dam;
        $found++;
    }
    if ($found) {
        push @{$stack_ref}, $animal;
        draw_loop( $stack_ref, $cfg );
        my @ext_animals =
            map { decode_animal( $_, $cfg ) } @{$stack_ref};
        @ext_animals = map { MaskForLatex($_) } @ext_animals;
        my %involved = map { $_ => 1 } @ext_animals;    # no duplicates

        push @{ $cfg->{err_mesgs_die} },
            'Pedigree loop encountered. Terminated ... \\\\';
        push @{ $cfg->{err_mesgs_die} }, sprintf "%u involved animals: \\\\",
            scalar keys %involved;
        push @{ $cfg->{err_mesgs_die} }, sprintf "%s",
            join( '-', sort keys %involved );

        $cfg->{err_stat_die} = 255;    # catch this error in the wrapper
        return 1;
    }
    push @{$stack_ref}, $animal;
    test_loop( $sire, $stack_ref, $cfg ) if defined $sire and !$clean_sire;
    test_loop( $dam,  $stack_ref, $cfg ) if defined $dam and !$clean_dam;
    pop @{$stack_ref};
}
##############################################################################
# This test_loop() has a counter and loops as long through the tree as the
# counter is exhausted. This is somehow ineffective and provides a big stack,
# if a loop is found.
sub test_loop_old {
    my ( $animal, $counter, $cfg ) = @_;
    return if ! $animal;
    return if $cfg->{err_stat_die};
    my $pedref = $cfg->{ped};

    if ( $counter <= $cfg->{max_loops} ) {
        # end of chain if animal is clean:
        return if $pedref->{$animal}[5];    # clean

        # end of chain for sire, if he is clean:
        my $sire = $pedref->{$animal}[0];
        my $clean_sire = $pedref->{$sire}[5] if defined $sire;

        # end of chain for dam, if she is clean:
        my $dam = $pedref->{$animal}[1];
        my $clean_dam = $pedref->{$dam}[5] if defined $dam;

        # both parents are clean:
        if ( $clean_sire and $clean_dam ) {
            $pedref->{$animal}[5] = 1;    # animal is also clean
            return;
        }

        # loop recursively:
        test_loop( $sire, $counter + 1, $cfg ) if defined $sire and !$clean_sire;
        test_loop( $dam, $counter + 1, $cfg ) if defined $dam and !$clean_dam;
    }
    else {
        # endless loop! loop again and store involved animals for notification:
        my $loop_animals_ref = $cfg->{loop_animals};
        $loop_animals_ref->{$animal}++;
        if ( $loop_animals_ref->{$animal} >= $cfg->{loop_counter} ) {
            push @{ $cfg->{err_mesgs_die} },
                "Pedigree loop encountered. Terminated ...";
            push @{ $cfg->{err_mesgs_die} }, sprintf "%u involved animals:",
                scalar keys %{$loop_animals_ref};
            my @ext_animals =
                map { decode_animal( $_, $cfg ) } keys %{$loop_animals_ref};
            @ext_animals = map { MaskForLatex( $_ ) } @ext_animals;
            push @{ $cfg->{err_mesgs_die} }, sprintf "%s",
                join( '-', sort @ext_animals );
            $cfg->{err_stat_die} = 255; # catch this type of error in the wrapper
            return;
        }
        my $sss = $pedref->{$animal}[0];
        my $ddd = $pedref->{$animal}[1];
        test_loop( $sss, $counter + 1, $cfg ) if defined $sss and $sss ne 1;
        test_loop( $ddd, $counter + 1, $cfg ) if defined $ddd and $ddd ne 2;
    }
}
##############################################################################
# we have a loop, so read the loop animals into Graph:
sub draw_loop {
    my ( $stack_ref, $cfg )     = @_;
    my $pedref    = $cfg->{ped};
    my $graph     = Graph->new();

    for my $animal ( @{$stack_ref} ){
        my $ext_animal = decode_animal($animal, $cfg);
        my $sire = $pedref->{$animal}[0];
        my $dam  = $pedref->{$animal}[1];
        if ( defined $sire and grep {/^${sire}$/} @{$stack_ref} ){
            my $ext_sire = decode_animal($sire, $cfg);
            $graph->add_edge( $ext_animal, $ext_sire );
            $graph->set_vertex_attribute( $ext_animal, 'color', 'blue' );
            $graph->set_edge_attribute( $ext_animal, $ext_sire, 'color', 'red' );
        }
        if ( defined $dam and grep {/^${dam}$/} @{$stack_ref} ){
            my $ext_dam = decode_animal($dam, $cfg);
            $graph->add_edge( $ext_animal, $ext_dam );
            $graph->set_vertex_attribute( $ext_animal, 'color', 'blue' );
            $graph->set_edge_attribute( $ext_animal, $ext_dam, 'color', 'red' );
        }
    }
    my $writer = Graph::Writer::Dot->new();
    $writer->write_graph( $graph, "loopgraph.dot" );
    `dot -Tfig -o "loopgraph.fig" "loopgraph.dot" && fig2dev -Lpdf "loopgraph.fig" "loopgraph.pdf"`;
}
##############################################################################
sub test_sex {
    my $cfg         = shift;
    my $pedref      = $cfg->{ped};
    my $male_code   = $cfg->{male_code};
    my $female_code = $cfg->{female_code};
    my $extended    = $cfg->{extended};

    my ( %wrong_sire, %wrong_dam );
    ANIMAL:
    for my $animal ( keys %{$pedref} ) {
        next ANIMAL if !defined $animal;
        next ANIMAL if $animal == 1;    # base animal
        next ANIMAL if $animal == 2;    # base animal

        SIRE: {
            my $sire = $pedref->{$animal}[0];
            last SIRE if !$sire;
            last SIRE if $sire eq 1;
            my $sire_sex = $pedref->{$sire}[3];
            last SIRE if !defined $sire_sex;
            $wrong_sire{$sire} = 1 if $sire_sex != $male_code;
        }

        DAM: {
            my $dam = $pedref->{$animal}[1];
            last DAM if !$dam;
            last DAM if $dam eq 1;
            my $dam_sex = $pedref->{$dam}[3];
            last DAM if !defined $dam_sex;
            $wrong_dam{$dam} = 1 if $dam_sex != $female_code;
        }
    }

    # notification:
    my $max_wrong_animals = 50;
    my $no_wrong_sires = scalar keys %wrong_sire;
    if ( $no_wrong_sires ) {
        my @concats;
        my $s = 0;
        WRONGSIRE:
        for my $sire ( sort { $a <=> $b } keys %wrong_sire ) {
            if ( ++$s >= $max_wrong_animals ) {
                push @concats,
                    sprintf '\\\\Stopped printing after %s wrong animals',
                    $max_wrong_animals;
                last WRONGSIRE;
            }
            my $dec_sire = decode_animal( $sire, $cfg );
            my $ext_sire = MaskForLatex($dec_sire);
            if ($extended) {
                push @concats, sprintf '%s (int: %s)', $ext_sire, $sire;
            }
            else {
                push @concats, sprintf '%s', $ext_sire;
            }
        }
        push @{ $cfg->{err_mesgs} }, sprintf "Found %u female sires:\\\\%s \\\\\n",
            $no_wrong_sires, join( ', ', @concats );
    }
    my $no_wrong_dams = scalar keys %wrong_dam;
    if ( $no_wrong_dams ) {
        my @concats;
        my $d = 0;
        WRONGDAM:
        for my $dam ( sort { $a <=> $b } keys %wrong_dam ) {
            if ( ++$d >= $max_wrong_animals ) {
                push @concats,
                    sprintf '\\\\Stopped printing after %s wrong animals',
                    $max_wrong_animals;
                last WRONGDAM;
            }
            my $dec_dam = decode_animal( $dam, $cfg );
            my $ext_dam = MaskForLatex($dec_dam);
            if ($extended) {
                push @concats, sprintf '%s (int: %s)', $ext_dam, $dam;
            }
            else {
                push @concats, sprintf '%s', $ext_dam;
            }
        }
        push @{ $cfg->{err_mesgs} }, sprintf "Found %u male dams:\\\\%s \\\\\n",
            $no_wrong_dams, join( ', ', @concats );
    }
}
##############################################################################
sub test_dates {
    my $cfg      = shift;
    my $pedref   = $cfg->{ped};
    my $extended = $cfg->{extended};
    my $delete   = $cfg->{delete} || 0;

    my %wrong_bdate;
    ANIMAL:
    for my $animal ( keys %{$pedref} ) {
        my $bdate = $pedref->{$animal}[4];
        next ANIMAL if !$bdate;
        my ( $year, $month, $day ) = split /-/, $bdate;
        if ( check_date( $year, $month, $day ) ) {
            SIRE: {
                my $sire = $pedref->{$animal}[0];
                last SIRE if !$sire;
                last SIRE if $sire eq 1;
                my $sire_bdate = $pedref->{$sire}[4];
                last SIRE if !defined $sire_bdate;
                my ( $s_year, $s_month, $s_day ) = split /-/, $sire_bdate;
                if ( check_date( $s_year, $s_month, $s_day ) ) {
                    my $ddiff =
                        Delta_Days( $s_year, $s_month, $s_day, $year, $month,
                        $day );
                    if ( $ddiff <= 0 ) {
                        ${ $wrong_bdate{$animal} }[0] = $ddiff;
                        ${ $wrong_bdate{$animal} }[1] = $sire;
                    }
                }
                else {
                    $wrong_bdate{$sire} = "wrong date: $sire_bdate";
                }
            }
            DAM: {
                my $dam = $pedref->{$animal}[1];
                last DAM if !$dam;
                last DAM if $dam eq 2;
                my $dam_bdate = $pedref->{$dam}[4];
                last DAM if !defined $dam_bdate;
                my ( $d_year, $d_month, $d_day ) = split /-/, $dam_bdate;
                if ( check_date( $d_year, $d_month, $d_day ) ) {
                    my $ddiff =
                        Delta_Days( $d_year, $d_month, $d_day, $year, $month,
                        $day );
                    if ( $ddiff <= 0 ) {
                        ${ $wrong_bdate{$animal} }[0] = $ddiff;
                        ${ $wrong_bdate{$animal} }[1] = $dam;
                    }
                }
                else {
                    $wrong_bdate{$dam} = "wrong date: $dam_bdate";
                }
            }
        }
        else {
            $wrong_bdate{$animal} = "wrong date: $bdate";
        }
    }

    # notification:
    if ( scalar keys %wrong_bdate ) {
        my $max    = 20;
        my @texlines;
        my $addmsg = " (max. $max displayed)"
            if $max < scalar keys %wrong_bdate;
        push @texlines,
            sprintf "%u wrong birthdates animal -> sire/dam%s:",
            scalar keys %wrong_bdate, ( $addmsg || '' );
        push @texlines, '\begin{verbatim}';

        my @clean_birthdates;
        for my $animal ( sort { $a <=> $b } keys %wrong_bdate ) {
            my $parent = ${ $wrong_bdate{$animal} }[1];
            # delete erroneous birthdates both at animal and parent:
            $pedref->{$animal}[4] = '';
            $pedref->{$parent}[4] = '';

            # notification:
            if ( $max-- > 0 ) {
                my $datediff = abs( ${ $wrong_bdate{$animal} }[0] );
                my $mess;
                if ($extended) {
                    $mess = sprintf
                        "animal %s (int: %s): born %5d days before its dam/sire %s (int: %s)",
                        decode_animal( $animal, $cfg ), $animal, $datediff,
                        decode_animal( $parent, $cfg ), $parent;
                }
                else {
                    $mess = sprintf
                        "animal %s: born %5d days before its dam/sire %s",
                        decode_animal( $animal, $cfg ), $datediff,
                        decode_animal( $parent, $cfg );
                }
                push @texlines, $mess;
            }
            push @clean_birthdates, $animal, $parent;
        }
        push @texlines, '\end{verbatim} ';

        # Deletion of wrong birthdates stopped (at least in database):
        if ($delete) {
            my $cleaned_no = db_clean_birthdates( \@clean_birthdates, $cfg );
            push @texlines,
                "Incorrect birthdates of $cleaned_no records cleaned successfully in Database"
                if $cleaned_no;
        }
        push @{ $cfg->{err_mesgs} }, join( "\n", @texlines );
    }
}
##############################################################################
# clean faulty birthdates in the database:
# input:  array reference of the db_animal values
# output: number of effected rows
sub db_clean_birthdates {
    my ( $animals_ref, $cfg ) = @_;

    my $rows_changed;
    my $dbh = $cfg->{apiis}->DataBase->dbh;
    local $dbh->{AutoCommit} = 0;
    local $dbh->{RaiseError};
    eval {
        my $sth = $dbh->prepare(
            "UPDATE animal SET birth_dt = NULL WHERE db_animal = ?");
        $sth->bind_param_array( 1, $animals_ref );
        $rows_changed =
            $sth->execute_array( { ArrayTupleStatus => \my @tuple_status } );
        if ($rows_changed) {
            print "Database changes successful ($rows_changed)\n";
        }
        else {
            print STDERR "Database error:\n";
            for my $tuple ( 0 .. @{$animals_ref} - 1 ) {
                my $status = $tuple_status[$tuple];
                $status = [ 0, "Skipped" ] unless defined $status;
                next unless ref $status;
                printf STDERR "Failed to update (%s): %s\n",
                    $animals_ref->[$tuple], $status->[1];
            }
        }

    };
    if ($@) {
        warn $@;    # print the error
        $dbh->rollback;
        return;
    }
    else {
        $dbh->commit;
        return $rows_changed;
    }
}
##############################################################################
sub decode_animal {
    my ( $db_animal, $cfg ) = @_;
    our $apiis   = $cfg->{apiis};
    my $extended = $cfg->{extended};

    #--muelf 
    if (exists $cfg->{'pedigreetable'}) {
        return $db_animal;
    }
    #--endmuelf

    my $record = Apiis::DataBase::Record->new( tablename => 'transfer', );

    $record->column('db_animal')->intdata($db_animal);
    $record->decode_record;
    $record->check_status;
    if ($extended) {
        return join( '-', $record->column('db_animal')->extdata );
    }
    else {
        # return only ext_animal and skip the unit parts (???):
        return ${ $record->column('db_animal')->extdata }[2];
    }
    return;
}
##############################################################################
sub handle_errors {
    my $cfg = shift;
    my $max_err = $cfg->{'max_errors'} + 10;

    if ( @{ $cfg->{err_mesgs} } or @{ $cfg->{err_mesgs_die} } ) {
        my $outfile = $cfg->{texfile} || $cfg->{listfile};
        if ($outfile) {
            if ( @{ $cfg->{err_mesgs} } ) {
                my $curr_err;
                my @out_arr;
                ERR1:
                for my $msg ( @{ $cfg->{err_mesgs} } ) {
                    $curr_err++;
                    push @out_arr, $msg;
                    if ( $curr_err >= $max_err ) {
                        my $stop_msg =
                            sprintf 'Too many errors (%u). Stopped printing.',
                            scalar @{ $cfg->{err_mesgs} };
                        push @out_arr, $stop_msg;
                        last ERR1;
                    }
                }
                my $msg = "ERROR:\\\\ ";
                print_tex_item( $msg . join( '\\\\', @out_arr ), $outfile );
                $cfg->{err_mesgs} = [];    # delete after printing, keep arr_ref!
            }
            if ( @{ $cfg->{err_mesgs_die} } ) {
                my $curr_err;
                my @out_arr;
                ERR2:
                for my $msg ( @{ $cfg->{err_mesgs_die} } ) {
                    $curr_err++;
                    push @out_arr, $msg;
                    if ( $curr_err >= $max_err ) {
                        my $stop_msg =
                            sprintf 'Too many errors (%u). Stopped printing',
                            scalar @{ $cfg->{err_mesgs_die} };
                        push @out_arr, $stop_msg;
                        last ERR2;
                    }
                }
                my $msg = 'FATAL ERROR:\\\\ ';
                print_tex_item( $msg . join( '\\\\', @out_arr ), $outfile );
                $cfg->{err_stat_die}  = 255;
                $cfg->{err_mesgs_die} = [];    # delete after printing, keep arr_ref!
            }
        }
        else {
            # send mail to notify the user:
            my $email   = $cfg->{email}   || 'unknown';
            my $breed   = $cfg->{breed}   || 'unknown';
            my $project = $cfg->{project} || 'unknown';
            my @all_msgs;
            push @all_msgs, @{ $cfg->{err_mesgs} }, @{ $cfg->{err_mesgs_die} };
            if ($email) {
                # send mail to user:
                my %mail_user = (
                    To      => $email,
                    From    => 'popreport@popreport.tzv.fal.de',
                    Subject => "popreport: Your input data for breed $breed",
                    Message => join( "\n", @all_msgs ),
                );
                # sendmail(%mail_user) or die $Mail::Sendmail::error;
            }
            # send mail to admin:
            my %mail_admin = (
                To   => 'popmaster@tzv.fal.de',
                From => 'popreport@popreport.tzv.fal.de',
                Subject =>
                    "popreport: Errors in project $project from: $email, breed: $breed",
                Message => join( "\n", @all_msgs ),
            );
            sendmail(%mail_admin) or die $Mail::Sendmail::error;
        }
        exit ($cfg->{err_stat_die} || 1) if $cfg->{err_stat_die};
        die if @{ $cfg->{err_mesgs_die} };
    }
}
##############################################################################

1;

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>

=cut
