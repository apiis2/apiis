##############################################################################
# $Id: AR_Batch.pm,v 1.4 2005/12/09 18:50:06 marek Exp $
##############################################################################
#package Apiis::Auth::AR_Batch;
$VERSION = '$Revision: 1.4 $';
##############################################################################

=head1 NAME

Apiis::Auth::AR_Batch.pm

=cut

=head1 SYNOPSIS


=head1 DESCRIPTION


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
use Apiis::Init;
use Data::Dumper;
use Config::IniFiles;

our $apiis;
our $arfile;
##############################################################################

=head2 collect_groups 

  This subroutine puts complete information about groups in to the hashes. 
  This means that also the information about roles and policies defined 
  for these groups is collected.

=cut

sub collect_groups{
  my $section_names = shift;
  my (%group_hash,%old_role_hash,%role_hash,%stpolicies_hash,%dbtpolicies_hash)=();
   my $stp_notget=1;my $dbtp_notget=1;
  EXIT:{
    _init() unless (defined $arfile);
    last EXIT if ($apiis->status);

    my $gr_hsh = get_groups_or_roles(\@$section_names,'GROUP');
    last EXIT if ($apiis->status);

    %group_hash = %$gr_hsh;
    foreach my $mygroup (keys %group_hash){ 
       my @mygrelements = split ',',$group_hash{$mygroup}{group_elements};
       my $mygrcontent =$group_hash{$mygroup}{group_content}; 
       ##IF THE GROUP CONSIST OF ROLES
       if ($mygrcontent eq 'Roles'){
         ### GET ROLES ###
         my ($rhsh,$stphsh,$dbtphsh,$statusstp,$statusdbtp) = collect_roles(\@mygrelements,$stp_notget,$dbtp_notget);
         ### merging all role hashes in to the one hash (%role_hash) which will be returned at the end ###  
         %old_role_hash= %role_hash;
         my %new_role_hash= %$rhsh;
         while ( my ($k,$v) =  each (%old_role_hash)){$role_hash{$k} = $v;}
         while ( my ($k,$v) =  each (%new_role_hash)){$role_hash{$k} = $v;}
         #policy hash is fill in when the 'notget' is set on 1. This means that the policies could be taken from the file.
         #Then tthe status is chaneged and this hash is not touch anymore. If the policy were not taken than the status 
         #stays on 1 and the hash is fill in empty value.
         %stpolicies_hash = %$stphsh if ($stp_notget);
         %dbtpolicies_hash = %$dbtphsh if ($dbtp_notget);

         $dbtp_notget=$statusdbtp;
         $stp_notget=$statusstp;
       ##IF THE GROUP CONSIST OF GROUPS
       }elsif ($mygrcontent eq 'Groups'){
         print "Grouping groups not supported by the command line tool\n";
         last EXIT; 
       }else{
         $apiis->status(1);
               $apiis->errors(
                  Apiis::Errors->new(
                     type      => 'DATA',
                     severity  => 'ERR',
                     from      => 'Apiis::Auth::AR_Batch::ar_batch',
                     msg_short => __('Wrong group content definition: [_1]',$mygrcontent),
                     msg_long  => __("The element 'CONTENT_GROUP' is not corectly defined for the group '[_1]'. It can be defined only as 'Roles' value or as 'Groups' value.",$mygroup),
                  )
               );
         last EXIT; 
       }
    }#end foreach group
  }
  return \%group_hash,\%role_hash,\%stpolicies_hash,\%dbtpolicies_hash,$stp_notget,$dbtp_notget; 
}

=head2 _init

  this subroutine creates the object for the config file where the information 
  about access rights is written. 

=cut

sub _init {

  my $ar_batch_config = $apiis->APIIS_LOCAL."/etc/AR_Batch.conf";
  my $checkfile = Apiis::CheckFile->new( file => "$ar_batch_config" );
      if ( $checkfile->status ) {
        $apiis->errors($checkfile->errors);
        $apiis->status(1);
        $apiis->errors(
                  Apiis::Errors->new(
                     type      => 'DATA',
                     severity  => 'ERR',
                     from      => 'Apiis::Auth::AR_Batch::_init',
                     msg_short => __('Object not created'),
                     msg_long  => __("Object for the config file not created: '[_1]'",$ar_batch_config),
                  )
               );
        return;
      }else{
        $arfile = new Config::IniFiles( -file   =>  "$ar_batch_config",  -nocase => 1 );
	$apiis->log( 'debug',"Apiis::Auth::AR_Batch::_init: Object for the config file created: $ar_batch_config");
      }
}

=head2 get_group_or_roles

   This subroutine get an information about groups or roles from the config file. 

=cut

sub get_roles{
  my ($names,$recursion_hash) = @_;
  my %tmp_hash = %$recursion_hash if (defined $recursion_hash);
  my @wrong_sections;
  my $section_status=0;

 EXIT:{
  foreach my $myname(@{$names}){
    my $mysection = "ROLE $myname";
    if ($arfile->Parameters($mysection)){
      foreach my $parameter ($arfile->Parameters($mysection)){
        $tmp_hash{$myname}{$parameter} = $arfile->val( $mysection, $parameter); 
        if ($parameter eq 'role_subset' and defined $arfile->val( $mysection, 'role_subset') ){
          my @role_subset = split (',',$arfile->val( $mysection, 'role_subset')); 
          my @not_duplicated_roles;
          foreach my $role_name (@role_subset){
          	push @not_duplicated_roles, $role_name unless ($tmp_hash{$role_name}{'role_type'});
          }
          my $ret_hash  = get_roles(\@not_duplicated_roles,\%tmp_hash) if (@not_duplicated_roles);
          last EXIT if ($apiis->status);
          %tmp_hash = %$ret_hash if (@not_duplicated_roles);
        }
      }
    }else{
      $apiis->status(1);
      $apiis->errors(
                  Apiis::Errors->new(
                     type      => 'DATA',
                     severity  => 'ERR',
                     from      => 'Apiis::Auth::AR_Batch::get_groups_or_roles',
                     msg_short => __("No section definition in the configuration file ([_1]/etc/AR_Batch.conf)",$apiis->APIIS_LOCAL),
                     msg_long  => __("There is no role definition with the following name: [_1]",$myname),
                  )
               );
      last EXIT;
    }
  }
  return \%tmp_hash
 }#EXIT end
}

=head2 get_policies

   This subroutine can get an information about system task policies or database
   task policies form the configuration file. The result is dependend on 
   the section name which you put as a input parameter. 

=cut

sub get_policies{
  my $section = shift;
  my %tmp_hash;
  my $policies_notget=1;

 EXIT:{
  if ($section eq "SYSTEM_TASK"){
    my $mysection = "$section POLICIES"; 
    if ($arfile->Parameters($mysection)){
      foreach my $parameter ($arfile->Parameters($mysection)){
        $tmp_hash{$parameter} = $arfile->val($mysection,$parameter); 
      }
      $policies_notget=0;
    }else{
      $apiis->status(1);
      $apiis->errors(
                  Apiis::Errors->new(
                   type      => 'DATA',
                   severity  => 'ERR',
                   from      => 'Apiis::Auth::AR_Batch::get_policies',
                   msg_short => __("No section definition in the configuration file ([_1]/etc/AR_Batch.conf)",$apiis->APIIS_LOCAL),
                   msg_long  => __("Wrong section definition for the system task policies: [_1]",$mysection),
                  )
      );
      last EXIT;
    }
  }elsif ($section eq "DATABASE_TASK"){
    my @dbtsections = qw (TABLES DESCRIPTORS POLICIES);
    foreach my $dbtsection (@dbtsections){
      my $mysection = "$section $dbtsection";
      if ($arfile->Parameters($mysection)){
        foreach my $parameter ($arfile->Parameters($mysection)){
          $tmp_hash{$dbtsection}{$parameter} = $arfile->val($mysection,$parameter);
        }
        $policies_notget=0;
      }else{
        $apiis->status(1);
        $apiis->errors(
                  Apiis::Errors->new(
                     type      => 'DATA',
                     severity  => 'ERR',
                     from      => 'Apiis::Auth::AR_Batch::get_policies',
                     msg_short => __("No section definition in the configuration file ([_1]/etc/AR_Batch.conf)",$apiis->APIIS_LOCAL),
                     msg_long  => __("Wrong section definition for the database task policies: [_1]",$mysection),
                  )
        );
        last EXIT;
      }
    }#foreach $dbtsection
  }else{
    $apiis->status(1);
    $apiis->errors(
                Apiis::Errors->new(
                   type      => 'DATA',
                   severity  => 'ERR',
                   from      => 'Apiis::Auth::AR_Batch::get_policies',
                   msg_short => __("Wrong section type definition: '[_1]'",$section),
                   msg_long  => __("You can use as a parameter only 'SYSTEM_TASK' or 'DATABASE_TASK' value"),
                )
    );
    last EXIT;
  }
  #print "\n$section\n";
  #print Dumper (%tmp_hash);
  return \%tmp_hash,$policies_notget;
 }#end EXIT
}

=head2 collect_roles

   This subroutine puts information about roles and policies in to the hashes.

=cut

sub collect_roles{
  my ($section_names) = @_;
  my (%old_role_hash,%role_hash,%stpolicies_hash,%dbtpolicies_hash)=();
  my $stp=1;# if (not defined $stp );
  my $dbtp=1;# if (not defined $dbtp);

  EXIT:{
    _init() unless (defined $arfile);
    last EXIT if ($apiis->status);
    
    my $r_hsh  = get_roles(\@$section_names);
    last EXIT if ($apiis->status);
    %role_hash = %$r_hsh;
    ### GET POLICIES ### all the policies are taken from the configuration file by the first time
    foreach my $myrole (keys %role_hash){ 
      my @myrpolicies = split ',',$role_hash{$myrole}{role_policies};
      my $myrtype =$role_hash{$myrole}{role_type};
      ### system task policies ###
      if ($myrtype eq 'ST'){
        #if ($stp){
          my ($stp_hsh,$status) = get_policies("SYSTEM_TASK") ;
          last EXIT if ($apiis->status);
          $stp = $status;
          %stpolicies_hash = %$stp_hsh;
          #print "\nDDD\n";
          #print Dumper(\%stpolicies_hash);
        #}
      ### database task policies ###
      }elsif ($myrtype eq 'DBT'){
        #if ($dbtp){
          my ($dbtp_hsh,$status) = get_policies("DATABASE_TASK");
          last EXIT if ($apiis->status);
          $dbtp= $status;
          %dbtpolicies_hash = %$dbtp_hsh;
        #} 
      }else{
        $apiis->status(1);
        $apiis->errors(
          Apiis::Errors->new(
            type      => 'DATA',
            severity  => 'ERR',
            from      => 'Apiis::Auth::AR_Batch::ar_batch',
            msg_short => __('Wrong role type definition: [_1]',$myrtype),
            msg_long  => __("The element 'ROLE_TYPE' is not corectly defined for the role '[_1]'. It can be defined only as 'ST' value or as 'DBT' value.",$myrole),
          )
        );
        last EXIT;
      }
    }
    #print Dumper (%stpolicies_hash);
    return \%role_hash,\%stpolicies_hash,\%dbtpolicies_hash,$stp,$dbtp; 
  }#EXIT
}
#########################################################################
1;

=head1 AUTHOR

Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut
