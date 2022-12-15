#!/usr/bin/env perl
##############################################################################
# $Id: ins_codes_01.pl,v 1.1 2006-06-27 07:26:59 heli Exp $
# ins_codes_01.pl inserts the values for class='ID_SET' into table codes.
# Please configure to your needs between the tags 'configuration_start' and
# 'configuration_end'.
##############################################################################

BEGIN {
    use Env qw( APIIS_HOME );
    die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
    push @INC, "$APIIS_HOME/lib";
}

use strict;
use warnings;
use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.1 $' );

###############################################################
##### configuration_start #####################################

# these are your ID sets (german: Nummernkreise):
my @ext_codes = ( qw/ HB LBN LMN / );

# short name:
my %short_name = (
    HB  => 'HB-Nr',
    LBN => 'Lebens-Nr',
    LMN => 'Lamm-Nr',
);

# long name:
my %long_name = (
    HB  => 'Herdbuchnummer',
    LBN => 'Lebensnummer',
    LMN => 'Lammnummer',
);

# description:
my %description = (
    HB  => 'Dies ist die von den Verbänden vergebene Herdbuchnummer',
    LBN => 'Dies ist die von den Betrieben vergebene Transpondernummer',
    LMN => 'Dies ist die von den Betrieben vergebene Lammnummer',
);

# set to 1 if your configuration is ready:
my $configuration_done = 0;

##### configuration_end  ######################################
###############################################################

# handle command-line options:
my %args;
my $args_ref = \%args;
use Getopt::Long;
Getopt::Long::Configure ("bundling"); # allow argument bundling
use Pod::Usage;

# allowed parameters:
GetOptions( $args_ref,
    'help|h|?',
    'man|m',
    'version|v',
    'project|p=s',
    'user|u=s',
    'password|P=s',
) or pod2usage( -verbose => 1 );

# short help, longer man page, and version:
pod2usage( -verbose => 1 ) if $args_ref->{'help'};
pod2usage( -verbose => 2 ) if $args_ref->{'man'};

if ( $args_ref->{version} ) {
    die sprintf "%s: %s\n", $apiis->programname, $apiis->version;
}

# model file:
my $project = $args_ref->{'project'};
if ( !$project ) {
    printf "%s!\n", __( 'No [_1] given', 'project' );
    pod2usage( -verbose => 1 );
}

# connect to project:
if ( $args_ref->{user} and $args_ref->{password} ) {
    require Apiis::DataBase::User;
    my $thisobj = Apiis::DataBase::User->new(
        id       => $args_ref->{user},
        password => $args_ref->{password},
    );
    $thisobj->check_status;
    $apiis->join_model( $project, userobj => $thisobj );
}
$apiis->join_model($project) if !$apiis->exists_model;
$apiis->check_status( die => 'ERR' );

# ok, we have correct parameters. Do we have configuration?:
if ( !$configuration_done ) {
    print "*** You have to do some configuration.\n";
    die "*** Please edit file $0\n"
        . "*** between 'configuration_start' and 'configuration_end'!\n";
}

# please don't change this as the ForeignKey in transfer points to it!
my $class = 'ID_SET';

my $record = Apiis::DataBase::Record->new( tablename => 'codes', );
$record->check_status;

# check if sequence is set by PreInsert trigger:
my $sets_seq;
for my $pit ( @{ $record->preinsert_triggers } ) {
    my ( $name, $col, $seq ) = split /\s+/, $pit;
    $sets_seq = 1 if $name eq 'SetColumn' and $col eq 'db_code';
}

# if not, provide sequence directly:
my $sequence;
if ( !$sets_seq ) {
    my $has_seq;
    for my $seq ( $record->sequences ) {
        if ( $seq =~ /db_code/ ) {
            $has_seq  = 1;
            $sequence = $seq;
        }
    }
    die "No sequence for db_code available. Failed.\n" if !$has_seq;
}

my $ok;
EXT_CODE:
for my $ext_code (@ext_codes) {
    my $codes = Apiis::DataBase::Record->new( tablename => 'codes', );
    $codes->check_status;
    $codes->column('class')->extdata($class);
    $codes->column('ext_code')->extdata($ext_code);
    $codes->column('short_name')->extdata( $short_name{$ext_code} );
    $codes->column('long_name')->extdata( $long_name{$ext_code} );
    $codes->column('description')->extdata( $description{$ext_code} );
    $codes->column('opening_dt')->extdata( $apiis->now );
    if ( !$sets_seq ) {
        my $nextval = $apiis->DataBase->seq_next_val($sequence);
        $codes->column('db_code')->intdata($nextval);
        $codes->column('db_code')->encoded(1);
    }
    $codes->insert;
    if ( $codes->status ) {
        $codes->check_status;
        $ok = 0;
        last EXT_CODE;
    }
    $ok++;
}
if ( $ok ){
    $apiis->DataBase->commit;
    $apiis->check_status;
    printf "%s records inserted.\n", $ok;
}
else {
    print "Insert failed!\n";
}
##############################################################################

=pod

=head1 NAME

ins_codes_01.pl

=head1 SYNOPSIS

ins_codes_01.pl -p <project> [Options]

=head1 OPTIONS

 -p | --project <project>  defines the project to update the model file (r)

 -u | --user  <user>       provide username <user> to connect to project (o)
 -P | --password <passwd>  provide password <passwd> to connect to project (o)

 -h | -? | --help          short help (o)
 -m | --man                detailed man page (o)
 -v | --version            current version of ins_codes_01.pl (o)

                           (r) - required, (o) - optional

=head1 DESCRIPTION

B<ins_codes_01.pl> inserts the values for class='ID_SET' into table codes.

The option B<-p <project>> is the only required one. If you don't define
B<-u user> and B<-P password>, you get prompted for them.

You have to configure the entries to your needs. Please edit this file
ins_codes_01.pl between the tags 'configuration_start' and
'configuration_end'.

=head1 EXAMPLES

 ins_codes_01.pl -p breedprg
 ins_codes_01.pl -p breedprg -u my_name -P 'my secret'

=head1 VERSION

$Revision: 1.1 $

=head1 AUTHOR

 Helmut Lichtenberg <heli@tzv.fal.de>

=cut

