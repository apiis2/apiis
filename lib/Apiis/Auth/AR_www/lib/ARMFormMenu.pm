package ARM::ARMFormMenu;
##############################################################################
# $Id: ARMFormMenu.pm,v 1.4 2009-05-12 13:21:19 duchev Exp $
##############################################################################

=head1 NAME

ARM::ARMSubroutines

=head1 SYNOPSIS

 This module is responsible for showing menu on the form.

=head1 DESCRIPTION

 long description of your module

=head1 SEE ALSO

 need to know things before somebody uses your program
use strict;

=head1 METHODS

=cut

##############################################################################
use Apiis::Init;
##############################################################################

sub get {

    my @form_menu = (
        {    # USER
            tab_name   => sub          { return __("Users"); },
            default    => "users",
            user       => [ "GENERAL", "1" ],
            user_roles => [ "GENERAL", "2" ],
        },
        {    # ROLE
            tab_name  => sub          { return __("Roles"); },
            default   => "st_roles",
            st_roles  => [ "GENERAL", "1" ],
            dbt_roles => [ "GENERAL", "2" ],
        },
        {    # POLICIES
            tab_name     => sub          { return __("Policies"); },
            default      => "st_policies",
            st_policies  => [ "GENERAL", "1" ],
            dbt_policies => [ "GENERAL", "2" ],
        },
    );

    # core for main subroutine
    my @level1;
    my @level2;

    foreach (@form_menu) {
        my @tmp_array;
        foreach my $key ( keys %{$_} ) {
            if ( $key eq "tab_name" ) {
                push( @level1, &{ $_->{$key} } );
            }
            elsif ( $key eq "default" ) {
                $tmp_array[0] = $_->{$key};
            }
            else {
                $tmp_array[ $_->{$key}->[1] ] = $key;
            }
        }
        push( @level2, [@tmp_array] );
    }
    return \@level1, \@level2;
}

=head2 labels

 input: none
 output: referenc to hash with translated messages for web forms menu

=cut

sub labels {

    my $key = shift || undef;
    my %labels = (
        user         => sub { return __("User Data"); },
        user_roles   => sub { return __("User Roles"); },
        st_roles     => sub { return __("System Roles"); },
        dbt_roles    => sub { return __("Database Roles"); },
        st_policies  => sub { return __("System Task Policies"); },
        dbt_policies => sub { return __("Database Task Policies"); },
    );

    my %new_labels;

    if ( defined $key ) {
        $new_labels{$key} = &{ $labels{$key} };
    }
    else {
        while ( ( $key, $value ) = each %labels ) {
            $new_labels{$key} = &{$value};
        }
    }
    return \%new_labels;
}

=head2 tab_menu


=cut

sub tab_menu {
    my $level1 = shift;
    my $level2 = shift;
    my $action = shift || undef;
    my $current_tab;
    my $i = 0;
    $action = "st_roles" if ( $action eq "role" );

    if ( defined $action ) {
        foreach ( @{$level2} ) {
            foreach ( @{ $$level2[$i] } ) {
                if ( $_ eq $action ) { $current_tab = $i; }
            }
            $i++;
        }
    }
    else {
        $current_tab = 0;
    }

    $i = 0;
    my @tab_menu1;
    foreach ( @{$level1} ) {
        my %tmp_hash;
        $tmp_hash{"action"} =
            "javascript:go_next_arm(\'" . $$level2[$i][0] . "\')";    #}
        $tmp_hash{"label"} = $$level1[$i];
        if ( $current_tab == $i ) {
            $tmp_hash{"class"} = "active";
        }
        else {
            $tmp_hash{"class"} = "non_active";
        }
        push( @tab_menu1, \%tmp_hash );
        $i++;
    }

    $i = 0;
    my @tab_menu2;
    if ( defined $current_tab ) {
        foreach ( @{ $$level2[$current_tab] } ) {
            my %tmp_hash;
            if ( ( $i != 0 ) and defined $_ ) {
                $tmp_hash{"action"} = "javascript:go_next_arm(\'" . $_ . "\')";
                my ( $key, $value ) = each %{ labels($_) };
                $tmp_hash{"label"} = $value;
                $tmp_hash{"class"} = "non_active";
                push( @tab_menu2, \%tmp_hash );
            }
            $i++;
        }
    }
    return \@tab_menu1, \@tab_menu2;
}
##############################################################################

1;

=head1 AUTHOR

Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>
Lucjan Soltys <soltys@tzv.fal.de>

=cut

__END__
