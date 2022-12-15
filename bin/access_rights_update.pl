#!/usr/bin/env perl
##############################################################################
# $Id: access_rights_update.pl,v 1.5 2021/05/01 19:42:51 ulf Exp $
##############################################################################

=head1 NAME

access_rights_update.pl

=head1 SYNOPSIS

 how to us your module

=head1 DESCRIPTION

 long description of your module

=head1 SEE ALSO

 need to know things before somebody uses your program
use strict;

=head1 METHODS

=cut

##############################################################################
BEGIN {
    use Env qw( APIIS_HOME );
    die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
    push @INC, "$APIIS_HOME/lib";
}

use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.5 $' );
our $apiis;
use strict;
use warnings;
use Carp;

use Term::ReadKey;
use Digest::MD5 qw(md5_base64);
use Apiis::DataBase::User;
use Apiis::Auth::AR_Common;
use Apiis::Auth::AR_Init;

##############################################################################

use vars qw( $opt_p $opt_d $opt_w );
use Getopt::Std;
getopts( 'p:w:d:' );

my $project_name = $opt_p;
my $loginname    = $opt_d;
my $passwd       = $opt_w;

$apiis->APIIS_LOCAL( $apiis->project( $project_name ) );
my $APIIS_LOCAL = $apiis->APIIS_LOCAL;
my $dummy = Apiis::DataBase::User->new( id => ( $apiis->os_user || 'nobody' ),
                                        password => 'nopassword', );
$apiis->join_model( $project_name, userobj => $dummy, database => 0 );
$apiis->DataBase->connect;
$apiis->check_status;
my $user = $apiis->os_user;
#################################################################################

#################################################################################
print __( "ADMIN USER AUTHENTICATION:\n" );
if ( !$loginname or !$passwd ) {
    my $not_ok = 1;
    while ( $not_ok ) {
        print __( "Please enter your login name: " );
        chomp( $loginname = <> );
        print __( "... and your password: " );
        ReadMode 2;
        chomp( $passwd = <> );
        ReadMode 0;
        print "\n";
        $not_ok = 0 if $loginname and $passwd;
    }
}

my $user_obj = Apiis::DataBase::User->new( id => $loginname );
$user_obj->password( $passwd );

#$apiis->DataBase->connect;
$apiis->DataBase->connect( user => 'application', userobj => $user_obj );
$apiis->check_status;
$apiis->join_auth( $loginname, 'DBT' );
#################################################################################

my @sqls;
$sqls[ 0 ]  = "DELETE FROM ar_dbtdescriptors";
$sqls[ 1 ]  = "DELETE FROM ar_dbtpolicies";
$sqls[ 2 ]  = "DELETE FROM ar_dbttables";
$sqls[ 3 ]  = "DELETE FROM ar_role_dbtpolicies";
$sqls[ 4 ]  = "DELETE FROM ar_roles";
$sqls[ 5 ]  = "DELETE FROM ar_role_stpolicies";
$sqls[ 6 ]  = "DELETE FROM ar_user_roles";
$sqls[ 7 ]  = "DELETE FROM ar_users";
$sqls[ 8 ]  = "DELETE FROM ar_users_data";
$sqls[ 9 ]  = "DELETE FROM ar_stpolicies";
$sqls[ 10 ] = "DROP schema $loginname CASCADE";

foreach my $sql ( @sqls ) {
    my $sql_ref = $apiis->DataBase->sys_sql( $sql );
    if ( $sql_ref->status ) {
        $apiis->errors( $sql_ref->errors );

        # $apiis->status(1);
    }
}

my $user_language = $apiis->language;
my $user_marker   = $apiis->node_name;
my $administrator = "db_manager";
my @admin_groups  = qw (administrator_scripts administrator_dbt arm_admin);
access_rights( $loginname,      \@admin_groups,
               'Administrator', 'Administrator',
               $user_language,  $user_marker,
               $passwd
);

#create_other_accounts();

$apiis->check_status;
if ( $apiis->status ) {
    $apiis->DataBase->dbh->rollback;
}
else {
    $apiis->DataBase->dbh->commit;
}

### parameters ############################################################

sub parameters {
    use vars qw( $opt_p $opt_h );
    my $project;

    # allowed parameters:
    use Getopt::Std;
    getopts( 'p:h' );    # option -h  => Help

    if ( $opt_h ) {
        print "\nNAME";
        print
            "\n              access_rights_update.pl  - updates access rights.";
        print "\nSYNOPIS";
        print "\n              access_rights_update.pl  [OPTIONS]";
        print "\nDESCRIPTION";
        print "\n            ";
        print "\nOPTIONS";
        print "\n              -p [project name]    - sets project name";
        print "\n              -h                - prints this help\n";
        print "\n";
        die();
    }
    if ( $opt_p ) {
        $project = $opt_p;
    }
    else {
        print "\n!!!! Missing parameter !!!!";
        print "\nTry help with -h option\n";
        die();
    }
    return $project;
}
#########################################################################

##############################################################################
__END__

=head1 AUTHOR

 Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut
