##############################################################################
# $Id: Extjs.pm,v 1.1 2019/06/06 16:05:30 ulf Exp $
# This Init package provides specific methods for Extjs:
##############################################################################

package Apiis::Form::HTML::Extjs;
@Apiis::Form::HTML::Extjs::ISA=qw (Apiis::Form::HTML);

use strict;
use warnings;
our $VERSION = '$Revision: 1.1 $';

use autouse 'Carp' => qw( longmess );
use autouse 'Data::Dumper' => qw( Dumper );

use base "Apiis::Form::Init";
use Apiis;
our @ISA;
our $apiis;

sub _init {
    my ( $self, $args_ref ) = @_;
    return if $self->{"_init"}{ scalar __PACKAGE__ }++;    # Conway p. 243
    
    # we know the type of GUI here:
    $self->gui_type('Extjs');

    # store an existing toplevel reference:
    if ( exists $args_ref->{toplevel} ) {
        # $self->top( $args_ref->{toplevel} ) if $args_ref->{toplevel};
    }

    # Extjs-specific names for fieldtypes:
    $self->set_fieldtypes(
        {   button        => 'Button',
            frame         => 'LabFrame',
            tabular       => 'Tabular',
            tabular2      => 'Tabular2',
            scrollinglist => 'ScrollingList',
            browseentry   => 'BrowseEntry',
            popupmenue    => 'BrowseEntry',
            textfield     => 'TextField',
            textblock     => 'TextBlock',
            label         => 'Label',
            message       => 'Message',
            calendar      => 'DateEntry',
            filefield     => 'Button',
        }
    );

    # extend the search path for modules:
    $self->add_formlib_path( 'Extjs', $self->formname );
}

##############################################################################
# run the configured form:
# flow control:
#  * create top widget
#  * loop through each block
#  * create all fields and other elements like Label, Line in $self->top. Also
#    the special Tabular-'Field'.
#  * start the Extjs loop

sub run {
    my ( $self, $args_ref ) = @_;
    return if $self->status;
    my $toplevel;
    my $master_toplevel = $args_ref->{'toplevel'};
    my $wait_var_ref = $args_ref->{'waitvariable'};

    if ( $master_toplevel ) {
        # create new toplevel on old reference:
        $toplevel = $master_toplevel->Toplevel;
    }
    else {
        # create new toplevel object:
        $toplevel = MainWindow->new();
    }
    $self->top($toplevel);

    my $title = $self->GetValue( $self->generalname, 'Description' );
    $toplevel->configure( -title => $title );

    # running OnOpenForm-Events:
    $self->RunEvent(
        {   elementname => $self->formname,
            eventtype   => 'OnOpenForm',
        }
    );
    my %_done;
    BLOCK:
    foreach my $blockname ( $self->blocknames ) {
        my ( @fieldnames, @widgets );
        my $field_ref = $self->GetValue( $blockname, '_field_list' );
        my $misc_list_ref =
            $self->GetValue( $blockname, '_misc_blockelement_list' );

        FIELD:
        for my $fieldname ( @$field_ref, @$misc_list_ref ) {
            my $fieldtype = lc $self->GetValue( $fieldname, 'Type' );
            my $tk_fieldtype = $self->fieldtype($fieldtype, $fieldname);
            next FIELD if !$tk_fieldtype; # do we need an error here?

            if ( $tk_fieldtype eq 1 ) {
                $self->status;
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'PARAM',
                        severity  => 'ERR',
                        from      => 'Apiis::Form::Extjs::run',
                        backtrace => longmess('invoked'),
                        msg_short => "error on converting fieldnames to Extjs",
                        msg_long  => sprintf(
                            "Fieldtype '%s' not configured for widget set '%s'.",
                            $fieldtype, 'Extjs'
                        ),
                    )
                );
                $self->form_error( die => 0 );
            }

            # require the widget module:
            my $module = 'Apiis::Form::Extjs::' . $tk_fieldtype;
            if ( not exists $_done{$module} ) {
                # load modules only once
                eval "require $module";    ## no critic
                if ($@) {
                    $self->status(1);
                    my $msg = $@;
                    $self->errors(
                        Apiis::Errors->new(
                            type      => 'CODE',
                            severity  => 'CRIT',
                            from      => 'Apiis::Form::Extjs::run',
                            backtrace => longmess('invoked'),
                            msg_long  => $msg,
                            msg_short =>
                                sprintf( "Error loading module '%s'", $module ),
                        )
                    );
                    last BLOCK;
                }
                else {
                    push @ISA, $module;
                }
            }
            $_done{$module}++;
            $self->form_error( die => 0 ) if $self->status;

            # the commands are named after the Fieldtype, e.g _textfield for
            # type TextField or _label for type Label:
            my $command = '_' . $fieldtype;
            my $widget;
            eval { $widget = $self->$command( elementname => $fieldname ) };
            if ($@) {
                $self->status(1);
                my $msg = $@;
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'CODE',
                        severity  => 'CRIT',
                        from      => 'Apiis::Form::Extjs::run',
                        backtrace => longmess('invoked'),
                        msg_long  => $msg,
                        msg_short => __(
                            "Error running command '[_1]'", $command ),
                    )
                );
                $self->form_error( die => 0 );
                last BLOCK;
            }

            if ( not defined $widget ) {
                $self->status(1);
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'CODE',
                        severity  => 'CRIT',
                        from      => 'Apiis::Form::Extjs::run',
                        backtrace => longmess('invoked'),
                        msg_short => __(
                            "Method '[_1]' returned no valid widget", $command ),
                    )
                );
                $self->form_error( die => 0 );
                last BLOCK;
            }
            push @fieldnames, $fieldname;
            push @widgets,    $widget;
            # store widget reference for later use (error handling):
            $self->PushValue( $fieldname, '_widget_refs', $widget );
        }

        for my $index ( 0 .. $#fieldnames ) {
            my $field  = $fieldnames[$index];
            my $widget = $widgets[$index];
            $widget->grid(
                -row        => $self->GetValue( $field, 'Row' ),
                -column     => $self->GetValue( $field, 'Column' ),
                -columnspan => $self->GetValue( $field, 'Columnspan' ),
                -padx       => $self->GetValue( $field, 'PaddingRight' )  || 0,
                -pady       => $self->GetValue( $field, 'PaddingTop' )    || 0,
                -ipadx      => $self->GetValue( $field, 'IPaddingRight' ) || 0,
                -ipady      => $self->GetValue( $field, 'IPaddingTop' )   || 0,
                -sticky     => $self->GetValue( $field, 'Sticky' ),
            );
            my $visible = $self->GetValue( $field, 'Visibility' );
            $widget->gridForget if $visible and $visible eq 'hidden';
        }
    }

    $self->top->OnDestroy(
        sub {
            if ( defined $wait_var_ref ) {
                $$wait_var_ref = 1;
            }
        }
    );
    # $self->top->protocol('WM_DELETE_WINDOW', \&before_exit);
    MainLoop() unless $self->status;

    # running OnCloseForm-Events:
    $self->RunEvent(
        {   elementname => $self->formname,
            eventtype   => 'OnCloseForm',
        }
    );
}


#################################################################
#  Init a HTML-Form using AJAX
#################################################################

sub PrintBody {
    my $self = shift;
    my %_done;
    my $cell;
    my $cell1;

    #--- make a loop over all blocks in xml-definition
    #--- and initialize variables
    my $tab0      = 100000;
    my $hs_config = {};
    $hs_config->{general} = {
        'date_order'  => $apiis->date_order,
        'date_sep'    => $apiis->date_sep,
        'date_format' => lc( $apiis->date_format ),
        'tab_0'       => undef,
        'tab_first'   => undef
    };

    # running OnOpenForm-Events:
    $self->RunEvent( { elementname => $self->formname, eventtype => 'OnOpenForm', } );

    BLOCK: foreach my $blockname ( $self->blocknames ) {

        my @navigationbar = ();
        my @statusbar     = ();
        my @ar_pos        = ();
        my $max_col       = 0;
        my $vtr           = '';
        my $vnavi         = '';
        my $vstatus       = '';
        my $vstyle;
        my $row           = '';
        my $column        = '';
        my $field_ref     = $self->GetValue( $blockname, '_field_list' );
        my $misc_list_ref = $self->GetValue( $blockname, '_misc_blockelement_list' );
        my $ds            = $self->GetValue( $blockname, 'DataSource' );
        my %hs_floworder;
        my @floworder;
        my %hs_order;

        FIELD:
#        for my $fieldname ( @$field_ref, @$misc_list_ref ) {
        for my $fieldname ( @$field_ref ) {

            #-- skip if field = hidden
            next
                if (
                (       $self->GetValue( $fieldname, 'Visibility' )
                    and $self->GetValue( $fieldname, 'Visibility' ) eq 'hidden'
                )
                );

            next if ( exists $self->{'_disable_targetfield'}->{$fieldname} );

            my $tab_col = $self->GetValue( $fieldname, 'DSColumn' );
            my $check;
            my @check;

            my $fieldtype = lc $self->GetValue( $fieldname, 'Type' );

            #-- prepare FlowOrder for special fieldtypes
            #-- if FlowOrder not defined then floworder=''
            #--
            if ((   !$self->GetValue( $fieldname, 'Enabled' )
                    or (    ( $self->GetValue( $fieldname, 'Enabled' ) )
                        and ( $self->GetValue( $fieldname, 'Enabled' ) ne "no" ) )
                )
                and (  ( $fieldtype eq 'filefield' )
                    or ( $fieldtype eq 'textfield' )
                    or ( $fieldtype eq 'scrollinglist' )
                    or ( $fieldtype eq 'checkbox' ) )
                and ( $fieldname ne '__nav_r' )
                )
            {
                my $floworder = '999999';
                $floworder = $self->GetValue( $fieldname, 'FlowOrder' )
                    if ( $self->GetValue( $fieldname, 'FlowOrder' ) );
                if ( exists $hs_floworder{$floworder} ) {
                    push( @{ $hs_floworder{$floworder} }, $fieldname );
                }
                else {
                    $hs_floworder{$floworder} = [$fieldname];
                }
            }

            if ( $self->GetValue( $fieldname, 'FlowOrder' ) ) {
                $hs_config->{general}->{'tab_first'} = $fieldname if ( !$hs_config->{general}->{'tab_first'} );
                if ( $tab0 > $self->GetValue( $fieldname, 'FlowOrder' ) ) {
                    $hs_config->{general}->{'tab_0'} = $fieldname;
                    $tab0 = $self->GetValue( $fieldname, 'FlowOrder' );
                }
            }

            #next if (($fieldtype eq 'label') or ($fieldtype eq 'button') or ($fieldtype eq 'image') or
            #         ($fieldtype eq 'link'));

            #-- JSONConfig füllen
            $hs_config->{fields}->{$fieldname} =
                { 'type' => '', 'default' => '', 'defaultfunction' => '', 'check' => [] };
            if ($tab_col) {
                if ( $self->GetValue( $ds, 'Type' ) eq 'Record' ) {
                    my $col;
                    if ( $self->GetValue( $tab_col, 'Type' ) eq 'Related' ) {
                        $col = $self->GetValue( $self->GetValue( $tab_col, 'RelatedColumn' ), 'DBName' );
                    }
                    else {
                        $col = $self->GetValue( $tab_col, 'DBName' );
                    }
                    my $type = $apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col)->datatype;
                    if ( lc($type) eq 'date' ) {
                        $check = 'isadate';
#                        $self->SetValue( $fieldname, 'InputType', 'date' );
                    }
                    elsif ( ( ( lc($type) eq 'float' ) or ( lc($type) eq 'real' ) or ( lc($type) eq 'bigint' ) )
                        and ( ( $col !~ /^db_/ ) and ( $col !~ /_id$/ ) and ( $col !~ /id_set$/ ) ) )
                    {
                        $check = 'isanumber';
                        $type  = 'number';
#                        $self->SetValue( $fieldname, 'InputType', 'number' );
                    }
                    if ( $apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col)->check ) {
                        if ( ( $col ne 'guid' ) and ( $col !~ /^db_/ ) ) {
                            @check = $apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col)->check;
                        }
                    }
                    if ( $apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col)->default ) {
                        my $v = $apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col)->default;
                        $v = $self->GetValue( $fieldname, 'Default' )
                            if ( defined $self->GetValue( $fieldname, 'Default' ) );
                        $hs_config->{fields}->{$fieldname}->{'default'} = $v;
                    }
                    else {
                        if ( defined $self->GetValue( $fieldname, 'Default' ) ) {
                            $hs_config->{fields}->{$fieldname}->{'default'} = $self->GetValue( $fieldname, 'Default' );
                        }
                    }
                    $hs_config->{fields}->{$fieldname}->{'type'} = $type;
                }
                push( @check, lc( $self->GetValue( $fieldname, 'Check' ) ) )
                    if ( $self->GetValue( $fieldname, 'Check' ) );
                push( @check, lc($check) ) if ($check);
                push( @{ $hs_config->{fields}->{$fieldname}->{'check'} }, @check );
            }
            else {
                push( @{ $hs_config->{fields}->{$fieldname}->{'check'} }, 'isadate' )
                    if (( $self->GetValue( $fieldname, 'InputType' ) )
                    and ( $self->GetValue( $fieldname, 'InputType' ) eq 'date' ) );
                $hs_config->{fields}->{$fieldname}->{'type'}    = $self->GetValue( $fieldname, 'InputType' );
                $hs_config->{fields}->{$fieldname}->{'default'} = $self->GetValue( $fieldname, 'Default' );
            }
            $hs_config->{fields}->{$fieldname}->{'defaultfunction'} = $self->GetValue( $fieldname, 'DefaultFunction' );

            my $html_fieldtype = $self->fieldtype( $fieldtype, $fieldname );
                
            if (    defined $self->GetValue( $fieldname, 'Row' )
                    and defined $self->GetValue( $fieldname, 'Column' )
                    and ( $fieldname ne '__nav_r' )
                    and ( $fieldname ne '__statusbar' )
                    and ( !defined $self->GetValue( $fieldname, 'Navigationbar' )
                        or $self->GetValue( $fieldname, 'Navigationbar' ) eq 'no' )
                    )
                {
                    my ( $a, $a1, $b, $b1 );
                    $a = $self->GetValue( $fieldname, 'Row' );
                    if ( $self->GetValue( $fieldname, 'Rowspan' ) ) {
                        $a1 = $self->GetValue( $fieldname, 'Rowspan' );
                    }
                    $b = $self->GetValue( $fieldname, 'Column' );
                    if ( $self->GetValue( $fieldname, 'Columnspan' ) ) {
                        $b1 = $self->GetValue( $fieldname, 'Columnspan' );
                    }
                    if ( $ar_pos[$a][$b] ) {
                        push( @{ $ar_pos[$a][$b] }, $self->GetValue( $fieldname, 'Name' ) );
                    }
                    else {
                        $ar_pos[$a][$b] = [ $self->GetValue( $fieldname, 'Name' ) ];
                    }

                    #-- find max Column
                    $max_col = $b1 if ( ($b1) and ( $b1 > $max_col ) );
                    $max_col = $b  if ( ($b)  and ( $b > $max_col ) );
                }
                elsif ( $fieldname eq '__statusbar' ) {
                    push( @statusbar, $fieldname );
                }
                else {
                    push( @navigationbar, $fieldname );
                }
        }

        #-- makes a flat structure from hash into an array - change Floworder in an order
        #
        foreach my $key ( sort { $a <=> $b } keys %hs_floworder ) {
            map { push( @floworder, $_ ) } @{ $hs_floworder{$key} };
        }

        $hs_order{ $floworder[0] } = [ $floworder[$#floworder], $floworder[1] ];
        for ( my $i = 1; $i < $#floworder; $i++ ) {
            $hs_order{ $floworder[$i] } = [ $floworder[ $i - 1 ], $floworder[ $i + 1 ] ];
        }
        $hs_order{ $floworder[$#floworder] } = [ $floworder[ $#floworder - 1 ], $floworder[0] ];
        $hs_config->{'general'}->{'floworder'} = {%hs_order};
        $hs_config->{'general'}->{'ar_floworder'} = [@floworder];
        $hs_config->{'blockname'}=$blockname;
    }

    return $hs_config;
}

###############################################################################
#-- creates extjs-DataArray
###############################################################################
sub CreateDataArray {
    
    my $self        = shift;
    my $hs_config   = shift;

    my $dataarray; my @data;
    $dataarray='var myData = [';
    
    foreach my $vfield (@{ $hs_config->{'general'}->{'ar_floworder'}} ) {
        push(@data,'');
    }

    $dataarray.=join(',',@data);
    $dataarray.='];';

    return $dataarray;
}

###############################################################################
#-- creates extjs-ArrayStore
###############################################################################
sub CreateArrayStore {
    
    my $self        = shift;
    my $hs_config   = shift;
    my $jsond       = shift;

    my $arraystore;
    $arraystore.='var store = new Ext.data.ArrayStore({';
    $arraystore.='fields: [';
    
    my @fields;
    foreach my $vfield (@{ $hs_config->{'general'}->{'ar_floworder'}} ) {
    
        my $field='{';
    
        $field.="name:'".$vfield."',";
        if ($self->GetValue($vfield,'Type') eq 'TextField') {
            if ($self->GetValue($vfield,'InputType') eq 'number') {
                $field.="type:'float',";
            }
            elsif ($self->GetValue($vfield,'InputType') eq 'date') {
                $field.="type:'date',";
                $field.="dateFormat:'n/j h:ia',";
            }
        }

        $field.='}';

        push(@fields,$field);
    }

    $arraystore.=join(',',@fields);
    $arraystore.=']';
    $arraystore.='});';

    return $arraystore;
}

###############################################################################
#-- creates extjs-GridPanel
###############################################################################
sub CreateGridPanel {
    
    my $self        = shift;
    my $hs_config   = shift;

    my $grid;
    $grid.='    // create the Grid'."\n";
    $grid.='    var grid = new Ext.grid.GridPanel({';
    $grid.='                   store: store,';
    
    $grid.='                   columns: [';

    my $blockname=$hs_config->{'blockname'};

    my $i=0; my @fields;
    foreach my $vfield (@{ $hs_config->{'general'}->{'ar_floworder'}} ) {
    
        my $field='{';

        #-- Sonderbehandlung, bei erstem Feld
        $field .= "id:'".$blockname."'," if ($i++ == 0);
        $field .= "header: '".   $self->GetValue($vfield,'Label')."',";
        if ($self->GetValue($vfield,'Width') ne '') {
            $field .= "width: ".     $self->GetValue($vfield,'Width').",";
        }
        if ($self->GetValue($vfield,'Sortable') eq 'yes') {
            $field .= "sortable: true,";
        }
        else {
            $field .= "sortable: false,";
        }

        $field .= "dataIndex: '".$vfield."',";
#       $field .= "renderer: '". $hs_config->{$vfield}->{'Format'}."',";
        $field .= "}";

        push(@fields,$field);
    }
    $grid.=join(',',@fields);
    $grid.='],';

    #-- alternative Farben für jede Zeile 
    if (exists $hs_config->{$blockname}->{'striperows'}) {
        $grid.='stripeRows: '.$self->GetValue($blockname,'Striperows').',';
    }

#    $grid.='height: 350,';
    $grid.='width: 600,';
#    $grid.="title: '".$self->GetValue($blockname,'Title')."',";
#    $grid.='stateful: true,';
#    $grid.="stateId: 'grid'";
    $grid.='});';

    return $grid;
}


##############################################################################
sub PrintHeaderInit {
    my $self   = shift;
    my $opt_js = shift;
    my $query  = $self->{_query};
    my $enc    = $self->GetValue( $self->generalnames->[0], 'CharSet' );
    my $css    = $self->GetValue( $self->generalnames->[0], 'StyleSheet' );
    my $title  = $self->GetValue( $self->generalnames->[0], 'Description' );
    my $width  = $self->GetValue( $self->formnames->[0],    'Width' );
    my $height = $self->GetValue( $self->formnames->[0],    'Height' );

    # write code for <body>
    my $header='';
    $header .= '<html>';
    $header .= '<head>';
    $header .= '<meta http-equiv="Content-Type" content="text/html; charset="'.$enc.'" />';
    $header .= '<title>' . $title . '</title>';
    
    $header .= '<link rel="stylesheet" type="text/css" href="/lib/Apiis/Extjs/resources/css/ext-all.css" />';

    $header .= '<script type="text/javascript" src="/lib/Apiis/Extjs/adapter/ext/ext-base.js"></script>';
    $header .= '<script type="text/javascript" src="/lib/Apiis/Extjs/ext-all-debug.js"></script>';
  
    #-- execute on this place! 
    my $jsond; my $data;
    ($jsond,$data) = $self->InitJSONData();
   
    my $hs_config=$self->PrintBody();

    $header .= '<script type="text/javascript">'."\n";
    $header .= '// Path to the blank image should point to a valid location on your server'."\n";
    $header .= "Ext.BLANK_IMAGE_URL = '/lib/Apiis/Extjs/resources/images/default/s.gif';\n ";
    $header .= 'Ext.onReady(function(){'."\n";

#    $header.=$jsond.";\n";

    #-- Schleife über alle Datensätze
    my @data;
    for (my $i=0; $i<=$#{ $data->{'data'}};$i++ ) {

        my @record;
        #-- Schleife über die Reihenfolge der Felder
        foreach my $vfield (@{ $hs_config->{'general'}->{'ar_floworder'}} ) {
            push(@record,$data->{'data'}->[$i]->{$vfield}->[0]);
        }
        push(@data,'['.join(',',@record).']');
    }

    $header .= 'var myData = ['."\n";
    $header .= join(',',@data);
    $header .= '];'."\n";

    $header .= $self->CreateArrayStore($hs_config);

    $header .= "store.loadData(myData);\n";    

    $header .= $self->CreateGridPanel($hs_config);

    $header .= "grid.render('grid-example')\n }); //end onReady";
    $header .= '</script>';
                 
    
    $header .= '</head>'."\n";
    $header .= '<body>'."\n";
    $header .= '     <div id="grid-example"/>'."\n";
    $header .= '</body>'."\n";
    $header .= '</html>'."\n";

    $self->{'_table'} = $header;
}


1;

