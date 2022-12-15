##############################################################################
# $Id: Label.pm,v 1.6 2010-10-24 13:15:25 ulm Exp $
# Handling Labels
##############################################################################
package Apiis::Form::HTML::Label;
$VERSION = '$Revision $';
use warnings;
use strict;
use Data::Dumper;

=head1 NAME

Apiis::Form::HTML::Label

=head1 DESCRIPTION

create a html label. The return value is valid html code.

=head1 METHODS

=head2 _label

=cut


sub _label {
    my ( $self, %args ) = @_;
    my $fieldname = $args{elementname};
   
    my $label='';
    $label=$self->GetValue( $fieldname, 'Content') if ($self->GetValue( $fieldname, 'Content'));

    #-- if translation
    if ($label=~/^__\('(.*)'\)/) {
    
        #-- translate
        $label=main::__($1);
    }

    return '<div id="'.$fieldname.'">'.$label.'</div>';
}

1;
