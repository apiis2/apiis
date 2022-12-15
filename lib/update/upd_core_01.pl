#!/usr/bin/env perl
##############################################################################
# $Id: upd_core_01.pl,v 1.1 2006/06/26 12:55:45 heli Exp $
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
our $apiis;

use XML::LibXML;
use File::Copy;
my $update_id = 'upd_core_01';

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

# ok, now let's start:
my $model_file = $apiis->Model->path . $apiis->Model->fullname;
print "*** Going to change model file: $model_file\n";

# parse the model file:
my $xml_ref;
eval {
    my $parser = XML::LibXML->new();
    $parser->load_ext_dtd(1);
    $xml_ref = $parser->parse_file($model_file);
    $xml_ref->validate();
};
if ($@) {
    printf "*** Error reading/parsing XML-file: %s\n", $model_file;
    die $@ . "\n";
}

# add the element:
my $rv = read_node( $xml_ref->documentElement );

# return values of read_node:
#    0 - xml tree changed, everything ok
#    1 - xml tree unchanged, everything ok
#    2 - errors
if ( $rv >= 1 ){
    die "*** Left everything unchanged.\n";
}

# validate again agains dtd:
eval { $xml_ref->validate() };
if ($@){
    print "Changes produced no valid XML. This should not happen.\n";
    print scalar $@;
    die "*** Left everything unchanged.\n";
}

# reorder column attributes:
xml_pretty_print( $xml_ref->documentElement );

# save changes:
# ok, going to write, first create a backup:
my $backup = $model_file . '-before_' . $update_id;
printf "*** File     %s\n    saved to %s\n    before writing any changes.\n",
    $model_file, $backup;
copy( $model_file, $backup ) or die "Copy failed: $!";

# overwrite old model file in place (see man XML::LibXML::Document):
eval { $xml_ref->toFile( $model_file, 1 ) };
die $@ if $@;
printf "*** File %s changed successfully.\n", $model_file;

##############################################################################
# return values:
#    0 - xml tree changed, everything ok
#    1 - xml tree unchanged, everything ok
#    2 - errors
sub read_node {
    my $node      = shift;
    my $nodename  = $node->getAttribute('name');
    my $nodetype  = $node->nodeName;
    my $rv = 0;

    if ( $nodetype eq 'table' ) {
        if ( $nodename eq 'transfer' ) {
            my $has_id_set = 0;
            my $table_node;
            CHILD:
            for my $childnode ( $node->childNodes ) {
                next CHILD if ref $childnode eq 'XML::LibXML::Text';
                next CHILD if ref $childnode eq 'XML::LibXML::Comment';
                my $childtype = $childnode->nodeName;
                if ( $childtype eq 'TABLE' ) {
                    $table_node = $childnode;
                    next CHILD;
                }

                # columns:
                if ( lc $childtype eq 'column' ) {
                    my @attributelist = $childnode->attributes();
                    for my $attr (@attributelist) {
                        my $attr_val  = $attr->value;
                        my $attr_name = $attr->name;
                        if ( $attr_name eq 'name' and $attr_val eq 'id_set' ) {
                            $has_id_set = 1;
                            last CHILD;
                        }
                    }
                }
            }

            if ($has_id_set) {
                print "*** Model file already updated, skipping changes!\n";
                $rv = 1;
            }
            else {
                eval {
                    # unbind node TABLE from tree to add it later:
                    $table_node->unbindNode();
                    print "*** Going to add column id_set to table transfer.\n";

                    my $new_id_set = XML::LibXML::Element->new('column');
                    $new_id_set->setAttribute( 'name',     'id_set' );
                    $new_id_set->setAttribute( 'DATATYPE',    'SMALLINT' );
                    $new_id_set->setAttribute( 'LENGTH',      '10' );
                    $new_id_set->setAttribute( 'struct_type', 'mandatory' );
                    $new_id_set->setAttribute( 'CHECK',
                        'ForeignKey codes db_code class=ID_SET' );
                    $new_id_set->setAttribute( 'DESCRIPTION',
                        'Set of categories for the numbering scheme' );
                    $node->appendChild($new_id_set);

                    # reappend node TABLE to make dtd happy:
                    $node->appendText( "\n    " );
                    $node->appendChild($table_node);
                };
                if ( $@ ){
                    printf "    %s", scalar $@;
                    $rv = 2;
                }
            }
        }
    }
    else {
        L_TABLE:
        for my $childnode ( $node->childNodes ) {
            next if ref $childnode eq 'XML::LibXML::Text';
            next if ref $childnode eq 'XML::LibXML::Comment';
            $rv = read_node($childnode);
            last L_TABLE if $rv; # end loop if errors
        }
    }
    return $rv;
}

##############################################################################
# Currently only pretty prints the Column element of the model file.
# Could be a starting point for more pretty printing and also for mkxmlforms.
# input: root node of the document.
sub xml_pretty_print {
    my $root     = shift;
    my $nodetype = $root->nodeName;
    my $blank = q{ };
    my $nl = "\n";

    # model file:
    if ( $nodetype eq 'model' ) {
        my @tablenodes = $root->findnodes('/model/table');
        TABLE:
        for my $table (@tablenodes) {
            my @col_attrs = (
                qw/ name DATATYPE CHECK MODIFY DESCRIPTION
                    DEFAULT LENGTH CHECK1 CHECK2 CHECK3 CHECK4
                    CHECK5 struct_type form_type ar_check /
            );

            CHILD:
            for my $childnode ( $table->childNodes ) {
                if ( ref $childnode eq 'XML::LibXML::Text' ){
                    $childnode->setData( $nl . $blank x 4 ); # replaces
                    next CHILD;
                }
                next CHILD if ref $childnode eq 'XML::LibXML::Comment';

                my $childtype = $childnode->nodeName;
                # columns:
                if ( lc $childtype eq 'column' ) {
                    my %attr_of;
                    for my $attr_name (@col_attrs) {
                        if ( $childnode->hasAttribute($attr_name) ) {
                            my $attr_val = $childnode->getAttribute($attr_name);
                            if ( defined $attr_val and $attr_val ne '' ) {
                                $attr_of{$attr_name} = $attr_val;
                            }
                        }
                    }

                    # ... and add them in a defined order:
                    my $newnode = XML::LibXML::Element->new('column');
                    for my $attr_name (@col_attrs) {
                        if ( exists $attr_of{$attr_name} ) {
                            eval {
                                $newnode->setAttribute( $attr_name,
                                    $attr_of{$attr_name} );
                            };
                            print $@ if $@;
                        }
                    }
                    $childnode->replaceNode($newnode);
                }
            }
        } # end label TABLE
    } # end node model
}
##############################################################################

=pod

=head1 NAME

upd_core_01.pl

=head1 SYNOPSIS

upd_core_01.pl -p <project> [Options]

=head1 OPTIONS

 -p | --project <project>  defines the project to update the model file (r)

 -u | --user  <user>       provide username <user> to connect to project (o)
 -P | --password <passwd>  provide password <passwd> to connect to project (o)

 -h | -? | --help          short help (o)
 -m | --man                detailed man page (o)
 -v | --version            current version of upd_core_01.pl (o)

                           (r) - required, (o) - optional

=head1 DESCRIPTION

B<upd_core_01.pl> updates the structure of the project's model file

The option B<-p <project>> is the only required one. If you don't define
B<-u user> and B<-P password>, you get prompted for them.

B<upd_core_01.pl> adds the column B<id_set> to table transfer. This column has a
ForeignKey definition to table codes. It contains the set of ID categories
(german: Nummernkreis), the external triplet representation of db_animal could
belong to.

These are the XML definitions, added into the model file:

   <column name="id_set"
           DATATYPE="SMALLINT"
           CHECK="ForeignKey codes db_code class=ID_SET"
           DESCRIPTION="Set of categories for the numbering scheme"
           LENGTH="10"
           struct_type="mandatory"
   />

B<upd_core_01.pl> recognizes, if you already applied the changes to the model
file. If the column transfer.id_set already exists, processing stops and the
file will be left unchanged.

In case of changes, your model file is copied to a backupfile with the
extension '-before_upd_core_01' appended, before any changes are done. This
file is located in the same directory as your model file.

The column elements of all tables are reordered by some pretty printing. The
attributes are printed out in the same order:
   name DATATYPE CHECK MODIFY DESCRIPTION
   DEFAULT LENGTH CHECK1 CHECK2 CHECK3 CHECK4
   CHECK5 struct_type form_type ar_check


=head1 EXAMPLES

 upd_core_01.pl -p breedprg
 upd_core_01.pl -p breedprg -u my_name -P 'my secret'

=head1 BUGS

If you have included external xml files, these files are read and inlined into
the model file. If you don't like this you maybe have to re-extract them again
manually.

=head1 VERSION

$Revision: 1.1 $

=head1 AUTHOR

 Helmut Lichtenberg <heli@tzv.fal.de>

=cut

