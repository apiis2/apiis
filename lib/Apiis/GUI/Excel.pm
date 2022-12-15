###################################################################################
#
# $Id: Excel.pm,v 1.4 2019/10/03 20:08:38 ulf Exp $
###################################################################################
use Apiis::GUI;

###################################################################################
package Apiis::GUI::Excel;
@Apiis::GUI::Excel::ISA = qw (Apiis::GUI);
use Spreadsheet::WriteExcel;

sub PrintHeader {
    my $self = shift;
    print $self->Query->header(-type=>'application/vnd.ms-excel');
    binmode(STDOUT);
    $self->{_workbook}  = Spreadsheet::WriteExcel->new( \*STDOUT );    # Step 1
    $self->{_worksheet} = $self->{_workbook}->add_worksheet();         # Step 2
    $self->{_globalrow} = 0;

}

sub PrintObjects {
    my $self    = shift;
    my $objects = shift;
    my $parent  = shift;
    my $cell;
    my $row;
    my @cell;
    my $column;

    return if ( $#{$objects} eq -1 );
    if ( !$parent ) {
        if ( $self->GUI eq "Report" ) {
            $parent = $self->GUIobj->{ $objects->[0] }->CallFrom;
            $parent = $self->GUIobj->$parent->[0];
        }
    }
    if ( !defined $parent ) {
        $parent = $self->GUIobj->{ $objects->[0] }->Parent;
    }

    if ( $#{ $self->GUIobj->$parent->OrderByRow } eq -1 ) {
        my @s = ();
        foreach ( @{ $self->GUIobj->$parent->Children } ) {
            push( @s, [ $self->GUIobj->$_->Row, $_ ] );
        }
        map { push( @{ $self->GUIobj->$parent->OrderByRow }, $_->[1] ) } sort { $a->[0] <=> $b->[0] } @s;
    }

    foreach my $o ( @{ $self->GUIobj->$parent->OrderByRow } ) {
        next if ( $self->GUIobj->$o->ElementType eq 'Hidden' );
        #-- if object a new row, then init new else collect
        no strict 'refs';
        if ( $row and ( $self->GUIobj->$o->Row ne $row ) ) {
            $self->PrintRow( \@cell );
            @cell = ();
        }
        $row    = $self->GUIobj->$o->Row;
        $column = $self->GUIobj->$o->Column;

        if ($row) {
            $cell[ $column - 1 ] = $self->PrintCell($o);
        }
        else {
            if ( $self->GUIobj->$o->ElementType eq 'Block' ) {
                $self->PrintObjects( $self->GUIobj->$o->Children, $self->GUIobj->$o->Name );
            }
        }
    }
    $self->PrintRow( \@cell );
    return;
}

sub PrintCell {
    my $self       = shift;
    my $object     = shift;
    my $cell       = '';
    my @properties = ();
    my $query      = $self->Query;
    no strict 'refs';
    my $controled;
    my $replace;

    #-- Datenbehandlung
    my $et     = $self->GUIobj->$object->ElementType;
    my $column = $self->GUIobj->$object->Column;

    no strict 'refs';
    #-- Belegte Zellen finden und kennzeichnen
    if ( $column =~ /.+\-.+/ ) {
        my ( $min, $max ) = ( $column =~ /(.+)\-(.+)/ );
        $colcount = $max - $min + 1;
        for ( my $i = $min; $i <= $max; $i++ ) {
            $self->GUIobj->SetColumnBusy($i);
        }
    }
    else {
        $self->GUIobj->SetColumnBusy($column) if ( $column =~ /^\d+/ );
    }

    #-- Spaltenbelegung ermitteln
    #if ($column=~/(.+)\-/) {$column=$1};

    if ( ( $et eq 'Text' ) or ( $et eq 'Data' ) or ( $et eq 'Label' ) or ( $et eq 'Field' ) ) {
        if ( $et eq 'Text' ) {
            $cell = $self->GUIobj->$object->Content;
        }
        else {
            $cell = $self->GUIobj->$object->Content;
        }
        if ( $et eq 'Data' ) {
            if (    ( $self->GUIobj->$object->DecimalPlaces ne '' )
                and ( $self->GUIobj->$object->DecimalPlaces ne 'Automatic' )
                and ( $self->GUIobj->$object->DecimalPlaces ne 'none' ) )
            {
                $cell = sprintf( '%.' . $self->GUIobj->$object->DecimalPlaces . 'f', $cell );
            }
        }
	use Encode;
	$cell=Encode::decode("utf-8", $cell);
    }

    if ( ( $et eq 'Lines' ) or ( $self->GUIobj->$object->FieldType eq 'Line' ) ) {
        if ( $self->GUIobj->$object->Column =~ /(.+)\-/ and $colcount < $self->GUIobj->MaxColumn ) {
            my $column = $self->GUIobj->$object->Column;
        }
        else {
        }
    }
    if ( $cell =~ /^date\(/ ) {
        $cell = localtime();
    }

    #--- loop over all elements
    if ( $self->GUI eq 'Report' ) {
        foreach my $item ( keys %{ $self->GUIobj->$object } ) {
            my $t = $self->GUIobj->$object->$item;
            if ( $t and $t ne 'none' ) {
                if ( $item eq 'FontStyle' ) {
                }
                if ( $item eq 'FontSize' ) {
                }
                if ( $item eq 'FontWeight' ) {
                }
                if ( $item eq 'FontVariant' ) {
                }

                if ( $item eq 'FontFamily' ) {
                }
                if ( $item eq 'BackgroundColor' ) {
                }
                if ( $item eq 'Color' ) {
                }
                if ( $item eq 'TextAlign' ) {
                }
            }
        }
        foreach my $item ( @{ $self->GUIobj->$object->Functions } ) {
            #--- initialize
            $replace = '';
            $t       = '';

            #--- if content a function, then solve function and save return value
            if ( $self->GUIobj->$object->$item =~ /^([_a-zA-Z0-9_]*)\((.*)\)$/ ) {
                my @vparam = split( ',', $2 );
                my $vfunction = "Apiis::GUI::$1";

                #mue in initialisierungsteil #--- test if module exists
                if ( !$self->GUIobj->CheckModul ) {
                    $self->LinkModul( $self->GUIobj->path . '/' . $self->GUIobj->basename . ".pm" );
                    return if ( $self->Apiis->status == 1 );
                }

                #--- set parameters and auflösen
                my @vvparam = ();
                foreach my $v (@vparam) {
                    if ( $v =~ /\[(.*?)\]/ ) {
                        push( @vvparam, $self->GUIobj->$1->Content );
                    }
                    else {
                        push( @vvparam, $v );
                    }
                }

                #--- execute function
                eval { $replace = &$vfunction( $self, @vvparam ); };
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

                my $t = $replace;

            }
        }

    }
    $row    = $self->{_globalrow};
    $column = $self->GUIobj->$object->Column;
    $column = $column - 1;
    my $format1 = $self->{_workbook}->add_format( num_format => '@' );
    
    $self->{_worksheet}->write_string( $row, $column, $cell, $format1 );
}

sub PrintAllCells {
    my $self   = shift;
    my $data   = shift;
    my $header = shift;

    for ( my $j = 0; $j <= $#{$header}; $j++ ) {
        my $cell=$header->[$j];

#mue sonderfall
	use Encode;
	$cell=Encode::decode("utf-8", $cell);
#emue
        $self->{_worksheet}->write_string( 0, $j, $cell, $format1 );    
    }

    my $format1 = $self->{_workbook}->add_format( num_format => '@' );

    for ( my $i = 0; $i <= $#{$data}; $i++ ) {
        for ( my $j = 0; $j <= $#{ $data->[$i] }; $j++ ) {
        my $cell=$data->[$i][$j];

#mue sonderfall
	use Encode;
	$cell=Encode::decode("utf-8", $cell);
#emue
            $self->{_worksheet}->write_string( $i + 1, $j, $cell, $format1 );
        }
    }
}

sub PrintRow {
    my $self = shift;
    $self->{_globalrow}++;
}

sub PrintTable {
    my $self = shift;
}

sub PrintGUI {
    my $self = shift;
    $self->{_workbook}->close;    # Step 3
}
1;

