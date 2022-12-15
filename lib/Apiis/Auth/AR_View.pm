##############################################################################
# $Id: AR_View.pm,v 1.21 2021/05/27 19:53:15 ulf Exp $
##############################################################################.
#package Apiis::Auth::AR_View;
$VERSION = '$Revision: 1.21 $';
##############################################################################

=head1 NAME

Apiis::Auth::AR_View

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
use strict;
use warnings;
use Carp;
use Apiis::DataBase::Record;
use Apiis::DataBase::SQL::MakeSQL;
use Apiis::Init;
use Data::Dumper;

our $apiis;
our $admin_defined;
our $debug;
##############################################################################

=head2 create_st_access_view

  This subroutine creates view which returns information about user access rights 
  for the system tasks. The view is created in the user schema.$from_interface 
  parameter is used only if you want to call this subroutine from the interface 
  and is needed to remove the standard print-outs.

=cut

sub create_st_access_view {
    my ( $user, $from_interface ) = @_;
    my $system_user = $apiis->Model->db_user;
    my $view        = "v_star_" . $user;
    drop_view( $view, $user );

    EXIT: {
        drop_view( $view, $user );
        my $sql =
            "SELECT ar_user_roles.role_id,role_subset,role_name FROM ar_user_roles,ar_roles 
            WHERE ar_user_roles.role_id=ar_roles.role_id and user_id 
            IN (SELECT user_id FROM ar_users where user_login='$user')";
        my $fetched_0 = $apiis->DataBase->sys_sql($sql);
        if ( $fetched_0->status ) {
            $apiis->errors( $fetched_0->errors );
            $apiis->status(1);
            print "\n" if ( not defined $from_interface );
            last EXIT;
        }
        my ( @sub_roles, @roles_id, @all_roles );
        my $rows = $fetched_0->handle->rows;
        if ($rows) {
            while ( my $ret_val = $fetched_0->handle->fetch ) {
                my $rolename = $ret_val->[2];
                if ( !( grep /^$rolename/, @all_roles ) ) {
                    push @all_roles, $rolename;
                    if ( $ret_val->[1] ) {
                        my @splited = split ',', $ret_val->[1];
                        my $string =
                            "role_name='"
                            . join( "' OR role_name='", @splited ) . "' ";
                        push @sub_roles, $string;
                        push @roles_id,  $ret_val->[0];
                    }
                    else {
                        push @roles_id, $ret_val->[0];
                    }
                }
            }
            my $finall_role_id;
            if (@sub_roles) {
                my $ret_role_id =
                    role_recursion( \@roles_id, \@sub_roles, \@all_roles );
                $finall_role_id = join( ',', @$ret_role_id );
            }
            else {
                $finall_role_id = join( ',', @roles_id );
            }

            my $sql_1 = "
    CREATE VIEW $user.$view AS 
      SELECT stpolicy_id,stpolicy_name,stpolicy_type,stpolicy_desc 
        FROM $system_user.ar_stpolicies
       WHERE stpolicy_id IN
               (SELECT stpolicy_id FROM ar_role_stpolicies WHERE role_id IN 
                   ($finall_role_id))";

            my $fetched_1 = $apiis->DataBase->sys_sql($sql_1);
            if ( $fetched_1->status ) {
                $apiis->errors( $fetched_1->errors );
                $apiis->status(1);
                print "\n" if ( not defined $from_interface );
            }
            else {
                my $msg_1 = __(
                    "User access view v_star_[_1] (re)created (system tasks view)",
                    $user
                );
                print "\nOK: $msg_1" if ( not defined $from_interface );
                $apiis->log( 'debug',
                    "Apiis::Auth::AccessControl::create_st_access_view: $msg_1"
                );
            }
        }
        else {
            my $sql_2 = "
    CREATE VIEW $user.$view AS SELECT stpolicy_id,stpolicy_name,stpolicy_type,stpolicy_desc 
        FROM $system_user.ar_stpolicies
       WHERE stpolicy_id is NULL";

            my $fetched_2 = $apiis->DataBase->sys_sql($sql_2);
            if ( $fetched_2->status ) {
                $apiis->errors( $fetched_2->errors );
                $apiis->status(1);
                print "\n" if ( not defined $from_interface );
            }
            else {
                my $msg_1 = __(
                    "User access view v_star_[_1] (re)created (system tasks view)",
                    $user
                );
                print "\nOK: $msg_1" if ( not defined $from_interface );
                $apiis->log( 'debug',
                    "Apiis::Auth::AccessControl::create_st_access_view: $msg_1"
                );
            }

        }
    }    #EXIT
    return;
}
##############################################################################

=head2 create_dbt_access_view

  This subroutine creates view which returns information about user access rights
  for the database tasks. The view is created in the user schema.

=cut

sub create_dbt_access_view {
    my ( $user, $from_interface ) = @_;
    my $system_user = $apiis->Model->db_user;
    my $view        = "v_dbtar_" . $user;

    EXIT: {
        drop_view( $view, $user );
        my $sql =
            "SELECT ar_user_roles.role_id,role_subset,role_name FROM ar_user_roles,ar_roles 
            WHERE ar_user_roles.role_id=ar_roles.role_id and user_id 
            IN (SELECT user_id FROM ar_users where user_login='$user')";
        my $fetched_0 = $apiis->DataBase->sys_sql($sql);
        if ( $fetched_0->status ) {
            $apiis->errors( $fetched_0->errors );
            $apiis->status(1);
            print "\n" if ( not defined $from_interface );
            last EXIT;
        }
        my $rows = $fetched_0->handle->rows;
        my ( @sub_roles, @roles_id, @all_roles );
        if ($rows) {
            while ( my $ret_val = $fetched_0->handle->fetch ) {
                my $rolename = $ret_val->[2];
                if ( !( grep /^$rolename/, @all_roles ) ) {
                    push @all_roles, $rolename;
                    if ( $ret_val->[1] ) {
                        my @splited = split ',', $ret_val->[1];
                        my $string =
                            "role_name='"
                            . join( "' OR role_name='", @splited ) . "' ";
                        push @sub_roles, $string;
                        push @roles_id,  $ret_val->[0];
                    }
                    else {
                        push @roles_id, $ret_val->[0];
                    }
                }
            }
            my $finall_role_id;
            if (@sub_roles) {
                my $ret_role_id =
                    role_recursion( \@roles_id, \@sub_roles, \@all_roles );
                $finall_role_id = join( ',', @$ret_role_id );
            }
            else {
                $finall_role_id = join( ',', @roles_id );
            }

            my $sql_1 = "
   CREATE VIEW $user.$view AS 
     SELECT dbtpolicy_id,ext_code as sqlaction,table_name,table_columns,descriptor_name,descriptor_value 
       FROM $system_user.codes,$system_user.ar_dbtpolicies,$system_user.ar_dbttables,$system_user.ar_dbtdescriptors 
      WHERE ($system_user.ar_dbtpolicies.table_id=$system_user.ar_dbttables.table_id 
             and $system_user.ar_dbtpolicies.descriptor_id=$system_user.ar_dbtdescriptors.descriptor_id 
             and $system_user.ar_dbtpolicies.action_id=$system_user.codes.db_code
            )
            and dbtpolicy_id IN
              (SELECT dbtpolicy_id FROM ar_role_dbtpolicies WHERE role_id IN 
                  ($finall_role_id))";

            my $fetched_1 = $apiis->DataBase->sys_sql($sql_1);
            if ( $fetched_1->status ) {
                $apiis->errors( $fetched_1->errors );
                $apiis->status(1);
                print "\n" if ( not defined $from_interface );
            }
            else {
                my $msg_1 = __(
                    "User access view v_dbtar_[_1] (re)created (database tasks view)",
                    $user
                );
                print "\nOK: $msg_1" if ( not defined $from_interface );
                $apiis->log( 'debug',
                    "Apiis::Auth::AccessControl::create_dbt_access_view: $msg_1"
                );
            }

        }
        else {
            my $sql_2 = "
   CREATE VIEW $user.$view AS 
     SELECT dbtpolicy_id,ext_code as sqlaction,table_name,table_columns,descriptor_name,descriptor_value 
       FROM $system_user.codes,$system_user.ar_dbtpolicies,$system_user.ar_dbttables,$system_user.ar_dbtdescriptors 
      WHERE dbtpolicy_id is NULL";

            my $fetched_2 = $apiis->DataBase->sys_sql($sql_2);
            if ( $fetched_2->status ) {
                $apiis->errors( $fetched_2->errors );
                $apiis->status(1);
                print "\n" if ( not defined $from_interface );
            }
            else {
                my $msg_1 = __(
                    "User access view v_dbtar_[_1] (re)created (database tasks view)",
                    $user
                );
                print "\nOK: $msg_1" if ( not defined $from_interface );
                $apiis->log( 'debug',
                    "Apiis::Auth::AccessControl::create_dbt_access_view: $msg_1"
                );
            }

        }
    }    #EXIT
    return;
}
##############################################################################

=head2 role_recursion

  Collect information about user role ids which are used to create access
  rights view.

=cut

sub role_recursion {
    my ( $roles_id, $role_names, $all_roles ) = @_;
    my $final_roles_id;
    EXIT: {
        my $sql_0 = "SELECT role_id,role_subset,role_name 
              FROM ar_roles WHERE (" . join( ' OR ', @$role_names ) . ")";
        my $fetched_0 = $apiis->DataBase->sys_sql($sql_0);
        if ( $fetched_0->status ) {
            $apiis->errors( $fetched_0->errors );
            $apiis->status(1);
            last EXIT;
        }
        my @sub_roles;
        while ( my $ret_val = $fetched_0->handle->fetch ) {
            my $rolename = $ret_val->[2];
            if ( !( grep /^$rolename/, @$all_roles ) ) {
                push @$all_roles, $rolename;
                if ( $ret_val->[1] ) {
                    push @sub_roles, "role_name='" . $ret_val->[1] . "' ";
                    push @$roles_id, $ret_val->[0];
                }
                else {
                    push @$roles_id, $ret_val->[0];
                }
            }
        }
        if (@sub_roles) {
            my $r_ids =
                role_recursion( \@$roles_id, \@sub_roles, \@$all_roles );
            @$roles_id = @$r_ids;
        }
    }    #EXIT
    return \@$roles_id;
}
##############################################################################

=head2 table_views 

  This subroutine creates views for the tables in the user schema. The views
  are created only for these table which are defined with the select rights 
  in the user access rights view.

=cut

sub table_views {
    my ( $user, $myuser_marker, $from_interface ) = @_;
    my @all_tables;
    my %arview_data = ();
    my $i           = 1;

    EXIT: {
        ### creates array with all table names allowed for the user (for select action) ###
        my $queriedtable = "v_dbtar_" . $user;
        my $sql          =
            "SELECT table_name,table_columns,descriptor_name,descriptor_value 
             FROM $user.$queriedtable WHERE sqlaction='select'";
        my $fetched = $apiis->DataBase->sys_sql($sql);
        if ( $fetched->status ) {
            $apiis->errors( $fetched->errors );
            $apiis->status(1);
            last EXIT;
        }

        while ( my $ret_table = $fetched->handle->fetch ) {
            my $tablename = $ret_table->[0];
            my @tabcolumns = split ',', $ret_table->[1];
            my %tmp_hash;
            $tmp_hash{table_columns}    = [@tabcolumns];
            $tmp_hash{descriptor}       = $ret_table->[2];
            $tmp_hash{descriptor_value} = $ret_table->[3];
            #$tmp_hash{sql_action} = $ret_table->[4];
            $arview_data{$tablename}{$i} = {%tmp_hash};
            $i++;
            push @all_tables, $tablename
                unless ( grep /^$tablename$/, @all_tables );
        }
        ### creates view for each table ###
        my @view_sqls;
        foreach my $table (@all_tables) {
            #next unless ($table eq 'languages');
            my $drop_view = "$table";
            drop_view( $drop_view, $user );
            if ( $apiis->status ) {
                my $msg_1 =
                    __( "View [_1] not dropped from the [_2] user schema",
                    $drop_view, $user );
                print "\nER: $msg_1" unless ( defined $from_interface );
                last EXIT;
            }
            else {
                my $msg_1 = __( "View [_1] dropped from the [_2] user schema",
                    $drop_view, $user );
                print "\nOK: $msg_1"
                    if ( $debug > 1 and not defined $from_interface );
            }
            my ( $tab1, $tab2, $str_maincolumns ) =
                main_columns( $table, \%arview_data );
            last EXIT if ( $apiis->status );

            my @tab_maincolumns            = @{$tab1};
            my @columns_for_selects        = @{$tab2};
            my $sorted_columns_for_selects =
                sorting_columns( \@tab_maincolumns, \@columns_for_selects );
            my $view_sql =
                creates_table_view( $user, $myuser_marker, $table,
                $str_maincolumns, \%$sorted_columns_for_selects );
            last EXIT if ( $apiis->status );
            if ( $apiis->status ) {
                my $msg_2 =
                    __( "View [_1] not corectly prepareds for creation",
                    $drop_view );
                print "\nER: $msg_2" unless ( defined $from_interface );
                last EXIT;
            }
            else {
                my $msg_2 =
                    __( "View [_1] corectly prepareds to creation",
                    $drop_view );
                print "\nOK: $msg_2"
                    if ( $debug > 1 and not defined $from_interface );
            }
            my $grant_sql = "GRANT SELECT ON $user.$table to $user";
            push @view_sqls, $view_sql, $grant_sql;
        }
        my $sql_1 = "GRANT ALL ON SCHEMA $user to $user";
        #my $sql_2 = "REVOKE create ON SCHEMA $user FROM $user";
        push @view_sqls, $sql_1;

        foreach my $sql (@view_sqls) {
            my $fetched = $apiis->DataBase->sys_sql($sql);
            if ( $fetched->status ) {
                $apiis->errors( $fetched->errors );
                $apiis->status(1);
                last EXIT;
            }
        }
    }    #EXIT@mcolumns
    if ( !$apiis->status ) {
        my $msg_3 = __("System of views (re)created");
        print "\nOK: $msg_3" unless ( defined $from_interface );
    }
    else {
        my $msg_4 = __("System of views not (re)created");
        print "\nER: $msg_4" unless ( defined $from_interface );
    }
    return;
}
##############################################################################

=head2 drop_view 

  This subroutine drop defined view from the user schema.

=cut

sub drop_view {
    my ( $view, $user ) = @_;

    EXIT: {
        ### Check if the view is existing ###
        my $sql =
            "SELECT relname FROM pg_catalog.pg_class JOIN pg_catalog.pg_namespace 
              ON (relnamespace = pg_namespace.oid) 
                WHERE relname='$view' and nspname='$user'";
        my $fetched = $apiis->DataBase->sys_sql($sql);
        if ( $fetched->status ) {
            $apiis->errors( $fetched->errors );
            $apiis->status(1);
            last EXIT;
        }
        my $ret_rel = $fetched->handle->rows;
        if (defined $ret_rel and $ret_rel != 0) {
            my $sql_0     = "DROP VIEW $user.$view CASCADE";
            my $fetched_0 = $apiis->DataBase->sys_sql($sql_0);
            if ( $fetched_0->status ) {
                $apiis->errors( $fetched_0->errors );
                $apiis->status(1);
                last EXIT;
            }
        }
    }    #EXIT
    return;
}
##############################################################################

=head2 main_columns
 
  This subroutine creates main list of column for the current table . Only these column names 
  are taken to the list, to which user have access rights. This list is needed to 
  creates structure of view via UNION (we have to have list of all columne which will be in the 
  view). 

=cut

sub main_columns {
    my ( $table, $data ) = @_;
    my @mcolumns;
    my $entrytab       = $table;
    my %data_from_view = %$data;
    my @set_of_columns = ();

    EXIT: {
        $entrytab =~ s/(.*entry_)(.*)$/$2/ if ( $table =~ /entry_/ );
        ### check if the table is existing in the modelfile ###
        my $modeltable = $apiis->Model->table($entrytab);
        if ( !$modeltable ) {
            my $msg =
                __( "There is no table '[_1]' in the modelfile", $entrytab );
            $apiis->status(1);
            $apiis->errors(
                Apiis::Errors->new(
                    type      => 'DB',
                    severity  => 'ERR',
                    from      => 'Apiis::Auth::AR_View::main_columns',
                    msg_short => $msg,
                )
            );
            last EXIT;
        }

        foreach my $data_frv_table ( keys %data_from_view ) {
            if ( $data_frv_table eq $entrytab ) {
                foreach
                    my $data_frv ( keys %{ $data_from_view{$data_frv_table} } )
                {
                    my $data_frv_desc =
                        $data_from_view{$data_frv_table}{$data_frv}{descriptor};
                    my $data_frv_descv =
                        $data_from_view{$data_frv_table}{$data_frv}
                        {descriptor_value};
                    my @data_frv_columns =
                        @{ $data_from_view{$data_frv_table}{$data_frv}
                            {table_columns} };
                    #my $data_frv_sqlact = $data_from_view{$data_frv_table}{$data_frv}{sql_action};
                    ### praparing data which are needed to select for each set of columns ###
                    my %tmp_hash_2 = ();
                    %tmp_hash_2 = (
                        descriptor_column => [@data_frv_columns],
                        descriptor_name   => $data_frv_desc,
                        descriptor_value  => $data_frv_descv,
                    );
                    push @set_of_columns, \%tmp_hash_2;
                    ### praparing a list of main columns needed to create view structure
                    foreach my $data_frv_column (@data_frv_columns) {
                        unless ( grep /^$data_frv_column$/, @mcolumns ) {
                            if ( $data_frv_column eq $apiis->DataBase->rowid ) {
                                push @mcolumns, $data_frv_column;
                            }
                            else {
                                if ( $modeltable->column($data_frv_column) ) {
                                    push @mcolumns, $data_frv_column;
                                }
                                else {
                                    my $msg = __(
                                        "There is no column '[_1]' in the table [_2]",
                                        $data_frv_column, $entrytab
                                    );
                                    $apiis->status(1);
                                    $apiis->errors(
                                        Apiis::Errors->new(
                                            type     => 'DB',
                                            severity => 'ERR',
                                            from     =>
                                                'Apiis::Auth::AR_View::main_columns',
                                            msg_short => $msg,
                                        )
                                    );
                                    last EXIT;
                                }
                            }    #eq oid
                        }    #unless
                    }    #foreach column
                }
            }    #if table form hash eq $table
        }    #foreach $data_frv_table
        my $str_mcolumns = join( ',', @mcolumns );
        return \@mcolumns, \@set_of_columns, $str_mcolumns;
    }    #EXIT
}
##############################################################################

=head2 sorting_columns 

  This subroutine compares list of the main columns with the set of columns for each descriptor. 
  Columns list is created for each descriptor. Columns order have to be the same like the order
  of columns on main list. Value NULL is putted to the list if some column doesn't 
  occure on the main list.

=cut

sub sorting_columns {
    my ( $main_columns, $descriptor_columns ) = @_;
    my %sorted_columns = ();
    my @unique_set_columns;

    foreach my $descriptor_data ( @{$descriptor_columns} ) {
        my @temp;
        my $desccolumns =
            join( ',', @{ $descriptor_data->{descriptor_column} } );
        my $descname  = $descriptor_data->{descriptor_name};
        my $descvalue = $descriptor_data->{descriptor_value};
        my %tmp_hash;
        %tmp_hash = (
            DESCRIPTOR_COLUMNS => '',
            DESCRIPTOR_NAME    => $descname,
            DESCRIPTOR_VALUE   => $descvalue,
        );

        if ( grep /^$desccolumns$/, @unique_set_columns ) {
            push @{ $sorted_columns{$desccolumns} }, \%tmp_hash;
        }
        else {
            push @unique_set_columns, $desccolumns;
            foreach my $maincolumn ( @{$main_columns} ) {
                if ( $desccolumns =~ m/$maincolumn/ ) {
                    push @temp, $maincolumn;
                }
                else {
                    push @temp, 'NULL';
                }
            }
            my $string = join( ',', @temp );
            $tmp_hash{DESCRIPTOR_COLUMNS} = $string;
            my @descriptor_list;
            push @descriptor_list, \%tmp_hash;
            $sorted_columns{$desccolumns} = [@descriptor_list];
        }
    }
    #print Dumper(%sorted_columns);
    return \%sorted_columns;
}
##############################################################################

=head2 creates_view 

  This subroutine creates view for the current table.

=cut

sub creates_table_view {
    my ($user_view,       $user_marker, $table_name,
        $str_maincolumns, $sorted_columns
        )
        = @_;
    my $system_user         = $apiis->Model->db_user;
    my %sorted_columns_hash = %$sorted_columns;
    my $sql_view            =
        "CREATE VIEW $user_view.$table_name AS SELECT $str_maincolumns 
                    FROM $system_user.$table_name
                    WHERE owner=NULL
            ";
    EXIT: {
        foreach my $sort ( keys %sorted_columns_hash ) {
            my @mytable = @{ $sorted_columns_hash{$sort} };
            my $where_clause;
            ### parsing of decsriptors for the where clause ###
            my ( $ret_where_hash, $columns ) =
                create_views_where_clause( $user_marker, \@mytable );
            ### create where clause ###
            foreach my $descname ( keys %{$ret_where_hash} ) {
                my $where_element = "("
                    . join( ' OR ', @{ $ret_where_hash->{$descname} } ) . ")";
                if ($where_clause) {
                    $where_clause =
                        join( ' AND ', $where_clause, $where_element );
                }
                else {
                    $where_clause = $where_element;
                }
            }
            my $sql_ext =
                "UNION  SELECT $columns FROM  $system_user.$table_name WHERE $where_clause";
            $sql_view = join( ' ', $sql_view, $sql_ext );
        }
        return $sql_view;
    }    #EXIT
}
##############################################################################

=head2 creates_views_where_clause 

  This subroutine parses descriptors for the where clause.

=cut

sub create_views_where_clause {
    my ( $user_marker, $descriptors_table ) = @_;
    my %where_hash;
    my $mycolumns;

    EXIT: {
        foreach my $myhash ( @{$descriptors_table} ) {
            $mycolumns = $myhash->{DESCRIPTOR_COLUMNS}
                if ( not defined $mycolumns );
            my $descriptor       = $myhash->{DESCRIPTOR_NAME};
            my $descriptor_value = $myhash->{DESCRIPTOR_VALUE};
            ### the values of the descriptor can be defined as a list ###
            my @descriptor_values_1 = split ',', $descriptor_value;
            ### if the value of the descriptor is empty then set on NULL ###
            push @descriptor_values_1, 'NULL' unless (@descriptor_values_1);

            foreach my $descriptor_value_1 (@descriptor_values_1)
            {    #foreach value from the descriptor list
                if ( $descriptor_value_1 =~ m/\(=\)(.*)/ )
                {    #if the operator is defined as (=)
                    my $value = $1;
                    if ( $value eq 'NULL' )
                    {    #if the descriptor value is set as NULL
                        push @{ $where_hash{$descriptor} },
                            "$descriptor is $value";
                    }
                    elsif ( $value eq 'SELF_FILLER' ) {
                        #           my $your_marker;
                        #           if ($admin_defined){
                        #             $your_marker = $apiis->User->user_marker;
                        #           }
                        #           else{
                        #             $your_marker = $user_marker;
                        #           }
                        push @{ $where_hash{$descriptor} },
                            "$descriptor='$user_marker'";
                        #push @descriptor_values_2, $descriptor_value_1;
                    }
                    else {
                        push @{ $where_hash{$descriptor} },
                            "$descriptor='$value'";
                        #push @descriptor_values_2, $descriptor_value_1;
                    }
                }
                elsif ( $descriptor_value_1 =~ m/\(>\)(.*)/ )
                {    #if the operator is defined as (>)
                    my $value = $1;
                    if ( $value =~ /^\d+$/ )
                    {    #check if the element of valu is defined as a number
                        push @{ $where_hash{$descriptor} },
                            "$descriptor>'$value'";
                    }
                    else {
                        my $msg = __("Descriptor definition is wrong defined");
                        my $msg_1 = __(
                            "Values of descriptor are not a numbers and can not be put 
                        to the where clause with '>' operator: '[_1]'",
                            $descriptor_value_1
                        );
                        $apiis->status(1);
                        $apiis->errors(
                            Apiis::Errors->new(
                                type     => 'DB',
                                severity => 'ERR',
                                from     =>
                                    'Apiis::Auth::AccessControl::creates_table_view',
                                msg_short => $msg,
                                msg_long  => $msg_1,
                            )
                        );
                        last EXIT;
                    }
                }
                elsif ( $descriptor_value_1 =~ m/\(<\)(.*)/ )
                {    #if the operator is defined as (<)
                    my $value = $1;
                    if ( $value =~ /^\d+$/ )
                    {    #check if the element of valu is defined as a number
                        push @{ $where_hash{$descriptor} },
                            "$descriptor<'$value'";
                    }
                    else {
                        my $msg = __("Descriptor definition is wrong defined");
                        my $msg_1 = __(
                            "Values of descriptor are not a numbers and can not be put
                        to the where clause with '<' operator: '[_1]'",
                            $descriptor_value_1
                        );
                        $apiis->status(1);
                        $apiis->errors(
                            Apiis::Errors->new(
                                type     => 'DB',
                                severity => 'ERR',
                                from     =>
                                    'Apiis::Auth::AccessControl::creates_table_view',
                                msg_short => $msg,
                                msg_long  => $msg_1,
                            )
                        );
                        last EXIT;
                    }
                }
                elsif ( $descriptor_value_1 =~ m/(.*)\(><\)(.*)/ )
                {    #if the descriptor value is defined as a range
                    my $range;
                    my $first  = $1;
                    my $second = $2;
                    if ( $first =~ /^\d+$/ and $second =~ /^\d+$/ )
                    {    #check if the element of valu is defined as a number
                        if ( $first < $second ) {
                            $range =
                                "($descriptor>$first AND $descriptor<$second)";
                        }
                        elsif ( $first > $second ) {
                            $range =
                                "($descriptor>$second AND $descriptor<$first)";
                        }
                        elsif ( $first == $second ) {
                            $range = "$descriptor=$first";
                        }
                    }
                    else {
                        my $msg = __("Descriptor definition is wrong defined");
                        my $msg_1 =
                            __( "Range values are not a numbers: '[_1]'",
                            $descriptor_value_1 );
                        $apiis->status(1);
                        $apiis->errors(
                            Apiis::Errors->new(
                                type     => 'DB',
                                severity => 'ERR',
                                from     =>
                                    'Apiis::Auth::AccessControl::creates_table_view',
                                msg_short => $msg,
                                msg_long  => $msg_1,
                            )
                        );
                        last EXIT;
                    }
                    push @{ $where_hash{$descriptor} }, "$range";
                }
                else {    #if the descriptor operator is not defined
                    my $msg   = __("Operator of descriptor not defined");
                    my $msg_1 = __(
                        "(=),(<),(>),(><) - one of these opeartors has 
                      to be defined with the descriptor value. 
                      Current value is defined as: '[_1]'", $descriptor_value_1
                    );
                    $apiis->status(1);
                    $apiis->errors(
                        Apiis::Errors->new(
                            type     => 'DB',
                            severity => 'ERR',
                            from     =>
                                'Apiis::Auth::AccessControl::creates_table_view',
                            msg_short => $msg,
                            msg_long  => $msg_1,
                        )
                    );
                    last EXIT;
                }
            }
        }
        return \%where_hash, $mycolumns;
    }    #EXIT
}
##############################################################################

=head2 

B<entry_views> -- This subroutine is used to create entry views under user schema.

=cut

sub entry_views {
    my $user_schema = shift;
    my @views_to_create;

    EXIT: {
        foreach ( keys %{ $apiis->entry_views } ) {
            my $sql =
                "CREATE VIEW $user_schema."
                . ${ $apiis->entry_views }{$_} . " 
               AS SELECT * 
                  FROM $user_schema.$_
                  WHERE closing_dt IS NULL
              ";
            push @views_to_create, $sql;

            my $sql_1 =
                "GRANT SELECT ON $user_schema."
                . ${ $apiis->entry_views }{$_} . " 
                 TO $user_schema
                ";
            push @views_to_create, $sql_1;
        }
        foreach (@views_to_create) {
            my $fetched = $apiis->DataBase->sys_sql($_);
            if ( $fetched->status ) {
                $apiis->errors( $fetched->errors );
                $apiis->status(1);
                last EXIT;
            }
        }
    };    #EXIT
    if ( !$apiis->status ) {
        my $msg_1 = __("Entry views created");
        print "\nOK: $msg_1";
    }
    else {
        my $msg_2 = __("Entry views not created");
        print "\nER: $msg_2";
    }
    return;
}
##############################################################################

=head2 v_views

this code was copied from MakeSQL.pm module and partialy changed.
This subroutine is used to create "v_" view under user schema.

Note (2008-04-08 heli):
As MakeSQL changed to allow self-referencing foreign keys I also had to change
this part of it. :^(

=cut

sub v_views {
    my $user_schema = shift;
    my @views_to_create;
    use vars qw/ $tab_alias %tab_trans %tmp_hash
        @join_tables_pre @join_alias_pre @join_cols_pre
        @join_tables_post @join_alias_post @join_cols_post
        /;

    my @tables;
    my $tab_sql =
        "SELECT distinct table_name from $user_schema.v_dbtar_$user_schema 
                     WHERE sqlaction='select'";
    my $fetched_tab = $apiis->DataBase->sys_sql($tab_sql);
    if ( $fetched_tab->status ) {
        $apiis->errors( scalar $fetched_tab->errors );
        $apiis->status(1);
        return;
    }
    while ( my $row = $fetched_tab->handle->fetch ) {
        push @tables, $row->[0];
    }

    my ( $create, $columns, @sql_arr, @pk_views, %pk_index );
    TABLE:
    foreach my $tab (@tables) {
        my $table = $apiis->Model->table($tab);
        my $create_view;
        $columns = scalar @{ $table->cols };    # get number of columns

        my $max_db_column = 0;
        my $max_datatype  = 0;
        my @table_columns = $table->cols;
        foreach my $col (@table_columns) {
            my $meta_datatype = $table->datatype($col);
            $max_db_column = length($col) if length($col) > $max_db_column;
            $max_datatype = length( $apiis->DataBase->datatypes($meta_datatype))
                if length( $apiis->DataBase->datatypes($meta_datatype) )
                > $max_datatype;
        }
        $max_db_column += 2;    # add to max length
        $max_datatype  += 2;

        my ( @view_selects, @left_outer_joins );
        $tab_alias = 'a';
        $tab_trans{$tab} = $tab_alias;

        $create_view .= "CREATE VIEW $user_schema.v_$tab AS\nSELECT ";
        push @view_selects,
            "$tab_trans{$tab}" . '.'
            . $apiis->DataBase->rowid
            . ' AS v_'
            . $apiis->DataBase->rowid;

        if ( $table->primarykey('ref_col') ) {
            if ( $table->primarykey('view') ) {
			#	die "Can't create view %s ! Table with same name defined.\n",
			#		 $table->primarykey('view')
            #        if defined $table->primarykey('view');
                push @pk_views,
                    "CREATE VIEW " . $table->primarykey('view') . " AS";

                my @tmp_arr;
                push @tmp_arr, $table->cols;
                my $myrowid = $apiis->DataBase->rowid;
                push @tmp_arr, $myrowid if !( grep /^$myrowid$/, @tmp_arr );

                my $where_clause = '';
                $where_clause = sprintf "\nWHERE       %s",
                    $table->primarykey('where')
                    if $table->primarykey('where');
                push @pk_views, sprintf "SELECT      %s\nFROM        %s\n",
                    join( ', ', @tmp_arr ), $tab . $where_clause;
            }
        }    # end PRIMARYKEY

        my $ar_sql = sprintf "SELECT table_columns FROM %s.v_dbtar_%s "
                           . "WHERE table_name='%s'"
                           . "AND sqlaction='select'",
                     $user_schema, $user_schema, $tab;
        my $fetched = $apiis->DataBase->sys_sql($ar_sql);
        if ( $fetched->status ) {
            $apiis->errors( scalar $fetched->errors );
            $apiis->status(1);
            last TABLE;
        }
        my $row             = $fetched->handle->fetch;
        my $ar_columns      = $row->[0];
        my @allowed_columns = split /\|/, $ar_columns;

        my @exclude_cols = qw( last_change_dt last_change_user dirty chk_lvl
            guid owner version creation_dt creation_user end_dt end_user
            opening_dt opening_user);

        COLUMN:
        foreach my $col (@table_columns) {
            next COLUMN if grep /^${col}$/, @exclude_cols;
            next COLUMN if ( !( grep /$col/, @allowed_columns ) );

            my $db_column = $col;
            $tmp_hash{ ${tab} . ${db_column} }++;
            my $datatype =
                $apiis->DataBase->datatypes( lc $table->datatype($col) );

            $create .= "   $db_column"
                . ' ' x ( $max_db_column - length($db_column) );
            $create .= "$datatype";
            $columns > 1 ? ( $create .= "," ) : ( $create .= " " );
            $create .= ' ' x ( $max_datatype - length($datatype) );
            $create .= "\n";
            $columns--;

            push @view_selects, "$tab_trans{$tab}.${db_column}";
            my ( $fk_table, $fk_col ) = HasFKRule( $tab, $col );

            if ( $fk_table and $fk_col ) {
                ( $fk_table, $fk_col ) = Cascaded_FK( $fk_table, $fk_col );
            }

            if ( $fk_table and $fk_col ) {
                my ( @fk_tables, @fk_cols, @table_aliases );
                push @fk_tables, $fk_table;
                push @fk_cols,   $fk_col;

                $tab_trans{$fk_table} = ++$tab_alias
                    unless exists $tab_trans{$fk_table};

                @join_tables_pre  = ($tab);
                @join_alias_pre   = ( $tab_trans{$tab} );
                @join_cols_pre    = ($db_column);
                @join_tables_post = ($fk_table);
                @join_alias_post  = ( $tab_trans{$fk_table} );
                @join_cols_post   = ($fk_col);

                my $new_db_col = $db_column;
                $new_db_col =~ s/^db_/ext_/i;
                $new_db_col = 'ext_' . $new_db_col
                    unless ( $new_db_col =~ /^ext_/i );
                push @table_aliases, $tab_trans{$fk_table};

                my $has_concat_pk = 0;

                resolve_concatenations( \@fk_tables, \@fk_cols, \@table_aliases )
                    if !( $fk_table eq $apiis->codes_table );

                my $delimiter = ${ $apiis->reserved_strings }{v_concat};
                for ( my $i = 0; $i <= $#fk_cols; $i++ ) {

                    #-- mue see explanation in MakeSQL 
                    if (($fk_tables[$i] eq 'codes') or ($fk_tables[$i] eq 'units') or ($fk_tables[$i] eq 'transfer')) {
                        $fk_cols[$i] =~ s/^db_/ext_/;
                    }

                    $fk_cols[$i] = $table_aliases[$i] . '.' . $fk_cols[$i];
                }
                push @view_selects,
                    join( " || '$delimiter' || ", @fk_cols )
                    . " AS $new_db_col";

                for ( my $i = 0; $i <= $#join_tables_pre; $i++ ) {
                    push @left_outer_joins,
                        sprintf 'LEFT OUTER JOIN %s %s ON %s.%s = %s.%s',
                        $user_schema . '.' . $join_tables_post[$i],
                        $tab_trans{ $join_tables_post[$i] },
                        $join_alias_pre[$i], $join_cols_pre[$i],
                        $tab_trans{ $join_tables_post[$i] },
                        $join_cols_post[$i];
                }
            }    # end FK exists
        };    #end COLUMN

        $create_view .= join( ",\n       ", @view_selects );
        # A self-referencing FK makes $tab_trans{$table} overwrite the
        # alias. We have to hardcode it in the FROM-clause:
        $create_view .= "\nFROM $user_schema.$tab a";
        my $tmp_count  = 0;
        my $thislength = length("FROM $user_schema.$tab x");
        while (@left_outer_joins) {
            if ($tmp_count) {
                $create_view
                    .= "\n" . ' ' x $thislength . ' ' . shift @left_outer_joins;
            }
            else {
                $create_view .= ' ' . shift @left_outer_joins;
                $tmp_count++;
            }
        }

        my $grant_sql = "GRANT SELECT ON $user_schema.v_$tab TO $user_schema";
        push @views_to_create, $create_view, $grant_sql;
    };    #TABLE

    foreach (@views_to_create) {
        my $fetched = $apiis->DataBase->sys_sql($_);
        if ( $fetched->status ) {
            $apiis->errors( scalar $fetched->errors );
            $apiis->status(1);
            last;
        }
    }

    if ( $apiis->status ) {
        my $msg_2 = __("v_ views not created");
        print "\nERR: $msg_2\n";
    }
    else {
        my $msg_1 = __("v_ views created");
        print "\nOK: $msg_1\n";
    }
    return;
}
##############################################################################
1;

__END__

=head1 AUTHOR

 Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut
