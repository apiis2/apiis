##############################################################################
# $Id: User.pm,v 1.12 2011-10-13 13:49:42 ulm Exp $
##############################################################################
package Apiis::DataBase::User;
$VERSION = '$Revision ';
##############################################################################

=head1 NAME

Apiis::DataBase::User -- collecting and providing user data

=head1 SYNOPSIS

   my $usr_obj = Apiis::DataBase::User->new( id => <userid>, %args );

=head1 DESCRIPTION

To create a new User object, we need at least a user id.
A User object is created and returned.

   my $usr_obj = Apiis::DataBase::User->new( id => <userid> );

Other parameters can be passed to fill the object at creation time:

   my $usr_obj = Apiis::DataBase::User->new(
      id       => <userid>,
      password => <top_secret>,
   );

When you run

   $apiis->join_user( user_obj => $this_obj, %args );

the User object $this_obj is joined into the $apiis structure. This can happen
only once as only one user can run a program at a time. If no user_obj is passwd,
join_user falls back to ask for login data by itself.

Nevertheless is it possible, to create other User object, e.g. to insert a new 
user into the database.

With

   my $user_obj = $apiis->DataBase->user( <userid> );

you can retrieve all user information, stored in the database, into a User object.

=head1 TODO

Maybe we get some class Apiis::Person later, whereof Apiis::DataBase::User is a
subclass. So User should be restricted to the data which is needed for database
connection (authentication and authorisation), whilst other personal data like name,
address, etc. should be retrieved from the unit/naming/address setup via some foreign
key. In table users, column login will then become the primary key (enforce uniqueness)
and user_id could point to unit (or somewhere else).

=head1 METHODS

=cut

##############################################################################

use strict;
use warnings;
use Carp;
use Apiis::Init;
use Apiis::DataBase::Record;
use Term::ReadKey;
use Digest::MD5 qw(md5_base64);
use Data::Dumper;

@Apiis::DataBase::User::ISA = qw/ Apiis::Init /;

{    # private class data and methods to leave the closure:
   my $__passwd;
   sub __passwd {
      my ( $package, $file, $line ) = caller;
      if ( $package eq 'Apiis::DataBase::User' ) {
         # TODO: still does not work if caller prepends to be package
         # Apiis::Init::User
         $__passwd = $_[1] if $_[1];
         return $__passwd;
      } else {
         print ":^(\n";
      }
   }

   my @methods = qw{ id user_id password authenticated
                 user_node session_id lang_id language roles
                 user_marker user_session_id user_language_id
                 };
    my %_attr_data = map { '_' . $_ => undef } @methods;

   sub _standard_keys { keys %_attr_data; }    # attribut names:
   sub methods {
      wantarray && return @methods;
      return \@methods;
   }

}    # end private class data:
##############################################################################

=head2 new (public)

B<new()> returns an object reference for a new User object.

=cut

sub new {
    my ( $invocant, %args ) = @_;
    my ( $local_status, @errors );
    croak __( "Missing initialisation in main file ([_1]).", __PACKAGE__ )
        . "\n" if !defined $apiis;
    my $class = ref($invocant) || $invocant;
    my $self = bless {}, $class;

    EXIT: {
        if ( !exists $args{'id'} ) {
            $self->status(1);
            my ( $pack, $file, $line ) = caller;
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::DataBase::User::new',
                    msg_short => __( "Parameter missing: [_1]", 'id' ),
                    backtrace => "Called from package $pack, $file line $line",
                )
            );
            last EXIT;
        }

        # is the id empty:
        my $id = $args{'id'};
        if ( !$id ) {
            $self->status(1);
            my ( $pack, $file, $line ) = caller;
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::DataBase::User::new',
                    msg_short => __("Empty id passed"),
                    backtrace => "Called from package $pack, $file line $line",
                )
            );
            last EXIT;
        }

        # creating of the methods should not be in new:
        THISKEY:
        for my $thiskey ( $self->_standard_keys() ) {
            my $method = $thiskey;
            $method =~ s/^_//;
            if ( $method eq 'password' ) {
                $self->password( $args{$method} ) if exists $args{$method};
            }
            else {
                $self->{$thiskey} = $args{$method} if exists $args{$method};
            }

            # to avoid 'Subroutine xxx redefined' messages
            next THISKEY if $self->can("$method");

            # create anon methods:
            no strict 'refs';
            *$method = sub {
                my ( $self, $value ) = @_;
                $self->{$thiskey} = $value if defined $value;
                return $self->{$thiskey};
            };
        }

        $self->language( $apiis->language ) unless $self->language;    # default
        $apiis->log( 'debug', "Created new user object with id '$args{'id'}'" );
    }    # end label EXIT
    return $self;
}

##############################################################################

=head2 roles (public)

$usr_obj->roles returns the roles of this user either as an array or an
arrayreference.
Roles are stored here by:

   $usr_obj->roles( \@these_roles );
   or
   $usr_obj->roles( 'role1', 'role2', 'roleN' );

=cut

sub roles {
   # stores an array:
   my ( $self, @values ) = @_;
   if ( scalar @values == 1 and ref $values[0] eq 'ARRAY' ){
      $self->{'_roles'} = $values[0];
   } else {
      $self->{'_roles'} = \@values if @values;
   }
   if ( $self->{'_roles'} ) {
      wantarray && return @{ $self->{'_roles'} };
      return $self->{'_roles'};
   }
   return undef;
}
##############################################################################

=head2 password

   $usr_obj->password
   
returns the encrypted password. If a new password is passed with

   $usr_obj->password( <new_password> );

this password is first encrypted and then stored. If you want to store an already
encrypted password (like one from the database) you have to invoke it

   $usr_obj->password( <new_password>, encrypted => 1 );

=cut

sub password {
   my ( $self, $value, %args ) = @_;
   if ( defined $value ) {
      if ( exists $args{'encrypted'} and $args{'encrypted'} ) {
         $self->{'_password'} = $value;
      } else {
         $self->__passwd($value); # store internally in cleartext
                                  # security by obscurity :^(
         $self->{'_password'} = md5_base64($value);
      }
   } else {
      return $self->{'_password'};
   }
}
##############################################################################

# Hmmm, I don't like to make the password public, but we need it at database 
# connection. TODO: some paranoia should be added later.
sub _passwd {
   my $self = shift;
   my ( $package, $file, $line ) = caller;
   if ( $package eq 'Apiis::DataBase::Init' ) {
      # TODO: still does not work if caller prepends to be package
      # Apiis::DataBase::Init
      return $self->__passwd;
   } else {
      $self->status(1);
      $self->errors(
         Apiis::Errors->new(
            type      => 'AUTH',
            severity  => 'CRIT',
            from      => 'Apiis::DataBase::User::__passwd',
            msg_short => __( "Calling '[_1]' from package '[_2]' is prohibited!",
               '_passwd', $package
            ),
         )
      );
   }
}
##############################################################################

=head2 authenticated (public)

This is a flag to show successful authentication of this user against his 
database password.

It is read-only to allow setting of this flag only from inside of B<verify_user>

=cut

sub authenticated {
   my ( $self, $flag ) = @_;
   if ( defined $flag ) {
      my ( $package, $file, $line ) = caller;
      if ( $package eq 'Apiis::DataBase::Init' or $package eq 'Apiis::Init' ) {
         $self->{'_authenticated'} = $flag;
      } else {
         $apiis->status(1);
         $apiis->errors(
            Apiis::Errors->new(
               type      => 'AUTH',
               severity  => 'CRIT',
               from      => 'Apiis::DataBase::User::authenticated',
               msg_short => __(
                  "Calling '[_1]' from package '[_2]' is prohibited!",
                  'authenticated',
                  $package
               ),
            )
         );
      }
   }
   return $self->{'_authenticated'};
}

##############################################################################

=head2 print (external)

Return the contents of the User object as a string, nicely formatted.
The elements of this object are printed according to the order of the @methods
array, if they contain data.

=cut

sub sprint {
   my $self   = shift;
   my $maxlen = 15;

   my $string = __("User") . ":\n";
   for ( $self->methods ) {
      if ( defined $self->$_ ) {
         if ( ref $self->$_ eq 'ARRAY' ) {
            $string .= " $_:" . ' ' x ($maxlen - length($_)) . join(' ', $self->$_ ) . "\n";
         } else {
            $string .= " $_:" . ' ' x ($maxlen - length($_)) . $self->$_ . "\n";
         }
      }
   }
   return $string;
}
##############################################################################

=head2 print (external)

Print this user object to STDOUT (default) or the passed filehandle with the
formatting of sprint.

Examples:
  $user_obj->print;
  $user_obj->print( filehandle => *FILE );

=cut

sub print {
   my ( $self, %args ) = @_;
   my $handle;
   no strict 'refs';
   if ( exists $args{'filehandle'} ) {
      # dereference the IO-part of the typeglob:
      $handle = *{ $args{'filehandle'} }{IO};
   } else {
      $handle = 'STDOUT';
   }
   print $handle $self->sprint;
}

##############################################################################


=head2 user_language_id (external)

$usr_obj->user_language_id returns the language id as stored in table ar_users
(new Auth/AR setup).

=cut

sub user_language_id {
    $_[0]->{'_user_language_id'} = $_[1] if defined $_[1];
    return $_[0]->{'_user_language_id'};
}

=head2 lang_id (external)

$usr_obj->lang_id returns the language id as stored in table users (old,
deprecated Auth/AR setup).

=cut

sub lang_id {
    $_[0]->{'_lang_id'} = $_[1] if defined $_[1];
    return $_[0]->{'_lang_id'};
}

=head2 language (external)

$usr_obj->language returns the value of iso_lang from table languages with
the given lang_id. It is preset with $apiis->language as default.

=cut

sub language {
   $_[0]->{'_language'} = $_[1] if defined $_[1];
   return $_[0]->{'_language'};
}
##############################################################################
1;

