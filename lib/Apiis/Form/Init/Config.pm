##############################################################################
# $Id: Config.pm,v 1.11 2022/02/25 22:13:14 ulf Exp $
##############################################################################
package Apiis::Form::Init::Config;
##############################################################################

use strict;
use warnings;
our $VERSION = '$Revision: 1.11 $';
use Apiis;   # to import $apiis
use base 'Apiis::Init';
use XML::LibXML;
use File::Basename;

##############################################################################

=head2 _parse_xml (internal)

B<_parse_xml> opens and parses the xml file.
The dtd is included and all attributes of the dtd with its defaults are added to
the configuration of the xml file.

=cut

sub _parse_xml {
    my ( $self, $argsref ) = @_;
    my $xml_ref;

    # link form.dtd:
    my @suffixes = qw{ .frm .pfrm };
    my ( $base, $path, $ext ) = fileparse( $argsref->{'xmlfile'}, @suffixes );
    # Note: not portable! (what about Win32::Symlink?)
    if ( !-f $path . 'form.dtd' ) {
        eval {
            symlink( $apiis->APIIS_HOME . '/etc/form.dtd', $path . 'form.dtd' );
        };
        if ($@) {
            $self->status(1);
            my $msg = $@;
            $self->errors(
                Apiis::Errors->new(
                    type      => 'OS',
                    severity  => 'ERR',
                    from      => __PACKAGE__,
                    msg_long  => $msg,
                    msg_short => sprintf( "Can't link form.dtd to '%s'",
                        $path . 'form.dtd' ),
                )
            );
        }
    }

    eval {
        my $parser = XML::LibXML->new();
        $parser->load_ext_dtd(1);
        $parser->complete_attributes(1);
        $xml_ref = $parser->parse_file( $argsref->{'xmlfile'} );
        $xml_ref->validate();
        $xml_ref->indexElements();    # speedup ?
    };
    if ($@) {
        $self->status(1);
        my $msg = $@;
        $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'CRIT',
                from      => __PACKAGE__,
                msg_short => sprintf( "Error reading/parsing XML-file '%s'",
                    $argsref->{'xmlfile'} ),
                msg_long => $msg,
            )
        );
    }
    return $xml_ref;
}
##############################################################################

=head2 _read_node (internal)

B<_read_node> is an auxiliary method for B<_parse_xml>. It starts reading the
root node of the xml file and steps on recursively through the whole tree.
It reorders the parsed xml to our needs. Here, the main data structures are
created.

=cut

sub _read_node {
    my ( $self, %args ) = @_;
    my $node      = $args{'node'};
    my $blockname = $args{'blockname'};
    my $nodename  = $node->getAttribute('Name');
    my $nodetype  = lc $node->nodeName;            # always in lower case!

    if ( defined $nodename ) {
        # write attribute name/value pairs:
        $self->{'_flat'}{$nodename}{ $_->name } = $_->value
            for $node->attributes();

        # accumulate the node types in lists:
        push @{ $self->{ '_' . $nodetype . '_list' } }, $nodename;
        if ( $self->is_misc_blockelement($nodetype) ) {
            push @{ $self->{'_misc_blockelement_list'} }, $nodename;
        }

        # store block information in subsequent elements:
        if ( defined $blockname ) {
            $self->{'_flat'}{$nodename}{'_my_block'}      = $blockname;
            $self->{'_flat'}{$nodename}{'_my_datasource'} =
                $self->{'_flat'}{$blockname}{'DataSource'};
        }
        else {
            if ( $nodetype eq 'block' ) {
                $blockname = $nodename;
            }
            else {
                $blockname='';
            }
        }

        # add some general structures to all nodes:
        $self->{'_flat'}{$nodename}{'_events'} = undef;
    }

    for my $childnode ( $node->childNodes ) {
        next if ref $childnode eq 'XML::LibXML::Text';
        next if ref $childnode eq 'XML::LibXML::Comment';
        my $childnodename = $childnode->getAttribute('Name');
        if ( defined $childnodename ) {
            # who is my ancestor?:
            $self->{'_flat'}{$childnodename}{'_parent'} = $nodename;

            # accumulate the childnode names under this nodename:
            my $childnodetype = $childnode->nodeName;
            push @{ $self->{'_flat'}{$nodename}
                    { '_' . lc $childnodetype . '_list' } }, $childnodename;

            # collect also misc non-Field elements:
            if ( $self->is_misc_blockelement($childnodetype) ) {
                push @{ $self->{'_flat'}{$nodename}
                        {'_misc_blockelement_list'} }, $childnodename;
            }

            # this is a real subelement -- read recursively:
            $self->Apiis::Form::Init::Config::_read_node(
                node      => $childnode,
                blockname => $blockname
            );

            # set Type to childnotetype unless already done before:
            $self->{'_flat'}{$childnodename}{'Type'} = $childnodetype
                unless $self->{'_flat'}{$childnodename}{'Type'};
        }
        else {
            # flatten these pseudo subelements into the main node:
            for my $child_attr ( $childnode->attributes() ) {
                $self->{'_flat'}{$nodename}{ $child_attr->name } =
                    $child_attr->value;
            }

            # also pseudo childnodes can have subelements (like Button):
            # ToDo: this is ugly hardcoded and must be rewritten. Maybe read
            # one element after the other via a sub and treat each separately.
            GRANDCHILD:
            for my $grandchildnode ( $childnode->childNodes ) {
                next GRANDCHILD if ref $grandchildnode eq 'XML::LibXML::Text';
                next GRANDCHILD
                    if ref $grandchildnode eq 'XML::LibXML::Comment';
                my $grandchildnodename =
                    $grandchildnode->getAttribute('Name');
                if ( defined $grandchildnodename ) {
                    # who is my ancestor? Skip pseudo element!:
                    $self->{'_flat'}{$grandchildnodename}{'_parent'} =
                        $nodename;

                    # accumulate the grandchildnode names under this nodename:
                    my $grandchildnodetype = $grandchildnode->nodeName;
                    push @{ $self->{'_flat'}{$nodename}
                            { '_' . lc $grandchildnodetype . '_list' } },
                        $grandchildnodename;

                    # collect also misc non-Field elements:
                    if ( $self->is_misc_blockelement($grandchildnodetype) ) {
                        push @{ $self->{'_flat'}{$nodename}
                                {'_misc_blockelement_list'} },
                            $grandchildnodename;
                    }

                    # this is a real subelement -- read recursively:
                    $self->Apiis::Form::Init::Config::_read_node(
                        node      => $grandchildnode,
                        blockname => $blockname,
                    );

                    # set Type to childnotetype unless already done before:
                    if ( !$self->{'_flat'}{$grandchildnodename}{'Type'} ) {
                        $self->{'_flat'}{$grandchildnodename}{'Type'} =
                            $grandchildnodetype;
                    }
                }
            }

            # some sub-elements could determine the Type of these elements:
            DETERMINE_NODETYPE: {
                my $childnodetype = $childnode->nodeName;

                # Field:
                if ( $nodetype eq 'field' ) {
                    if ( $self->exists_fieldtype($childnodetype) ) {
                        $self->{'_flat'}{$nodename}{'Type'} = $childnodetype;

                        # add reference to this Field into the corresponding
                        # Column of the DS:
                        my $ds_column = $node->getAttribute('DSColumn');
                        if ( defined $ds_column and $ds_column ne '' ) {
                            $self->{'_flat'}{$ds_column}{'_field'} =
                                $nodename;
                        }
                    }
                    last DETERMINE_NODETYPE;
                }

                # DataSource:
                if ( $nodetype eq 'datasource' ) {
                    if ( $self->exists_ds_type($childnodetype) ) {
                        $self->{'_flat'}{$nodename}{'Type'} = $childnodetype;
                    }
                    my $parent = $self->{'_flat'}{$nodename}{'_parent'};
                    $self->{'_flat'}{$parent}{'DataSource'} =
                        $self->{'_flat'}{$nodename}{'Name'};
                    last DETERMINE_NODETYPE;
                }

                # default: Type = $nodetype (e.g. label, image):
                $self->{'_flat'}{$nodename}{'Type'} = $nodetype;
            }  # end label DETERMINE_NODETYPE
        }
    }

    # nodetype specifics:
    NODETYPE: {
        # Block:
        if ( $nodetype eq 'block' ) {
            # collect all fields of this block:
            my $field_list = $self->GetValue( $nodename, '_field_list' );
            if ($field_list) {
                push @{ $self->{'_flat'}{$nodename}{'_all_field_list'} },
                    @$field_list;
            }

            # collect Master/Detail relations and flag blocks:
            my $masterblock = $self->GetValue( $nodename, 'MasterBlock' );
            if ( defined $masterblock ) {
                $self->master_detail(1);
                $self->{'_flat'}{$nodename}{'_is_detailblock'} = 1;
                push @{ $self->{'_flat'}{$masterblock}{'_detailblocks'} },
                    $nodename;
                $self->{'_flat'}{$masterblock}{'_is_masterblock'} = 1;
            }
            last NODETYPE;
        }

        # DataSource:
        if ( $nodetype eq 'datasource' ) {
            $self->{'_flat'}{$nodename}{__curr_index}    = 0;
            $self->{'_flat'}{$nodename}{__max_index}     = undef;
            $self->{'_flat'}{$nodename}{__query_records} = undef;
            last NODETYPE;
        }

        # Frame:
        if ( $nodetype eq 'frame' ) {
            $self->{'_flat'}{$nodename}{'_frame_top'} = undef;
            # add Fields of subelements to blocklist:
            my $frame_field_list_ref =
                $self->GetValue( $nodename, '_field_list' );
            if ($frame_field_list_ref) {
                last NODETYPE if !defined $blockname;
                # propagate fieldnames down to block:
                push @{ $self->{'_flat'}{$blockname}{'_all_field_list'} },
                    @$frame_field_list_ref;
            }
            last NODETYPE;
        }

        # Tabular:
        if ( $nodetype eq 'tabular' ) {
            $self->{'_flat'}{$nodename}{'_tabular_top'}      = undef;
            $self->{'_flat'}{$nodename}{'_tabular_template'} = undef;

            # add Fields of subelements to blocklist:
            last NODETYPE if !defined $blockname;
            my $tabular_field_list_ref =
                $self->GetValue( $nodename, '_field_list' ); #_all_field_list?
            last NODETYPE if !defined $tabular_field_list_ref;
            push @{ $self->{'_flat'}{$blockname}{'_all_field_list'} },
                @$tabular_field_list_ref;
            last NODETYPE;
        }

        # Field:
        if ( $nodetype eq 'field' ) {
            # check if we have a function to fill Default:
            my $default_type = $self->GetValue( $nodename, 'DefaultType' );
            if ( $default_type and (lc $default_type eq 'function' )) {
                my $func_def = $self->GetValue( $nodename, 'Default' );
                $func_def =~ s/^\s*//;
                my @func_args = split /\s+/, $func_def;
                my $func = shift @func_args;
                no strict 'refs';  ## no critic
                my $def_val = eval "$func(@func_args)"; ## no critic
                if ($@) {
                    $self->status(1);
                    my $msg = $@;
                    $self->errors(
                        Apiis::Errors->new(
                            type      => 'Code',
                            severity  => 'ERR',
                            from      => __PACKAGE__,
                            msg_long  => $msg,
                            msg_short => sprintf(
                                "Can't execute Default function '%s(%s)'",
                                $func, join( ' ', @func_args ) || '',
                            )
                        )
                    );
                }
                else {
                    $self->SetValue( $nodename, 'Default', $def_val );
                }
            }
            # predefine a scalar with the default and store a ref to it:
            my $var = $self->GetValue( $nodename, 'Default' );
            $self->{'_flat'}{$nodename}{'_data_ref'} =
                ${ $self->{'_flat'}{$nodename}{'_data_refs'} }[0] = \$var;

            # $self->{'_flat'}{$nodename}{'_data_ref'} = \$var;
            # push @{$self->{'_flat'}{$nodename}{'_data_refs'}},
            # \$self->{'_flat'}{$nodename}{'_data_ref'};
            # push @{$self->{'_flat'}{$nodename}{'_data_refs'}}, \$var;
            $self->{'_flat'}{$nodename}{'_widget_refs'} = undef;
            $self->{'_flat'}{$nodename}{'_displays_intdata'} = undef;
            if ( $self->{'_flat'}{$nodename}{'InternalData'} and (lc $self->{'_flat'}{$nodename}{'InternalData'} eq 'yes' )) {
                $self->{'_flat'}{$nodename}{'_displays_intdata'} = 1;
            }

            # has this Field its own DataSource for list values?:
            if ( $self->GetValue( $nodename, '_datasource_list' ) ) {
                $self->{'_flat'}{$nodename}{'_my_field_datasource'} =
                    ${ $self->GetValue( $nodename, '_datasource_list' ) }[0];
                $self->{'_flat'}{$nodename}{'_datasource_translate'} = undef;
            }
        }

        #-- mue  
        if (( $nodetype eq 'field' )  or ( $nodetype eq 'label')) {
           my $a=Encode::encode_utf8($self->GetValue( $nodename, 'Content' ));
            $self->{'_flat'}{$nodename}{'Content'}=$a;
        }
    }    # end label NODETYPE

    # some general structures:
    $self->{'_flat'}{'_field_types'} = $self->_initial_fieldtypes;
    $self->{'_balloon_ref'} = undef;
    $self->{'_return_value'} = undef;
}
##############################################################################

=head2 _reorder_events (internal)

B<_reorder_events> is an auxiliary method for B<_parse_xml>.
It goes through all important levels (Form, Block, Field) and orders the
configured Events logically.

=cut

sub _reorder_events {
    my $self = shift;

    my $all_elements_ref =
        $self->Apiis::Form::Init::Config::_get_all_public_elements;
    NODE:
    for my $element ( @$all_elements_ref ) {
        my $events_ref = $self->GetValue( $element, '_event_list' );
        next NODE if !$events_ref;
        for my $event ( @$events_ref ){
            my $e_name = $self->GetValue( $event, 'Name' );
            my $e_type = $self->GetValue( $event, 'Type' );
            $self->PushEvent( $element, $e_type, $e_name );
        }
    }
    return;
}
##############################################################################

=head2 _get_all_public_elements (internal)

B<_get_all_public_elements> returns all public elements (which have no leading
underscore) from the _flat structure.

=cut

sub _get_all_public_elements {
    my $self = shift;
    my @all_elements = keys %{$self->{_flat}};
    my @pub_elements = grep {
        $_ !~ m/^_/;
    } @all_elements;
    return \@pub_elements;
}
##############################################################################

=head2 _connect_fields (internal)

B<_connect_fields> overwrites the data reference _data_ref of one Field with
the _data_ref of another one. This is configured with the Connect XML Element.

=cut


sub _connect_fields {
    my $self     = shift;
    BLOCK:
    for my $block ( $self->blocknames ) {
        my $all_fields_ref = $self->GetValue( $block, '_all_field_list' );
        next BLOCK if !$all_fields_ref;
        for my $field ( @$all_fields_ref ) {
            my $con_ref = $self->GetValue( $field, '_connect_list' );
            if ($con_ref) {
                CON:
                for my $con ( @{$con_ref} ) {
                    # get parameters for this Connect:
                    my $par_ref = $self->GetValue( $con, '_parameter_list' );
                    next CON if !$par_ref;

                    # process parameters now:
                    PAR:
                    for my $par (@$par_ref) {
                        my $key = $self->GetValue( $par, 'Key' );
                        next PAR if lc $key ne 'fieldname';
                        my $f_src    = $self->GetValue( $par,   'Value' );

                        # just copy the _data_ref of the source field to that
                        # of the target field and also to the array _data_refs:
                        my $data_ref = $self->GetValue( $f_src, '_data_ref' );
                        $self->SetValue( $field, '_data_ref', $data_ref );
                        my $data_refs = $self->GetValue( $field, '_data_refs' );
                        $_ = $data_ref for @$data_refs;
                    }
                }
            }
        }
    }
}

##############################################################################
1;
