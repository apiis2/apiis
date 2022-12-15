##############################################################################
# $Id: Config.pm,v 1.16 2013/09/27 08:08:03 heli Exp $
##############################################################################
package Apiis::Init::Config;

=head1 NAME

Apiis::Init::Config mainly ready apiisrc config files

=head1 DESCRIPTION

Apiis::Init::Config contains internal methods to read the different apiisrc
files.

=head1 METHODS

=cut

use strict;
use warnings;
use Data::Dumper;
use Config::Auto;
use Config::IniFiles;
use Apiis;
use XML::Parser;
our $apiis;


##############################################################################

=head2 _import_apiisrc (internal)

Imports the default apiis config file $APIIS_HOME/etc/apiisrc.

=cut

sub _import_apiisrc {
    my $self          = shift;
    my $apiis_rc_file = $self->{"_APIIS_HOME"} . "/etc/apiisrc";
    die "Cannot read $apiis_rc_file\n" if !-r $apiis_rc_file;

    my $cfg = new Config::IniFiles( -file   => $apiis_rc_file, -nocase => 0 );
    die "Cannot read file $apiis_rc_file or error while parsing.\n" if !$cfg;

    # substitue APIIS_LOCAL, etc. in these sections:
    my $subst_env_in = {
        projects   => 1,
        rapidapiis => 1,
        local      => 1,
    };

    KEY:
    for my $mainkey ( $cfg->Sections ) {
        my $lkey = lc $mainkey;
        if ( $lkey eq 'entry_views' or $lkey eq 'reserved_strings' ) {
            # special cases, they return an array of hash entries
            foreach my $subkey ( $cfg->Parameters($mainkey) ) {
                $self->{ '_' . $lkey }{ lc $subkey } =
                    $cfg->val( $mainkey, $subkey );
                $self->{ '_' . $lkey }{ lc $subkey } =~ s/\s*$//;
            }
            next KEY;
        }

        if ( exists $subst_env_in->{$lkey} ) {
            foreach my $subkey ( $cfg->Parameters($mainkey) ) {
                $self->{"_$lkey"}{$subkey} = $cfg->val( $mainkey, $subkey );
                $self->substitute_env( \$self->{"_$lkey"}{$subkey} );
            }
            next KEY;
        }

        foreach my $subkey ( $cfg->Parameters($mainkey) ) {
            $self->{ lc "_$subkey" } = $cfg->val( $mainkey, $subkey );
            $self->{ lc "_$subkey" } =~ s/\s*$//;
        }
    }    # done config file apiisrc

    $self->{"_apiisrc"} = $apiis_rc_file;
    for my $thisitem (qw/ _sql_logfile _filelog_filename /) {
        $self->substitute_env( \$self->{$thisitem} );
    }
}

##############################################################################

=head2 _import_apiisrc_local (internal)

Overwrites the defaults from apiis apiisrc config file with the
project specific one.

=cut

sub _import_apiisrc_local {
   my $self = shift;
   my $project_rc_file = $self->APIIS_LOCAL . "/etc/apiisrc";
   if ( -r $project_rc_file ){
      my $proj_cfg = new Config::IniFiles( -file   => $project_rc_file, -nocase => 0 );
      die "Cannot read file $project_rc_file or error while parsing the file.\n" unless $proj_cfg;
   
      foreach my $mainkey ( $proj_cfg->Sections ) {
         next if lc $mainkey eq 'projects'; # makes no sense here
         if ( lc $mainkey eq 'entry_views' or lc $mainkey eq 'reserved_strings' ) {
            # special cases, they return an array of hash entries
            foreach my $subkey ( $proj_cfg->Parameters($mainkey) ) {
               $self->{'_' . lc $mainkey}{lc $subkey} = $proj_cfg->val( $mainkey, $subkey );
               $self->{'_' . lc $mainkey}{lc $subkey} =~ s/\s*$//;
            }
         } elsif ( lc $mainkey eq 'local' ){
            foreach my $subkey ( $proj_cfg->Parameters($mainkey) ) {
               $self->{"_local"}{$subkey} = $proj_cfg->val( $mainkey, $subkey );
               $self->substitute_env( \$self->{"_local"}{$subkey} );
            }
         } else {
            foreach my $subkey ( $proj_cfg->Parameters($mainkey) ) {
               $self->{lc "_$subkey"} = $proj_cfg->val( $mainkey, $subkey );
               $self->{lc "_$subkey"} =~ s/\s*$//;
            }
         }
      } # done config file apiisrc
      $self->{"_proj_apiisrc"} = $project_rc_file;
      for my $thisitem ( qw/ _sql_logfile _filelog_filename / ){
         $self->substitute_env( \$self->{$thisitem} );
      }
   }
}

##############################################################################

=head2 _import_user_apiisrc (internal)

Overwrites the project definition from global apiisrc config file.
This can be used for developers on a multiuser server to point to their
private copy of the project tree.

It reads only the [PROJECTS] section of apiisrc.

=cut

sub _import_user_apiisrc {
   my $self = shift;
   if ( $self->os_user and $self->os_user ne 'unknown' ) {
      my ($userhome) = ( getpwnam( $self->os_user ) )[7];
      if ($userhome) {
         my $user_rc_file = $userhome . "/.apiisrc";
         if ( -r $user_rc_file ) {
            my $user_cfg =
              new Config::IniFiles( -file => $user_rc_file, -nocase => 0 );
            die "Cannot read file $user_rc_file or error while parsing the file.\n"
              unless $user_cfg;

            foreach my $mainkey ( $user_cfg->Sections ) {
               next if lc $mainkey ne 'projects';
               foreach my $subkey ( $user_cfg->Parameters($mainkey) ) {
                  $self->{"_projects"}{$subkey} = $user_cfg->val( $mainkey, $subkey );
                  $self->substitute_env( \$self->{"_projects"}{$subkey} );
               }
            }
            $self->{"_user_apiisrc"} = $user_rc_file;
         }
      }
   }
}
##############################################################################
# Does some postprocessing for special cases (substitution of APIIS_HOME and
# APIIS_LOCAL with their values).

sub _substitute_env {
   my ( $self, $var_ref ) = @_;
   $$var_ref =~ /^\s*(\$*APIIS_HOME)(.*)/
     && ( $$var_ref = $self->{"_APIIS_HOME"} . $2 );
   $$var_ref =~ /^\s*(\$*APIIS_LOCAL)(.*)/
     && ( $$var_ref = $self->{"_APIIS_LOCAL"} . $2 );
   $$var_ref =~ s/\s*$//;    # remove trailing blanks
}

##############################################################################

=head2 _xml2model (internal)

B<_xml2model> parses the passed xmlfile and returns a reference to a
datastructure, representing the model file.

usage: 

    eval { $href = $self->Apiis::Init::Config::_xml2model(
                       xmlfile => $filename
                   );
    };

This results in a structure like this:

    $href->{
       general => {...},
       table   => {
          <tablename> => {
             struct_type => '...',
             trigger  => {...},
             sequence => [...],
             index    => [...],
             pk       => {...},
             column   => {
                <columnname> => {...},
                <columnname> => {...},
             },
             _column_order => [...],
          },
       },
       _table_order => [...],
    };

Only for internal use.

Note: This method will disappear in the near future when the model file
structure and parsing is rewritten. 

=cut

sub _xml2model {
   my ( $self, %args ) = @_;
   my $infile     = $args{'xmlfile'};
   our $href = {}; # $href is a reference to the structural hash

   my $xp = XML::Parser->new(
      ParseParamEnt => 1,
      Handlers      => {
         Start => \&start_tag,
      }
   );

   $xp->parsefile($infile);
   return $href;

   sub start_tag {
      my ( $parser, $currentTag, %attr ) = @_;
      our $href;
      my $current_table;
      if ( lc $currentTag eq "general" ) {
         foreach my $attrkey ( keys %attr ) {
            $attr{$attrkey} =~ s/^\s*//;    # remove leading whitespace
            $attr{$attrkey} =~ s/\s*$//;    # remove end whitespace
            $href->{'general'}->{$attrkey} = $attr{$attrkey};
         }
      } elsif ( $currentTag eq "table" ) {
         $href->{'_current_table'} = $attr{'name'};
         $href->{'_current_table'} =~ s/^\s*//;
         $href->{'_current_table'} =~ s/\s*$//;
         push @{ $href->{ 'table' }->{'_table_order'} }, $href->{'_current_table'};
         $href->{'table'}->{$attr{'name'}}->{'struct_type'} = $attr{'struct_type'};
      } elsif ( lc $currentTag eq "column" ) {
         my $curr_table = $href->{'_current_table'};
         my $thiscolumn = $attr{'name'};
         push @{ $href->{ 'table' }->{ $curr_table }->{'_column_order'} }, $thiscolumn;
         foreach my $attrkey ( keys %attr ) {
            next if uc $attrkey eq 'ERROR';
            next if uc $attrkey eq 'DATA';
            $attr{$attrkey} =~ s/^\s*//;
            $attr{$attrkey} =~ s/\s*$//;
            next if $attr{$attrkey} eq '';
            if ( defined $attr{$attrkey} ) {
               if ( uc $attrkey =~ /^CHECK\d?$/ or uc $attrkey =~ /^MODIFY$/ ) {
                  # arrays:
                  my @arr = split /\s*,\s*/, $attr{$attrkey};
                  @{ $href->{'table' }->{ $curr_table}->{'column'}->{$thiscolumn}->{$attrkey} } =
                     @arr if @arr;
               } else {
                  if ( lc $attrkey eq "name" ) {
                     # attribute "name" is replaced by DB_COLUMN                 
                     $href->{'table' }->{ $curr_table}->{'column'}->{$thiscolumn}->{'DB_COLUMN'} =
                       $attr{$attrkey};
                  } else {
                     $href->{'table' }->{ $curr_table}->{'column'}->{$thiscolumn}->{$attrkey} = $attr{$attrkey};
                  }
               }
            }
         }
      } elsif ( uc $currentTag eq "TRIGGER" ) {
         foreach my $attrkey ( keys %attr ) {
            $attr{$attrkey} =~ s/^\s*//;    # remove leading whitespace
            $attr{$attrkey} =~ s/\s*$//;    # remove end whitespace
            my $curr_table = $href->{'_current_table'};
            # remove leading and trailing " and ':
            my @arr = map { s/^['"]//; s/['"]$//; $_ } split /\s*,\s*/, $attr{$attrkey};
            @{$href->{'table' }->{ $curr_table}->{'trigger'}->{$attrkey}} = @arr if @arr;
         }
      } elsif ( uc $currentTag eq "CONSTRAINTS" ) {
         foreach my $attrkey ( keys %attr ) {
            $attr{$attrkey} =~ s/^\s*//;    # remove leading whitespace
            $attr{$attrkey} =~ s/\s*$//;    # remove end whitespace
            my $curr_table = $href->{'_current_table'};
            if ( defined $attr{$attrkey} ) {
               if ( uc $attrkey eq "SEQUENCE" or uc $attrkey eq "INDEX" ) {
                  my @arr = map { s/^['"]//; s/['"]$//; $_ } split /\s*,\s*/, $attr{$attrkey};
                  @{$href->{'table' }->{ $curr_table}->{lc $attrkey}} = @arr if @arr;
               } elsif ( uc $attrkey eq "PRIMARYKEY" ) {
                  # REF_COL:db_animal;CONCAT:db_unit,ext_animal;VIEW:entry_transfer;WHERE:closing_dt is NULL;
                  my @pk_items = split /\s*;\s*/, $attr{$attrkey};
                  foreach my $elem (@pk_items) {
                     my ( $key, $value ) = split /:/, $elem;
                     my $tmp_href;
                     die "Syntax error in model file (PRIMARYKEY of table $curr_table)\n"
                        if $key and not defined $value;
                     @{ $tmp_href->{$key} } = split /\s*,\s*/, $value;
                     foreach my $e ( keys %{$tmp_href} ) {
                        if ( ( uc $e eq "CONCAT" ) or ( uc $e eq "ADD_COLS" ) ) {
                           @{$href->{'table' }->{ $curr_table}->{'pk'}->{lc $e}} = @{ $tmp_href->{$e} }; 
                        } else {
                           $href->{'table' }->{ $curr_table}->{'pk'}->{lc $e} = shift @{ $tmp_href->{$e} }; 
                        }
                     }
                  }
               }
            }
         }
      }
   }
}
##############################################################################

=head2 _get_db_conf (internal)

Read the config file for the passed Database from
$APIIS_HOME/etc/apiis/<Database>.conf and return a hash reference of this
structure.

=cut

sub _get_db_conf {
    my ( $self, $db ) = @_;
    my $db_conf = $self->APIIS_HOME . "/etc/${db}.conf";
    die "Configuration for Database $db ($db_conf) does not exist\n" if ! -r $db_conf;
    my $cfg  = Config::Auto::parse($db_conf);
    die "Cannot read file $db_conf or error while parsing the file.\n" if ! $cfg;
    return $cfg;
}

##############################################################################
1;
