###################################################################################
#
# $Id: GUI.pm,v 1.15 2019/09/24 11:33:00 ulf Exp $
###################################################################################

package Apiis::GUI;
use Carp;
use Apiis::Init::XML;
#use Apiis::Init::DataSource;
use Apiis;

sub new {
    my ( $invocant, %args ) = @_;
    #  croak _("Missing initialisation in main file ([_1]).", __PACKAGE__ ) . "\n"
    #   #    unless defined $apiis;
    my $class = ref($invocant) || $invocant;
    my $self = bless {}, $class;
    $self->_init(%args);
    return $self;
}

=head2



=cut

##############################################################################
sub _init {
    my ( $self, %args ) = @_;
    my $pack = __PACKAGE__;
    return if $self->{"_init"}{$pack}++;    # Conway p. 243

    $self->{"_SetColumnBusy"} = [];
    $self->{"_Apiis"}         = $args{'apiis'};
    $self->{"_GUI"}           = $args{'gui'};
    $self->{"_Xml"}           = $args{'xml'};
    $self->{"_Query"}         = '';
    $self->{'_GUIobj'}        = $args{'guio'};

    $apiis->l10n_init( $apiis->language );

    if ( exists $args{'query'} ) {
        $self->{'_Query'} = $args{'query'};
    }
    else {
        $self->Apiis->errors(
            Apiis::Errors->new(
                type      => 'CODE',
                severity  => 'ERR',
                from      => 'Apiis::GUI',
                msg_short => __( "No query from CGI", 'gui', 'Apiis::GUI' ),
            )
        );
        $self->Apiis->status(1);
        return;
    }
}

sub SetColumnBusy { return $_[0]->{"_SetColumnBusy"} }
sub Apiis         { return $_[0]->{"_Apiis"} }
sub GUI           { return $_[0]->{"_GUI"} }
sub Xml           { return $_[0]->{"_Xml"} }
sub Query         { return $_[0]->{"_Query"} }
sub GUIobj        { return $_[0]->{"_GUIobj"} }

sub SetParameter {
    my ( $self, %optionen ) = @_;
    $self->{_Optionen} = \%optionen;
}

sub GetParameter {
    my ( $self, $value ) = @_;
    return $self->{_Optionen}->{$value};
}

##################################################################################
sub Refresh {
###################################################################################
    my $self = shift;

    #-- Schleife über alle Content-Felder alle Elemente,
    #-- Reihenfolge der Aktualisierung ermitteln
    my @right = ();
    my @left;
    my %hs_v = ();
    foreach my $field ( @{ $self->GUIobj->ContentFields } ) {
        if ( $self->GUIobj->$field->PositionSQL ne '' ) {
            if (   ( $self->GUIobj->$field->ElementType eq 'Data' )
                or ( $self->GUIobj->$field->ElementType eq 'Hidden' ) )
            {
                push( @left, $field );
            }
            $hs_v{$field} = 1;
        }
        else {
            if (   ( $self->GUIobj->$field->ElementType eq 'Data' )
                or ( $self->GUIobj->$field->ElementType eq 'Hidden' ) )
            {
                push( @right, $field );
            }
        }
    }

    my $l = 0;
    for ( my $j = 0; $j <= ( $#right * $#right ); $j++ ) {
        foreach $name (@right) {
            if ( $self->GUIobj->$name->{'Content'} =~ /\[(.*)\]/ ) {
                if ( ( exists $hs_v{$1} ) and ( !exists $hs_v{$name} ) ) {
                    push( @left, $self->GUIobj->$name->Name );
                    $hs_v{ $self->GUIobj->$name->Name } = 1;
                }
            }
        }
    }

    #--- Felder hinten dran hängen, auf die kein Verweis zeigt, doppelte entfernen
    foreach my $name (@right) {
        if ( !exists $hs_v{$name} ) {
            push( @left, $name );
            $hs_v{$name} = 1;
        }
    }

    #--- richtige Reihenfolge
    foreach my $name (@left) {
        if ( ( $self->GUIobj->$name->PositionSQL eq '' ) and ( $self->GUIobj->$name->{'Content'} =~ /\[(.*)\]/ ) ) {
            if ( !UNIVERSAL->can( $self->GUIobj->$name->Content ) ) {
                $self->Apiis->errors(
                    Apiis::Errors->new(
                        type      => 'CODE',
                        severity  => 'ERR',
                        from      => 'Apiis::GUI',
                        msg_short => "$1 ist nicht in *.rpt definiert",
                    )
                );
                $self->Apiis->status(1);
                return;
            }
            else {
                $self->GUIobj->$name->Content( $self->GUIobj->$1->Content );
            }
        }
    }
}

sub ResetFooterObjects {
    my $self   = shift;
    my $object = shift;
    foreach my $name ( @{ $self->GUIobj->$object->GroupFooterObjects } ) {
        if ( $self->GUIobj->$name->ElementType eq 'Data' ) {
            $self->GUIobj->$name->{'_n'}                   = 0;
            $self->GUIobj->$name->{'_min'}                 = 0;
            $self->GUIobj->$name->{'_max'}                 = 0;
            $self->GUIobj->$name->{'_sum'}                 = 0;
            $self->GUIobj->$name->{'_sum2'}                = 0;
            $self->GUIobj->$name->{'_first'}               = 0;
            $self->GUIobj->$name->{'_last'}                = 0;
            $self->GUIobj->$name->{'_QuestionChangeValue'} = undef;
        }
    }
}

###############################################################################
sub GetData {
###############################################################################
    my $self  = shift;
    my $name  = shift;
    my $query = $self->Query;
    my $statement;

    no strict 'refs';
    if ( $self->GUIobj->GUI ne 'Form' ) {
        $name = ${ $self->GUIobj->General }[0] if ( !$name );
        $statement = $self->GUIobj->$name->DataSource;
    }
    else {
        $statement = $self->GUIobj->$name->Statement;
        if ( $self->GUIobj->$name->ElementType eq 'Sql' ) {
            $statement = '(' . $statement . ')';
        }
    }

    #--- xml spezifika ersetzen
    $statement =~ s/&gt;/>/g;
    $statement =~ s/&lt;/</g;

    #--- Parameter ersetzen mit Eingabewerten
    while ( ( my $key, my $parameter ) = each %{ $self->{'_Parameter'} } ) {
        $parameter->[0] = quotemeta( $parameter->[0] );
        $statement =~ s/$parameter->[0]/$parameter->[3]/;
        $err = "Keine Parameter spezifiziert für $parameter->[2]\n" if ( !$parameter->[3] );
    }

    #---
    #--- SQL
    my @data;
    my @structure;
    my $a;
    if ( $statement =~ /^\((.*)\)$/ ) {

        #--- offen: generale Abarbeitung, unabhängig von apiis
        my $sql_ref = $self->Apiis->DataBase->sys_sql($1);
        $self->Apiis->check_status;

        #-- Schleife über alle Daten, abspeichern im array
        while ( my $q = $sql_ref->handle->fetch ) {
            push( @data, [@$q] );
        }
        ($a)         = ( $statement =~ /select(.*)from/ig );
        (@structure) = ( $a         =~ /\s+as\s+([\w|\d]*)/ig );
        return \@data, [@structure];
    }
    elsif ( $statement =~ /^([_a-zA-Z0-9_]*)\((.*)\)$/ ) {
        my $module;
        my $vfunction = $1;
        my @vparam    = split( ',', $2 );
        my $vgui      = $self->GUIobj->path;
        ($vgui) = ( $vgui =~ /\/etc\/(.*)/ );

        $module = $self->Apiis->APIIS_LOCAL . "/etc/$vgui/" . $self->GUIobj->basename . ".pm";
        eval {
            require $module;    #offen: Verzeichnisrechte und öffnen
        };
        if ($@) {
            $self->Apiis->errors(
                Apiis::Errors->new(
                    type      => 'CODE',
                    severity  => 'ERR',
                    from      => 'Apiis::GUI',
                    msg_short => "Can't open modul "
                        . $ENV{'APIIS_LOCAL'}
                        . "/etc/$vgui/"
                        . $self->GUIobj->basename . ".pm",
                    msg_long => "$@"
                )
            );
            $self->Apiis->status(1);
            return;
        }
        # execute loadobject
        eval { @d = &$vfunction( $self, @vparam ); };
        if ($@) {
            $self->Apiis->errors(
                Apiis::Errors->new(
                    type      => 'CODE',
                    severity  => 'ERR',
                    from      => 'Apiis::GUI',
                    msg_short => "Can't execute function $vfunction in module: $module",
                    msg_long  => "$@"
                )
            );
            $self->Apiis->status(1);
            return;
        }
        return @d;
    }
}

###############################################################################
sub MakeGUI {
###############################################################################
    my $self     = shift;
    my $children = shift;
    my @data;
    my $data;
    my $structure;

    if ( $self->GUI eq 'Report' ) {
        ( $data, $structure ) = $self->GetData;
        return if $self->Apiis->status;

        #-- if not defined $self->GUIobj->ContentFields
        #   then skip all codes wich uses the rpt-definition
        #
        if ( $self->GUIobj->ContentFields ) {
            #-- Positionen setzen
            if ($structure) {
                my $i = 1;
                my %hs_v;
                #map {$hs_v{$_}=$i;$i++} @{$structure->[0]};
                map { $hs_v{$_} = $i; $i++ } @{$structure};

                #-- if defined content within detail-block in file *.rpt
                if ( $self->GUIobj->ContentFields ) {
                    foreach my $s ( @{ $self->GUIobj->ContentFields } ) {
                        if (    ( exists $self->GUIobj->$s->{'Content'} )
                            and ( $self->GUIobj->$s->{'Content'} =~ /\[(.*)\]/ ) )
                        {
                            $self->GUIobj->$s->PositionSQL( $hs_v{$1} );
                        }
                    }
                }
            }

            #-- Gruppen bilden und zusammen mit den SQL-Daten abspeichern
            foreach my $q ( @{$data} ) {
                my @g = ();
                #-- if form, grouping of datas not allowed
                if ( $self->GUI eq 'Report' ) {
                    foreach my $grouph ( @{ $self->GUIobj->GroupHeader } ) {
                        foreach my $group ( @{ $self->GUIobj->$grouph->GroupHeaderObjects } ) {
                            push( @g, $q->[ $self->GUIobj->$group->PositionSQL ] )
                                if ( $self->GUIobj->$group->PositionSQL ne '' );
                        }
                    }
                }
                push( @data, [ @g, @$q ] );
            }

            my @sort = ();
            my $i    = 0;
            if ( $self->GUI eq 'Report' ) {
                #--- Sortieren nach Gruppen
                foreach my $grouph ( @{ $self->GUIobj->GroupHeader } ) {
                    if ( $self->GUIobj->$grouph->Sort eq 'Desc' ) {
                        push( @sort, ' $b->[' . $i . '] cmp $a->[' . $i . '] ' );
                    }
                    else {
                        push( @sort, ' $a->[' . $i . '] cmp $b->[' . $i . '] ' );
                    }
                    $i++;
                }
            }

            #--- nur wenn nach irgendwas sortiert werden soll
            if ( $i > 0 ) {
                my @data_neu;
                @data = eval( '@data_neu=sort{' . join( '||', reverse @sort ) . '} @data' );
                @data = @data_neu;
            }

            #--- print GUIHeader
            $self->PrintObjects( $self->GUIobj->GUIHeaderObjects ) if ( $#{ $self->GUIobj->GUIHeaderObjects } > -1 );

            #--- print PageHeader
            $self->PrintObjects( $self->GUIobj->PageHeaderObjects ) if ( $#{ $self->GUIobj->PageHeaderObjects } > -1 );

            foreach my $data (@data) {

                #-- if form, no grouping of datas is allowed
                if ( $self->GUI eq 'Report' ) {
                    #-- Schleife über alle Gruppen
                    foreach my $grouph ( @{ $self->GUIobj->GroupHeader } ) {
                        foreach my $group ( @{ $self->GUIobj->$grouph->GroupHeaderObjects } ) {
                            $self->GUIobj->$group->Content( shift @{$data} )
                                if ( $self->GUIobj->$group->ElementType eq 'Data' );
                        }
                    }

                    #--- wenn neue Gruppe, dann Footer drucken
                    foreach my $grouph ( reverse @{ $self->GUIobj->GroupHeader } ) {
                        my $groupf = $self->GUIobj->$grouph->GroupFooterName;
                        my $ok     = 0;
                        foreach my $group ( @{ $self->GUIobj->$grouph->GroupHeaderObjects } ) {
                            if (    $self->GUIobj->$group->QuestionChangeValue
                                and ( $self->GUIobj->$group->QuestionChangeValue == 1 )
                                and ( $self->GUIobj->$group->ElementType eq 'Data' ) )
                            {
                                $ok = 1;
                            }
                        }
                        if ( $ok == 1 ) {
                            $self->PrintObjects( $self->GUIobj->$groupf->GroupFooterObjects );
                            $self->ResetFooterObjects($groupf);
                        }
                    }

                    #--- wenn neue Gruppe, dann Header drucken
                    foreach my $grouph ( @{ $self->GUIobj->GroupHeader } ) {
                        foreach my $group ( @{ $self->GUIobj->$grouph->GroupHeaderObjects } ) {
                            if ( $self->GUIobj->$group->QuestionChangeValue ) {
                                $self->PrintObjects( $self->GUIobj->$grouph->GroupHeaderObjects );
                            }
                        }
                    }
                }

                foreach my $detail ( @{ $self->GUIobj->DetailObjects } ) {
                    if ( $self->GUIobj->$detail->PositionSQL ne '' ) {
                        $self->GUIobj->$detail->Content( $data->[ $self->GUIobj->$detail->PositionSQL - 1 ] );
                    }
                }
                $self->Refresh;

                $self->PrintObjects( $self->GUIobj->DetailObjects );

                if ( $self->GUI eq 'Report' ) {
                    #--- wenn neue Gruppe, dann Footer drucken
                    foreach my $grouph ( reverse @{ $self->GUIobj->GroupHeader } ) {
                        my $groupf = $self->GUIobj->$grouph->GroupFooterName;
                        $self->PrintObjects( $self->GUIobj->$groupf->GroupFooterObjects );
                        $self->ResetFooterObjects($groupf);
                    }

                    #--- print GUIFooter
                    $self->PrintObjects( $self->GUIobj->GUIFooterObjects )
                        if ( $#{ $self->GUIobj->GUIFooterObjects } > -1 );
                }
            }
        }
        else {
           $self->PrintAllCells( $data, $structure );
        }
    }
    else {

        foreach $_ ( @{$children} ) {
            if ( $self->GUIobj->getobject($_)->objecttype eq 'Block' ) {
                $self->PrintBlock( $self->GUIobj->getobject($_), $self->GUIobj->getobject($_)->parent );
                $self->{'_tablecontent'} .= $self->GUIobj->getobject($_)->table;
            }
        }
    }
    if ( $self->GUI eq 'Report' ) {
        return $self->PrintTable;
    }
}

###############################################################################
sub PrintGUI {
###############################################################################
    my $self = shift;
    if ( exists $self->GUIobj->{'ExportFile'} ) {
        eval {
            my $file = $self->GUIobj->{'ExportFile'};
            open( o_file, ">$file" );
        };
        if ($@) {
            $self->Apiis->errors(
                Apiis::Errors->new(
                    type      => 'CODE',
                    severity  => 'ERR',
                    from      => 'Apiis::GUI',
                    msg_short => "Can't write into file $self->GUIobj->{'ExportFile'}",
                    msg_long  => "$@"
                )
            );
            $self->Apiis->status(1);
            return;
        }
        else {
            print o_file $self->PrintTable;
            close(o_file);
        }
    }
    else {
        if ( $self->GUI eq 'Report' ) {
            print $self->PrintTable;
        }
        else {
            print $self->{'_tablecontent'};
        }
    }
}
###############################################################################
sub PrintFooter {
###############################################################################
    my $self = shift;
}

###############################################################################
sub PrintAllCells {
###############################################################################
  my $self = shift;
}  

###############################################################################
sub LinkModul {
###############################################################################
    my $self   = shift;
    my $module = shift;

    eval {
        require $module;    #offen: Verzeichnisrechte und öffnen
    };
    if ($@) {
        $self->Apiis->errors(
            Apiis::Errors->new(
                type      => 'CODE',
                severity  => 'ERR',
                from      => 'Apiis::GUI',
                msg_short => "Can't open modul $module",
                msg_long  => "$@"
            )
        );
        $self->Apiis->status(1);
        return;
    }
    $self->GUIobj->{'CheckModul'} = 1;
}

1;

