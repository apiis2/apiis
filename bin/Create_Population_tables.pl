#!/usr/bin/env perl
##############################################################################
# $Id: Create_Population_tables.pl,v 1.36 2015/03/10 07:12:02 heli Exp $
##############################################################################
# create some temporary tables for reports
# rewriting of createTempForTable.tpl

BEGIN {
    use Env qw( APIIS_HOME );
    die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
    push @INC, "$APIIS_HOME/lib";
}

use strict;
use warnings;
use Apiis;
use Popreport;  # provides print_list()
use Data::Dumper;

Apiis->initialize( VERSION => '$Revision: 1.36 $' );
our $apiis;

use vars qw(
    $opt_p $opt_h $opt_v $opt_b $opt_d $opt_x $opt_o $opt_r $opt_L $opt_n
    $opt_c $opt_u $opt_w $opt_l $opt_m $opt_f $opt_g $opt_e $opt_i $opt_j $opt_a
    @temp_tables_used $model_file $dbh $db_driver $db_name $db_user $breed
    $sine $dbb $ff $mm
);

use Date::Calc qw/ Delta_DHMS /;

my $debug = 0;
my ( $sec1, $min1, $hour1, $mday1, $mon1, $year1, $wday1, $yday1, $isdst1 ) =
    localtime(time);
$year1 = 1900 + $year1;
$mon1  = 1 + $mon1;

my $programname = $0;
$programname =~ s|.*/||;    # basename
my $version = $apiis->version;

#Program use the following field names in table litter:
# Defaults set as:
my $nba = 'born_alive_no'; #Your field name for number born alive
my $par = 'parity'; #Your field name for parity number
my $birth = 'delivery_dt'; #Your field name for birth date
my $ges_len = 'year' ; #Default Gestation length if no service table exist (Pigs)
my $brd = 'BREED'; #Default name for breed in class = 'BREED' in codes

# allowed parameters:
use Getopt::Std;
getopts('p:vhcdxo:u:w:r:n:b:l:m:f:g:e:i:j:a:L:');

if ($opt_v) { die "$programname $version\n" }    # Version
usage() if $opt_h;                               # help:
if ($opt_r) { die '-r ', msg(51), "!\n" if $opt_r =~ /\D+/; }    # not numeric
if ($opt_n) { die '-n ', msg(51), "!\n" if $opt_n =~ /\D+/; }    # not numeric
sub usage {
print " option -p <project>   => project
        -v                    => Version
        -h                    => Help
        -u                    => user
        -w                    => passwoord
        -b                    => database short_name for breed (If not entered all breeds will run)
        -a                    => Your name for BREED in class = 'BREED' in table codes (Default = $brd)
        -l                    => if you have service and litter information (1 = yes, 2 = no)
        -g                    => Gestation measure year, month or day (Default = $ges_len)
        -m                    => database short_name for males
        -f                    => database short_name for females
        -e                    => Your field name in litter for number born alive (Default =  $nba)
        -i                    => Your field name in litter for parity number (Default =  $par)
        -j                    => Your field name in litter for birth date (Default = $birth)
        -x                    => explain queries
        -o <out  file>        => output file for -x
        -L <listfile>         => listfile for program output
        -r <number>           => restart execution at sql statement <number>
        -n <number>           => stop after <number> statements
        -c                    => do count on temp. tables
        -d                    => drop all tables of these queries

For example:
Create_Population_tables.pl -p breedprg -u demo -w Demo -b DUR -a BREED -l 1 -m Male -f Female -c 1
\n";
    die "At least you have to provide -p <model>\n\n";
}
##############################################################################

my $outfile  = $opt_o if $opt_o;
our $listfile = $opt_L if $opt_L;
my $texlist = $listfile;
$texlist =~ s/lst$/tex/;

if (! defined $opt_m){die "No short_code for males where presented; use the -m option\n";}
if (! defined $opt_f){die "No short_code for females where presented; use the -f option\n";}

if ($opt_m){$mm=$opt_m;}
print "Data Base Short_name for Males: $mm\n";

if ($opt_f){$ff=$opt_f;}
print "Data Base Short_name for Females: $ff\n";

if ($opt_e){$nba=$opt_e;}
print "Field name in litter for number born alive: $nba\n";

if ($opt_i){$par=$opt_i;}
print "Field name in litter for parity: $par\n";

if ($opt_j){$birth=$opt_j;}
print "Field name in litter for birth date: $birth\n";

if ($opt_g){$ges_len=$opt_g;}
print "Gestation measure in: $ges_len \n";

$model_file = $opt_p if $opt_p;

if ($opt_b) {
  $breed = $opt_b;
    print "breed = $breed\n";
}
if ($opt_a) {
  $brd = $opt_a;
    print "BREED = $brd\n";
}

my $werk =2;
if ($opt_l) {
    if ($opt_l==1){  
    $werk = 1;
} else {
    $werk = 2;
}
  } else {
      $werk = 0;
  }

  
  if ($werk==1){
          print "Service and litter data exist\n";
      } 
  if ($werk==2){ 
          print "Service and litter data do not exist\n";
      } 
      
  if ($werk==0) {
          print "No option for Service and litter data will check in model file\n";
      }
usage() unless $model_file;
my $not_ok=1;
my $loginname = $opt_u if $opt_u;
my $passwd = $opt_w if $opt_w;
use Apiis::DataBase::User;
if (! $opt_u and ! $opt_w){
  while ($not_ok) {
    print __("Please enter your login name: ");
    chomp( $loginname = <> );
    print __("... and your password: ");
#    ReadMode 2;
    chomp( $passwd = <> );
#    ReadMode 0;
    print "\n";
    $not_ok = 0 if $loginname and $passwd;
  }
} else {
  $not_ok=1;
}
my $thisobj = Apiis::DataBase::User->new(
   id       => "$loginname",
   password => "$passwd",
   );
   $thisobj->check_status;

$apiis->join_model("$model_file", userobj => $thisobj);


$apiis->check_status( die => 'ERR' );
my $dbh=$apiis->DataBase->dbh;
my $dbname=$apiis->Model->db_name;
my $dbhost=$apiis->Model->db_host;

my $have_table_service=0;
$have_table_service = 1 if grep /^service$/, $apiis->Model->tables;
if (defined $opt_l) {
    if ($werk == 1){
     $have_table_service=1;
    } else {
      $have_table_service=3;
    }
}
$sine = '=';
#$dbb = $breed;
my $sql1;
my $sql_ref1;
if (! defined $breed){
  $sql1 = "select min(db_breed) from animal";
  $sine = '>=';  
   $sql_ref1 = $apiis->DataBase->sys_sql($sql1);
   $apiis->check_status ;
   while( my $line_ref = $sql_ref1->handle->fetch ) {
     my @line = @$line_ref;
     $dbb=$line[0];
   }
} else {
   $sql1 = "select db_code from codes where class='$brd' and (ext_code='$breed' or
          short_name = '$breed' or long_name='$breed')";
   $sql_ref1 = $apiis->DataBase->sys_sql($sql1);
   $apiis->check_status ;
   while( my $line_ref = $sql_ref1->handle->fetch ) {
     my @line = @$line_ref;
     $dbb=$line[0];
   }
}
if (! $dbb and $opt_b and ! $opt_d){
    my @die_msg_sex;
    push @die_msg_sex, "ERROR:\n";
    push @die_msg_sex, "Breed $breed does not exist in database\n";
    push @die_msg_sex, "No Population report can be created.\n";
    print_tex_item( join( '\\\\', @die_msg_sex ), $texlist );   
    die sprintf "\n**** Breed $breed does not exist in database ****\n\n";
}
my $sql11 = "select db_code
             from codes 
             where (ext_code='$mm' or short_name='$mm' or long_name='$mm') 
             and class='SEX'";
$sql_ref1 = $apiis->DataBase->sys_sql($sql11);
$sql_ref1->check_status( die => 'ERR' );
my $tmp;
while ( my $line_ref = $sql_ref1->handle->fetch ) {
    $tmp = $line_ref->[0];
}
if ( !$tmp and ! $opt_d ) {
   my @die_msg_sex;
   push @die_msg_sex, "ERROR:\n";
   push @die_msg_sex, "Sex $mm does not exist in the database\n";
   push @die_msg_sex, "No Population report can be created.\n";
   print_tex_item( join( '\\\\', @die_msg_sex ), $texlist );   
   die sprintf "\n ***** The SEX $mm does not exist in the database *****\n\n";
}
$sql11 = "select db_code
             from codes 
             where (ext_code='$ff' or short_name='$ff' or long_name='$ff') 
             and class='SEX'";
$sql_ref1 = $apiis->DataBase->sys_sql($sql11);
$sql_ref1->check_status( die => 'ERR' );
$tmp=undef;
while ( my $line_ref = $sql_ref1->handle->fetch ) {
    $tmp = $line_ref->[0];
}
if ( !$tmp and ! $opt_d ) {
   my @die_msg_sex;
   push @die_msg_sex, "ERROR:\n";
   push @die_msg_sex, "Sex $ff does not exist in the database\n";
   push @die_msg_sex, "No Population report can be created.\n";
   print_tex_item( join( '\\\\', @die_msg_sex ), $texlist );   
   die sprintf "\n ***** The SEX $ff does not exist in the database *****\n\n";
}

my ($sql_statement1a, $sql_statement2a, $sql_statement3a, $sql_statement4a,
    $sql_statement5a,$sql_statment2service1,$sql_statment2service2,$sql_statment2service3,$sql_statment2service4,$sql_statment2service5,$sql_statment2service6,$sql_statment2service7,$sql_statment2service8,$sql_statment2service9,$sql_statment2service10,$sql_statment2service11,$sql_statment2service12,$sql_statementbob1);
if ( $have_table_service == 1 ) {
#count the number of sires contrubute to a service during a year 
  $sql_statment2service1 = "select xx.db_breed,date_part('year',xx.service_dt) as year,count(xx.*) as services 
                            into tmp1_serv_sire 
                            from ( select distinct on (a.db_sire, date_part('year',service_dt)) b.db_breed,service_dt 
                                   from  service a, animal b 
                                   where  a.db_sire>2 and a.db_sire=b.db_animal and b.db_breed $sine $dbb) as xx
                            group by  xx.db_breed,date_part('year',xx.service_dt) 
                            order by year;
                            ";
#counting the number of service records during a year
#  $sql_statment2service1 = "select b.db_breed,date_part('year',a.service_dt) as
#  year,count(*) as services into tmp1_serv_sire from service a,
#  animal b where
#  a.db_sire>2 and a.db_sire=b.db_animal and b.db_breed $sine $dbb group by
#  b.db_breed,date_part('year',service_dt) order by
#  year
#  ";

  $sql_statment2service2 = "select xx.db_breed,date_part('year',xx.service_dt) as year,count(xx.*) as services 
                            into tmp1_serv_dam 
                            from ( select distinct on (a.db_animal, date_part('year',service_dt)) b.db_breed,service_dt 
                                   from  service a, animal b 
                                   where  a.db_animal>2 and a.db_animal=b.db_animal and b.db_breed $sine $dbb) as xx
                            group by  xx.db_breed,date_part('year',xx.service_dt) 
                            order by year;
                            ";
#  $sql_statment2service2 = "select b.db_breed,date_part('year',a.service_dt) as
#  year,count(*) as services into tmp1_serv_dam from service a,
#  animal b where
#  a.db_animal>2 and a.db_animal=b.db_animal and b.db_breed $sine $dbb group by
#  b.db_breed,date_part('year',service_dt) order by
#  year
#  ";
 
  $sql_statment2service3 = "create index ind_tmp1_serv_sire on tmp1_serv_sire
  (db_breed,year)
  ";

  $sql_statment2service4 = "create index ind_tmp1_serv_dam on tmp1_serv_sire
  (db_breed,year)
  ";

  $sql_statment2service5 = "update tmp1_1 set
  service=services from tmp1_serv_sire where
  tmp1_1.db_breed=tmp1_serv_sire.db_breed and
  tmp1_1.year=tmp1_serv_sire.year and tmp1_1.parent='sire'
  ";

  $sql_statment2service6 = "update tmp1_1 set
  service=services from tmp1_serv_dam where
  tmp1_1.db_breed=tmp1_serv_dam.db_breed and
  tmp1_1.year=tmp1_serv_dam.year and tmp1_1.parent='dam'
  ";

  $sql_statment2service7 = "select xx.db_breed as db_breed,count(xx.*) as number 
                            into tmp1_t_ser_dam 
                            from (select distinct on (service.db_animal, date_part('year',service.service_dt)) animal.db_breed,service.db_animal 
                                  from service, animal 
                                  where service.db_animal>2 and service.db_animal=animal.db_animal and animal.db_breed $sine $dbb) as xx 
                            group by xx.db_breed";

  $sql_statment2service8 = "select xx.db_breed as db_breed,count(xx.*) as number 
                            into tmp1_t_ser_sire 
                            from (select distinct on (service.db_sire, date_part('year',service.service_dt)) animal.db_breed,service.db_sire 
                                  from service, animal 
                                  where service.db_sire>2 and service.db_animal=animal.db_animal and animal.db_breed $sine $dbb) as xx 
                            group by xx.db_breed";

  $sql_statment2service9 = "update tmp1_1 set service=tmp1_t_ser_dam.number from tmp1_t_ser_dam, codes where tmp1_1.year='Total' and tmp1_1.breed=codes.short_name and codes.db_code=tmp1_t_ser_dam.db_breed and tmp1_1.parent='dam'";

  $sql_statment2service10 = "update tmp1_1 set service=tmp1_t_ser_sire.number from tmp1_t_ser_sire, codes where tmp1_1.year='Total' and tmp1_1.breed=codes.short_name and codes.db_code=tmp1_t_ser_sire.db_breed and tmp1_1.parent='sire'";

#  $sql_statment2service11 = "drop table tmp1_t_ser_dam";

#  $sql_statment2service12 = "drop table tmp1_t_ser_sire";
} else {
  print "Gestation measured in: $ges_len\n";
}


##### SQL statements ###############
# Most of the following SQL statement are PostgreSQL-specific. Some kind soul should rewrite
# them. Here some information from the PostgreSQL-docs:

# Note:  CREATE TABLE AS is functionally equivalent to SELECT INTO. CREATE
# TABLE AS is the recommended syntax, since SELECT INTO is not standard. 
# In fact, this form of SELECT INTO is not available in PL/pgSQL or ecpg,
# because they interpret the INTO clause differently.  Compatibility
# 
# SQL92 uses SELECT ... INTO to represent selecting values into scalar
# variables of a host program, rather than creating a new table (this applies also
# for Oracle - heli). This indeed is the usage found in PL/pgSQL and
# ecpg. The Postgres usage of SELECT INTO to represent table creation is
# historical. It's best to use CREATE TABLE AS for this purpose in new
# code. (CREATE TABLE AS isn't standard either, but it's less likely to
# cause confusion.)

my @sql_statements;

#####Bobbie van der Westhuizen SQL STARTS (SA Studbook, South Africa)   #### 
##### SQL for males and females in reproduction

push @sql_statements,
"select distinct db_sire as parent,'$mm'::varchar as sex into tmp1_sons from animal where db_sire>3 and db_breed $sine $dbb";

push @sql_statements,
"select distinct db_dam as parent,'$ff'::varchar as sex into tmp1_daug from animal where db_dam>3 and db_breed $sine $dbb";

push @sql_statements,
"select * into tmp1_parents from tmp1_sons UNION select * from tmp1_daug";

push @sql_statements,
"select distinct db_sire as parent into tmp1_par from animal where db_sire > 3 and db_breed $sine $dbb UNION 
 select distinct db_dam as parent from animal where db_dam > 3 and db_breed $sine $dbb";

push @sql_statements,
"create index ind_tmp1_par on tmp1_par(parent)";
if ($ges_len eq 'year'){
push @sql_statements,
"select a.db_breed,date_part('year',a.birth_dt) as year,a.db_sire,count(*) as borns,
round(((avg((a.birth_dt-b.birth_dt)::numeric/365))-0.5),0) as age
into tmp1_sires_noffsp 
from animal a left outer join animal b on (a.db_sire=b.db_animal)
where a.db_sire>2 and a.birth_dt notnull and a.db_breed $sine $dbb
group by a.db_breed,date_part('year',a.birth_dt),a.db_sire 
order by a.db_breed,year";
} elsif ($ges_len eq 'month') {
push @sql_statements,
"select a.db_breed,date_part('year',a.birth_dt) as year,a.db_sire,count(*) as borns,
round(((avg((a.birth_dt-b.birth_dt)::numeric/30.4))-0.5),0) as age
into tmp1_sires_noffsp 
from animal a left outer join animal b on (a.db_sire=b.db_animal)
where a.db_sire>2 and a.birth_dt notnull and a.db_breed $sine $dbb
group by a.db_breed,date_part('year',a.birth_dt),a.db_sire 
order by a.db_breed,year";
} else {
push @sql_statements,
"select a.db_breed,date_part('year',a.birth_dt) as year,a.db_sire,count(*) as borns,
round(((avg((a.birth_dt-b.birth_dt)::numeric))-0.5),0) as age
into tmp1_sires_noffsp 
from animal a left outer join animal b on (a.db_sire=b.db_animal)
where a.db_sire>2 and a.birth_dt notnull and a.db_breed $sine $dbb
group by a.db_breed,date_part('year',a.birth_dt),a.db_sire 
order by a.db_breed,year";
}

push @sql_statements,
"select db_breed,year,count(*) as borns into tmp1_1b from tmp1_sires_noffsp
group by db_breed,year order by db_breed,year";

push @sql_statements,
"select a.db_breed,date_part('year',a.birth_dt) as year,a.db_sire,count(*) as
number_sires into tmp1_sires_noffsp_sel from animal a,tmp1_par b where
a.db_sire>2 and a.birth_dt notnull and a.db_breed $sine $dbb and a.db_animal=b.parent group by
a.db_breed,date_part('year',a.birth_dt),a.db_sire order by a.db_breed,year";

push @sql_statements,
"alter table tmp1_1b add sel int";

push @sql_statements,
"alter table tmp1_1b add parent text";

push @sql_statements,
"update tmp1_1b set sel=(select count(*) from tmp1_sires_noffsp_sel where
tmp1_1b.db_breed=tmp1_sires_noffsp_sel.db_breed and
tmp1_1b.year=tmp1_sires_noffsp_sel.year group by
tmp1_sires_noffsp_sel.db_breed,tmp1_sires_noffsp_sel.year),parent='sire'";
if ($ges_len eq 'year'){
push @sql_statements,
"select a.db_breed,date_part('year',a.birth_dt) as year,a.db_dam,count(*) as borns,
round(((avg((a.birth_dt-b.birth_dt)::numeric/365))-0.5),0) as age
into tmp1_dams_noffsp 
from animal a left outer join animal b on (a.db_dam=b.db_animal)
where a.db_dam>2 and a.birth_dt notnull and a.db_breed $sine $dbb
group by a.db_breed,date_part('year',a.birth_dt),a.db_dam 
order by a.db_breed,year";
} elsif ($ges_len eq 'month') {
push @sql_statements,
"select a.db_breed,date_part('year',a.birth_dt) as year,a.db_dam,count(*) as borns,
round(((avg((a.birth_dt-b.birth_dt)::numeric/30.4))-0.5),0) as age
into tmp1_dams_noffsp 
from animal a left outer join animal b on (a.db_dam=b.db_animal)
where a.db_dam>2 and a.birth_dt notnull and a.db_breed $sine $dbb
group by a.db_breed,date_part('year',a.birth_dt),a.db_dam 
order by a.db_breed,year";
} else {
push @sql_statements,
"select a.db_breed,date_part('year',a.birth_dt) as year,a.db_dam,count(*) as borns,
round(((avg((a.birth_dt-b.birth_dt)::numeric))-0.5),0) as age
into tmp1_dams_noffsp 
from animal a left outer join animal b on (a.db_dam=b.db_animal)
where a.db_dam>2 and a.birth_dt notnull and a.db_breed $sine $dbb
group by a.db_breed,date_part('year',a.birth_dt),a.db_dam 
order by a.db_breed,year";
}

push @sql_statements,
"select db_breed,year,count(*) as borns into tmp1_1a from tmp1_dams_noffsp
group by db_breed,year order by db_breed,year";

push @sql_statements,
"select a.db_breed,date_part('year',a.birth_dt) as year,a.db_dam,count(*) as
number_dams into tmp1_dams_noffsp_sel from animal a,tmp1_par b where a.db_dam>2
and a.birth_dt notnull and a.db_breed $sine $dbb and a.db_animal=b.parent group by
a.db_breed,date_part('year',a.birth_dt),a.db_dam order by a.db_breed,year";

push @sql_statements,
"alter table tmp1_1a add sel int";

push @sql_statements,
"alter table tmp1_1a add parent text";

push @sql_statements,
"update tmp1_1a set sel=(select count(*) from tmp1_dams_noffsp_sel where
tmp1_1a.db_breed=tmp1_dams_noffsp_sel.db_breed and
tmp1_1a.year=tmp1_dams_noffsp_sel.year group by
tmp1_dams_noffsp_sel.db_breed,tmp1_dams_noffsp_sel.year),parent='dam'";

push @sql_statements,
"select * into tmp1_1 from tmp1_1b UNION select * from tmp1_1a";

push @sql_statements,
"alter table tmp1_1 add service int";

push @sql_statements,
"alter table tmp1_1 add breed text";

push @sql_statements,
"update tmp1_1 set breed=(select short_name from codes where
tmp1_1.db_breed=codes.db_code and codes.class='$brd')";

push @sql_statements,
 $sql_statment2service1 if $sql_statment2service1;

push @sql_statements,
 $sql_statment2service2 if $sql_statment2service2;

push @sql_statements,
 $sql_statment2service3 if $sql_statment2service3;

push @sql_statements,
 $sql_statment2service4 if $sql_statment2service4;

push @sql_statements,
 $sql_statment2service5 if $sql_statment2service5;

push @sql_statements,
 $sql_statment2service6 if $sql_statment2service6;

push @sql_statements,
"alter table tmp1_1 add born numeric";


push @sql_statements,
"select codes.short_name as breed,date_part('year',animal.birth_dt) as year,count(*) as number into tmp1_pas from animal, codes where animal.birth_dt is not null and animal.db_breed=codes.db_code and animal.db_breed $sine $dbb group by codes.short_name,date_part('year',animal.birth_dt)";

push @sql_statements,
"alter table tmp1_1 alter year type text";

push @sql_statements,
"select xx.db_breed,count(xx.*) as number into tmp1_t_dam from (select db_breed,db_dam from animal where db_dam>2 and db_breed $sine $dbb group by db_breed,db_dam) as xx group by xx.db_breed";

push @sql_statements,
"select xx.db_breed,count(xx.*) as number into tmp1_t_sire from (select db_breed,db_sire from animal where db_sire>2 and db_breed $sine $dbb group by db_breed,db_sire) as xx group by xx.db_breed";

push @sql_statements,
"select xx.db_breed,count(xx.*) as number into tmp1_t_dam_s from (select a.db_breed,a.db_dam from animal a, tmp1_parents b where a.db_dam>2 and a.db_animal=b.parent and a.db_breed $sine $dbb group by a.db_breed,a.db_dam) as xx group by xx.db_breed";

push @sql_statements,
"select xx.db_breed,count(xx.*) as number into tmp1_t_sire_s from (select a.db_breed,a.db_sire from animal a, tmp1_parents b where a.db_sire>2 and a.db_animal=b.parent and a.db_breed $sine $dbb group by a.db_breed,a.db_sire) as xx group by xx.db_breed";

push @sql_statements,
"insert into tmp1_1 (breed,year,borns,sel,parent) select c.short_name,'Total',a.number,b.number,'dam' from tmp1_t_dam a, tmp1_t_dam_s b, codes c where a.db_breed=b.db_breed and a.db_breed=c.db_code";

push @sql_statements,
"insert into tmp1_1 (breed,year,borns,sel,parent) select c.short_name,'Total',a.number,b.number,'sire' from tmp1_t_sire a, tmp1_t_sire_s b, codes c where a.db_breed=b.db_breed and a.db_breed=c.db_code";

#push @sql_statements,
#"drop table tmp1_t_dam";

#push @sql_statements,
#"drop table tmp1_t_sire";

#push @sql_statements,
#"drop table tmp1_t_dam_s";

#push @sql_statements,
#"drop table tmp1_t_sire_s";

push @sql_statements,
"alter table tmp1_pas alter year type text";

push @sql_statements,
"insert into tmp1_pas (breed,year,number) select breed,'Total',sum(number) from tmp1_pas group by breed";

push @sql_statements,
 $sql_statment2service7 if $sql_statment2service7;

push @sql_statements,
 $sql_statment2service8 if $sql_statment2service8;

push @sql_statements,
 $sql_statment2service9 if $sql_statment2service9;

push @sql_statements,
 $sql_statment2service10 if $sql_statment2service10;

push @sql_statements,
 $sql_statment2service11 if $sql_statment2service11;

push @sql_statements,
 $sql_statment2service12 if $sql_statment2service12;


### SQL For age structure males and females#

push @sql_statements,
"select b.short_name as breed,a.year,a.age,'sire'::varchar as
parent,count(*)::numeric as number
into tmp1_age_male from
tmp1_sires_noffsp a, codes b where a.db_breed=b.db_code group by
b.short_name,a.year,a.age";

push @sql_statements,
"select b.short_name as breed,a.year,a.age,'dam'::varchar as
parent,count(*)::numeric as number
into tmp1_age_female from
tmp1_dams_noffsp a, codes b where a.db_breed=b.db_code group by
b.short_name,a.year,a.age";

push @sql_statements,
"select * into tmp1_age from tmp1_age_male UNION select * from tmp1_age_female";

push @sql_statements,
"insert into tmp1_age (breed,year,age,parent,number) select breed,year,88888
,'sire'::varchar,sum(number) from tmp1_age_male where age>15
group by breed,year order by year";

push @sql_statements,
"insert into tmp1_age (breed,year,age,parent,number) select breed,year,88888
,'dam'::varchar,sum(number) from tmp1_age_female where age>15
group by breed,year order by year";

push @sql_statements,
"delete from tmp1_age where age>15 and age<88888";

push @sql_statements,
"update tmp1_age set age=16 where age=88888";

push @sql_statements,
"insert into tmp1_age (breed,year,age,parent,number) select 
b.short_name,a.year,17,'sire'::varchar,round(avg(age),1) from
tmp1_sires_noffsp a, codes b where a.db_breed=b.db_code group by
b.short_name,a.year";

push @sql_statements,
"insert into tmp1_age (breed,year,age,parent,number) select
b.short_name,a.year,17,'dam'::varchar,round(avg(age),1) from
tmp1_dams_noffsp a, codes b where a.db_breed=b.db_code group by
b.short_name,a.year";

########SQL for creating number of parity for the dams

push @sql_statements,
"select b.short_name as breed,a.db_dam as dam,a.birth_dt into tmp1_parity from
animal a,codes b where a.db_dam>2 and a.db_breed=b.db_code and a.birth_dt
notnull and db_breed $sine
$dbb group by b.short_name,a.db_dam,a.birth_dt";

push @sql_statements,
"alter table tmp1_parity add year numeric";

push @sql_statements,
"alter table tmp1_parity add parity numeric";

push @sql_statements,
"create index ind_tmp1_parity on tmp1_parity (dam,birth_dt)";

push @sql_statements,
"update tmp1_parity set parity=(select count(*) from tmp1_parity b where
    tmp1_parity.dam=b.dam and b.birth_dt <= tmp1_parity.birth_dt),year=date_part('year',tmp1_parity.birth_dt)";

push @sql_statements,
"update tmp1_parity set parity=16 where parity>15";
####
#### Family sizes based on births

#All off-spring
push @sql_statements,
"select b.short_name as breed,a.db_sire as id_nr,'sire'::varchar as parent,count(*)
into tmp1_family_sires from animal a,codes b where a.db_sire >3 and a.birth_dt
notnull and
a.db_breed $sine $dbb and a.db_breed=b.db_code group by b.short_name,a.db_sire";

push @sql_statements,
"select b.short_name as breed,a.db_dam as id_nr,'dam'::varchar as parent,count(*)
into tmp1_family_dams from animal a,codes b where a.db_dam >3 and a.birth_dt
notnull and
a.db_breed $sine $dbb and a.db_breed=b.db_code group by b.short_name,a.db_dam";

push @sql_statements,
"select * into tmp1_family_all from tmp1_family_sires UNION select * from tmp1_family_dams";

push @sql_statements,
"alter table tmp1_family_all add year numeric";

push @sql_statements,
"update tmp1_family_all set year=(select date_part('year',animal.birth_dt) from animal where id_nr=animal.db_animal)";

#Selected off-spring

push @sql_statements,
"create index ind_tmp1_parents on tmp1_parents (parent)";

push @sql_statements,
"create index ind_tmp1_parents_s on tmp1_sons (parent)";

push @sql_statements,
"create index ind_tmp1_parents_d on tmp1_daug (parent)";

push @sql_statements,
"select b.short_name as breed,a.db_sire as id_nr,'sire'::varchar as
parent,count(a.db_animal) into tmp1_family_sel_sires from animal a,codes b,
tmp1_parents c where a.db_sire >3 and a.db_breed $sine $dbb and a.birth_dt
notnull and a.db_animal=c.parent and a.db_breed=b.db_code group by b.short_name,a.db_sire";

push @sql_statements,
"select b.short_name as breed,a.db_dam as id_nr,'dam'::varchar as
parent,count(a.db_animal) into tmp1_family_sel_dams from animal a,codes b,
tmp1_parents c where a.db_dam >3 and a.db_breed $sine $dbb and a.birth_dt
notnull and a.db_animal=c.parent
 and a.db_breed=b.db_code group by b.short_name,a.db_dam";

push @sql_statements,
"select * into tmp1_family_sel from tmp1_family_sel_sires UNION select * from tmp1_family_sel_dams";

push @sql_statements,
"alter table tmp1_family_sel add year numeric";

push @sql_statements,
"update tmp1_family_sel set year=(select date_part('year',animal.birth_dt) from animal where id_nr=animal.db_animal)";

###Famiy size by male and female selected offspring based om births
push @sql_statements,
"select b.short_name as breed,a.db_sire as id_nr,'sire'::varchar as
parent,count(a.db_animal) into tmp1_sons_sires from animal a,codes b,
tmp1_sons c where a.db_sire >3 and a.db_breed $sine $dbb and a.birth_dt
notnull and a.db_animal=c.parent
    and a.db_breed=b.db_code group by b.short_name,a.db_sire";

push @sql_statements,
"select b.short_name as breed,a.db_dam as id_nr,'dam'::varchar as
parent,count(a.db_animal) into tmp1_sons_dams from animal a,codes b,
tmp1_sons c where a.db_dam >3 and a.db_breed $sine $dbb and a.birth_dt notnull
and a.db_animal=c.parent
 and a.db_breed=b.db_code group by b.short_name,a.db_dam";

push @sql_statements,
"select * into tmp1_family_sel_s from tmp1_sons_sires UNION select * from tmp1_sons_dams";

push @sql_statements,
"alter table tmp1_family_sel_s add year numeric";

push @sql_statements,
"update tmp1_family_sel_s set year=(select date_part('year',animal.birth_dt) from animal where id_nr=animal.db_animal)";

push @sql_statements,
"select b.short_name as breed,a.db_sire as id_nr,'sire'::varchar as
parent,count(a.db_animal) into tmp1_daug_sires from animal a,codes b,
tmp1_daug c where a.db_sire >3 and a.db_breed $sine $dbb and a.birth_dt
notnull and a.db_animal=c.parent
    and a.db_breed=b.db_code group by b.short_name,a.db_sire";

push @sql_statements,
"select b.short_name as breed,a.db_dam as id_nr,'dam'::varchar as
parent,count(a.db_animal) into tmp1_daug_dams from animal a,codes b,
tmp1_daug c where a.db_dam >3 and a.db_breed $sine $dbb and a.birth_dt notnull
and a.db_animal=c.parent
 and a.db_breed=b.db_code group by b.short_name,a.db_dam";

push @sql_statements,
"select * into tmp1_family_sel_d from tmp1_daug_sires UNION select * from tmp1_daug_dams";

push @sql_statements,
"alter table tmp1_family_sel_d add year numeric";

push @sql_statements,
"update tmp1_family_sel_d set year=(select date_part('year',animal.birth_dt) from animal where id_nr=animal.db_animal)";

push @sql_statements,
"select year, breed,min(count) as a_min_sire,max(count) as a_max_sire,round(avg(count),1) as a_avg_sire
into tmp1_family
from tmp1_family_all where parent='sire' and year notnull
group by breed,year
order by year";

push @sql_statements,
"alter table tmp1_family add a_min_dam numeric";

push @sql_statements,
"alter table tmp1_family add a_max_dam numeric";

push @sql_statements,
"alter table tmp1_family add a_avg_dam numeric";

push @sql_statements,
"update tmp1_family set a_min_dam=x.a_min_dam,a_max_dam=x.a_max_dam,a_avg_dam=x.a_avg_dam
from
(select year,breed,min(count) as a_min_dam,max(count) as a_max_dam,round(avg(count),1) as a_avg_dam
from tmp1_family_all where parent='dam' and year notnull
group by breed,year
order by year) as x
where tmp1_family.year=x.year and tmp1_family.breed=x.breed";

push @sql_statements,
"insert into tmp1_family (year,breed,a_min_sire,a_max_sire,a_avg_sire) 
select 9999 as year, breed,min(count) as a_min_sire,max(count) as a_max_sire,round(avg(count),1) as a_avg_sire
from tmp1_family_all where parent='sire' and year notnull group by breed";

push @sql_statements,
"update tmp1_family set a_min_dam=x.a_min_dam,a_max_dam=x.a_max_dam,a_avg_dam=x.a_avg_dam
from
(select 9999 as year,breed,min(count) as a_min_dam,max(count) as a_max_dam,round(avg(count),1) as a_avg_dam
from tmp1_family_all where parent='dam' and year notnull  group by breed) as x
where tmp1_family.year=x.year and tmp1_family.breed=x.breed";

push @sql_statements,
"alter table tmp1_family add s_min_sire numeric";

push @sql_statements,
"alter table tmp1_family add s_max_sire numeric";

push @sql_statements,
"alter table tmp1_family add s_avg_sire numeric";

push @sql_statements,
"update tmp1_family set s_min_sire=x.s_min_sire,s_max_sire=x.s_max_sire,s_avg_sire=x.s_avg_sire
from
(select year,breed,min(count) as s_min_sire,max(count) as s_max_sire,round(avg(count),1) as s_avg_sire
from tmp1_family_sel where parent='sire' and year notnull
group by breed,year
order by year) as x
where tmp1_family.year=x.year and tmp1_family.breed=x.breed";

push @sql_statements,
"alter table tmp1_family add s_min_dam numeric";

push @sql_statements,
"alter table tmp1_family add s_max_dam numeric";

push @sql_statements,
"alter table tmp1_family add s_avg_dam numeric";

push @sql_statements,
"update tmp1_family set s_min_dam=x.s_min_dam,s_max_dam=x.s_max_dam,s_avg_dam=x.s_avg_dam
from
(select year,breed,min(count) as s_min_dam,max(count) as s_max_dam,round(avg(count),1) as s_avg_dam
from tmp1_family_sel where parent='dam' and year notnull
group by breed,year
order by year) as x
where tmp1_family.year=x.year and tmp1_family.breed=x.breed";

push @sql_statements,
"update tmp1_family set s_min_sire=x.s_min_sire,s_max_sire=x.s_max_sire,s_avg_sire=x.s_avg_sire
from
(select 9999 as year,breed,min(count) as s_min_sire,max(count) as s_max_sire,round(avg(count),1) as s_avg_sire
from tmp1_family_sel where parent='sire' and year notnull group by breed) as x
where tmp1_family.year=x.year and tmp1_family.breed=x.breed";

push @sql_statements,
"update tmp1_family set s_min_dam=x.s_min_dam,s_max_dam=x.s_max_dam,s_avg_dam=x.s_avg_dam
from
(select 9999 as year,breed,min(count) as s_min_dam,max(count) as s_max_dam,round(avg(count),1) as s_avg_dam
from tmp1_family_sel where parent='dam' and year notnull group by breed) as x
where tmp1_family.year=x.year and tmp1_family.breed=x.breed";

push @sql_statements,
"alter table tmp1_family add ss_min_sire numeric";

push @sql_statements,
"alter table tmp1_family add ss_max_sire numeric";

push @sql_statements,
"alter table tmp1_family add ss_avg_sire numeric";

push @sql_statements,
"update tmp1_family set ss_min_sire=x.ss_min_sire,ss_max_sire=x.ss_max_sire,ss_avg_sire=x.ss_avg_sire
from
(select year,breed,min(count) as ss_min_sire,max(count) as ss_max_sire,round(avg(count),1) as ss_avg_sire
from tmp1_family_sel_s where parent='sire' and year notnull
group by breed,year
order by year) as x
where tmp1_family.year=x.year and tmp1_family.breed=x.breed";

push @sql_statements,
"alter table tmp1_family add ss_min_dam numeric";

push @sql_statements,
"alter table tmp1_family add ss_max_dam numeric";

push @sql_statements,
"alter table tmp1_family add ss_avg_dam numeric";

push @sql_statements,
"update tmp1_family set ss_min_dam=x.ss_min_dam,ss_max_dam=x.ss_max_dam,ss_avg_dam=x.ss_avg_dam
from
(select year,breed,min(count) as ss_min_dam,max(count) as ss_max_dam,round(avg(count),1) as ss_avg_dam
from tmp1_family_sel_s where parent='dam' and year notnull
group by breed,year
order by year) as x
where tmp1_family.year=x.year and tmp1_family.breed=x.breed";

push @sql_statements,
"update tmp1_family set ss_min_sire=x.ss_min_sire,ss_max_sire=x.ss_max_sire,ss_avg_sire=x.ss_avg_sire
from
(select 9999 as year,breed,min(count) as ss_min_sire,max(count) as ss_max_sire,round(avg(count),1) as ss_avg_sire
from tmp1_family_sel_s where parent='sire' and year notnull group by breed) as x
where tmp1_family.year=x.year and tmp1_family.breed=x.breed";

push @sql_statements,
"update tmp1_family set ss_min_dam=x.ss_min_dam,ss_max_dam=x.ss_max_dam,ss_avg_dam=x.ss_avg_dam
from
(select 9999 as year,breed,min(count) as ss_min_dam,max(count) as ss_max_dam,round(avg(count),1) as ss_avg_dam
from tmp1_family_sel_s where parent='dam' and year notnull group by breed) as x
where tmp1_family.year=x.year and tmp1_family.breed=x.breed";

push @sql_statements,
"alter table tmp1_family add sd_min_sire numeric";

push @sql_statements,
"alter table tmp1_family add sd_max_sire numeric";

push @sql_statements,
"alter table tmp1_family add sd_avg_sire numeric";

push @sql_statements,
"update tmp1_family set sd_min_sire=x.sd_min_sire,sd_max_sire=x.sd_max_sire,sd_avg_sire=x.sd_avg_sire
from
(select year,breed,min(count) as sd_min_sire,max(count) as sd_max_sire,round(avg(count),1) as sd_avg_sire
from tmp1_family_sel_d where parent='sire' and year notnull
group by breed,year
order by year) as x
where tmp1_family.year=x.year and tmp1_family.breed=x.breed";

push @sql_statements,
"alter table tmp1_family add sd_min_dam numeric";

push @sql_statements,
"alter table tmp1_family add sd_max_dam numeric";

push @sql_statements,
"alter table tmp1_family add sd_avg_dam numeric";

push @sql_statements,
"update tmp1_family set sd_min_dam=x.sd_min_dam,sd_max_dam=x.sd_max_dam,sd_avg_dam=x.sd_avg_dam
from
(select year,breed,min(count) as sd_min_dam,max(count) as sd_max_dam,round(avg(count),1) as sd_avg_dam
from tmp1_family_sel_d where parent='dam' and year notnull
group by breed,year
order by year) as x
where tmp1_family.year=x.year and tmp1_family.breed=x.breed";

push @sql_statements,
"update tmp1_family set sd_min_sire=x.sd_min_sire,sd_max_sire=x.sd_max_sire,sd_avg_sire=x.sd_avg_sire
from
(select 9999 as year,breed,min(count) as sd_min_sire,max(count) as sd_max_sire,round(avg(count),1) as sd_avg_sire
from tmp1_family_sel_d where parent='sire' and year notnull group by breed) as x
where tmp1_family.year=x.year and tmp1_family.breed=x.breed";

push @sql_statements,
"update tmp1_family set sd_min_dam=x.sd_min_dam,sd_max_dam=x.sd_max_dam,sd_avg_dam=x.sd_avg_dam
from
(select 9999 as year,breed,min(count) as sd_min_dam,max(count) as sd_max_dam,round(avg(count),1) as sd_avg_dam
from tmp1_family_sel_d where parent='dam' and year notnull group by breed) as x
where tmp1_family.year=x.year and tmp1_family.breed=x.breed";

########Generation interval:Generation interval is the average age of parents
#of those animals who have produced an offspring

push @sql_statements,
"select a.parent as progeny,a.sex as sex,c.short_name as
breed,b.birth_dt,b.db_sire as sire,b.db_dam as dam into tmp1_gen_1 from tmp1_parents a, animal
b, codes c where a.parent=b.db_animal and b.db_breed=c.db_code and b.db_breed $sine $dbb";

push @sql_statements,
"alter table tmp1_gen_1 add age_s numeric";

push @sql_statements,
"alter table tmp1_gen_1 add age_d numeric";

push @sql_statements,
"alter table tmp1_gen_1 add age_avg numeric";

push @sql_statements,
"update tmp1_gen_1 set age_s=tmp1_gen_1.birth_dt-(select birth_dt from animal
where tmp1_gen_1.sire=animal.db_animal)";

push @sql_statements,
"update tmp1_gen_1 set age_d=tmp1_gen_1.birth_dt-(select birth_dt from animal
    where tmp1_gen_1.dam=animal.db_animal)";

push @sql_statements,
"update tmp1_gen_1 set age_avg=CASE when age_s>0 and age_d>0 then round(((age_s+age_d)/2),0)
                                 when age_s>0 and (age_d=0 or age_d is null) then age_s
                                 when age_d>0 and (age_s=0 or age_s is null) then age_d
                                 else NULL
                                 END";
if ($ges_len eq 'year'){
push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_s)/365),1) as
ss,count(*) as ssn into tmp1_gen_ss from tmp1_gen_1 where sex='$mm' and
age_s>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_s)/365),1) as
sd,count(*) as sdn into tmp1_gen_sd from tmp1_gen_1 where sex='$ff' and
age_s>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_d)/365),1) as
ds,count(*) as dsn into tmp1_gen_ds from tmp1_gen_1 where sex='$mm' and
age_d>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_d)/365),1) as
dd,count(*) as ddn into tmp1_gen_dd from tmp1_gen_1 where sex='$ff' and
age_d>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_s)/365),1) as
sire,count(*) as siren into tmp1_gen_sires from tmp1_gen_1 where 
age_s>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_d)/365),1) as
dam,count(*) as damn into tmp1_gen_dams from tmp1_gen_1 where 
age_d>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_avg)/365),1) as
pop,count(*) as popn into tmp1_gen_sire_dam from tmp1_gen_1 where
age_avg>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";
} elsif ($ges_len eq 'month'){
push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_s)/30.4),1) as
ss,count(*) as ssn into tmp1_gen_ss from tmp1_gen_1 where sex='$mm' and
age_s>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_s)/30.4),1) as
sd,count(*) as sdn into tmp1_gen_sd from tmp1_gen_1 where sex='$ff' and
age_s>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_d)/30.4),1) as
ds,count(*) as dsn into tmp1_gen_ds from tmp1_gen_1 where sex='$mm' and
age_d>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_d)/30.4),1) as
dd,count(*) as ddn into tmp1_gen_dd from tmp1_gen_1 where sex='$ff' and
age_d>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_s)/30.4),1) as
sire,count(*) as siren into tmp1_gen_sires from tmp1_gen_1 where 
age_s>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_d)/30.4),1) as
dam,count(*) as damn into tmp1_gen_dams from tmp1_gen_1 where 
age_d>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_avg)/30.4),1) as
pop,count(*) as popn into tmp1_gen_sire_dam from tmp1_gen_1 where
age_avg>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";
} else {
push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_s)),1) as
ss,count(*) as ssn into tmp1_gen_ss from tmp1_gen_1 where sex='$mm' and
age_s>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_s)),1) as
sd,count(*) as sdn into tmp1_gen_sd from tmp1_gen_1 where sex='$ff' and
age_s>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_d)),1) as
ds,count(*) as dsn into tmp1_gen_ds from tmp1_gen_1 where sex='$mm' and
age_d>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_d)),1) as
dd,count(*) as ddn into tmp1_gen_dd from tmp1_gen_1 where sex='$ff' and
age_d>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_s)),1) as
sire,count(*) as siren into tmp1_gen_sires from tmp1_gen_1 where 
age_s>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_d)),1) as
dam,count(*) as damn into tmp1_gen_dams from tmp1_gen_1 where 
age_d>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";

push @sql_statements,
"select breed,date_part('year',birth_dt) as year,round((avg(age_avg)),1) as
pop,count(*) as popn into tmp1_gen_sire_dam from tmp1_gen_1 where
age_avg>0 group by breed,date_part('year',birth_dt) order by
date_part('year',birth_dt)";
}
push @sql_statements,
"select distinct breed,date_part('year',birth_dt) as year into tmp1_gen_temp
from tmp1_gen_1";

push @sql_statements,
"select
a.breed,a.year,b.ss,b.ssn,c.sd,c.sdn,d.ds,d.dsn,f.dd,f.ddn,g.sire,g.siren,h.dam,h.damn,i.pop,i.popn
into tmp1_gen 
from tmp1_gen_temp a, tmp1_gen_ss b, tmp1_gen_sd c, tmp1_gen_ds d,tmp1_gen_dd f, tmp1_gen_sires g, tmp1_gen_dams h, tmp1_gen_sire_dam i 
where a.breed=b.breed and a.year=b.year and a.breed=c.breed and a.year=c.year
    and a.breed=d.breed and a.year=d.year and a.breed=f.breed and a.year=f.year
    and a.breed=g.breed and a.year=g.year and a.breed=h.breed and a.year=h.year
    and a.breed=i.breed and a.year=i.year";

push @sql_statements,
"alter table tmp1_gen alter year type text";

push @sql_statements,
"insert into tmp1_gen (breed,year,ss,ssn,sd,sdn,ds,dsn,dd,ddn,sire,siren,dam,damn,pop,popn) 
select
breed,'Total',round((sum(ss*ssn)/sum(ssn)),1),null,round((sum(sd*sdn)/sum(sdn)),1),null,round((sum(ds*dsn)/sum(dsn)),1),null,round((sum(dd*ddn)/sum(ddn)),1),null,round((sum(sire*siren)/sum(siren)),1),null,round((sum(dam*damn)/sum(damn)),1),null,round((sum(pop*popn)/sum(popn)),1),null
from tmp1_gen group by breed";


#####SQL end


if ( defined $opt_d ){ # drop all tables
   foreach ( @sql_statements ){
      s/\n/ /gm;
      tr/A-Z/a-z/;

      # note: this currently works only for the PostgreSQL syntax 'select ... into table' which
      # (AFAIK) does not exist in Oracle. So it's only a quick hack. (25.6.2001 - heli)
      my @table_names = $dbh->tables;

      if ( /\s+into\s+(temporary\s+|temp\s+)?(table\s+)?(\b\S+\b)/i ){
         local $dbh->{RaiseError} = 0;
         if ( grep (/$3/, @table_names) ){
            print "Dropping table $3 ...\n";
             $apiis->DataBase->sys_sql( "drop table $3" );
             $apiis->DataBase->sys_dbh->commit;
         }
      }
   }
} else {
   if ( defined $opt_o ){
      unlink $opt_o;
      open( STDOUT, ">>$opt_o" )
          or die sprintf "Problems opening file %s: %s\n", $opt_o, $!;
      open( STDERR, ">>$opt_o")
          or die sprintf "Problems opening file %s: %s\n", $opt_o, $!;
      my $now = $apiis->now;
      print "Database: $db_name ($db_driver), User: $db_user\n\n";
      print "Query explain from $now:\n" .
            "====================" . '=' x length($now), "\n";
   }
   
   
   my ( $i, $start, $end );
   $opt_r ? ($start = $opt_r - 1) : ($start = 0);
   $opt_n ? ($end = $start + $opt_n - 1) : ($end = $#sql_statements);
   
   for ( $i = $start; $i <= $end; $i++ ){
      my $this_statement = $sql_statements[$i];
      $this_statement =~ s/^\s*//; # remove leading whitespace
      $this_statement =~ s/\s*$//; # remove trailing whitespace

      # just get the table name:
      my $tmp_statement = $this_statement;
      $tmp_statement =~ s/\n/ /gm;
      $tmp_statement =~ tr/A-Z/a-z/;

      # note: this currently works only for the PostgreSQL syntax 'select ... into table' which
      # (AFAIK) does not exist in Oracle. So it's only a quick hack. (25.6.2001 - heli)

      if ( $tmp_statement =~ /\s+into\s+(temporary\s+|temp\s+)?(table\s+)?(\b\S+\b)/i ){
         push @temp_tables_used, $3;
      }

      my $ddl_statement = $this_statement;
      $this_statement =~ s/\s*DDL:?\s*//; # remove tag for DDL
      my $remaining = $#sql_statements - $i + 1;
   
      print "Query ", $i + 1, ":\n$this_statement\n\n" if $debug;

      if ( $opt_x and $ddl_statement !~ /\s*DDL:?\s*/ ){
         print "\nExplain plan section for this query:\n";
         my %settings = %{ DBspecific( $db_driver ) };
         if ( $settings{EXPLAIN} ){
            my $prepend = $settings{EXPLAIN};
            my $sql = $prepend . ' ' . $ddl_statement;
            eval { $apiis->DataBase->sys_sql($sql) }; # or sys_sql()?
            die "Error in statement $i:\n$@\nRemaining $remaining SQL statements canceled.\n" if $@;
         } else {
            print "   .... not available\n";
         }
      }
   
      # now the real work:
      my ($sec_a,$min_a,$hour_a,$mday_a,$mon_a,$year_a,$wday_a,$yday_a,$isdst_a) = localtime(time);
      $year_a = 1900 + $year_a;
      $mon_a = 1 + $mon_a;
#     eval { $apiis->DataBase->sys_sql($this_statement) }; # or sys_sql()?
      my $st = $apiis->DataBase->sys_sql($this_statement) ; # or sys_sql()?
      $apiis->check_status;

      if ( $st->status ) {
         for my $error ($st->errors){
           my $ww =  $error->severity;
           if ($ww ne 'WARNING'){
              $error->print;
              die "Error in statement:\n Remaining $remaining SQL statements canceled.\n";
            }
         }
#         }
      }
      
      $apiis->DataBase->sys_dbh->commit unless $@;
      print "Commit\n" if $debug;
      my ($sec_b,$min_b,$hour_b,$mday_b,$mon_b,$year_b,$wday_b,$yday_b,$isdst_b) = localtime(time);
      $year_b = 1900 + $year_b;
      $mon_b = 1 + $mon_b;
      my ($d,$h,$m,$s) = Delta_DHMS($year_a,$mon_a,$mday_a, $hour_a,$min_a,$sec_a,
                                        $year_b,$mon_b,$mday_b, $hour_b,$min_b,$sec_b);
      $h += $d * 24;
      print "query time elapsed: $h:$m:$s\n" if $debug;
#      die "Error in statement $i:\n$@\nRemaining $remaining SQL statements canceled.\n" if $@;
        
      print '-' x 60, "\n" if $debug;
   }
   my ($sec2,$min2,$hour2,$mday2,$mon2,$year2,$wday2,$yday2,$isdst2) = localtime(time);
   $year2 = 1900 + $year2;
   $mon2 = 1 + $mon2;
   my ($Dd,$Dh,$Dm,$Ds) = Delta_DHMS($year1,$mon1,$mday1, $hour1,$min1,$sec1,
                                     $year2,$mon2,$mday2, $hour2,$min2,$sec2);
   
   $Dh += $Dd * 24;
   print "total time elapsed: $Dh:$Dm:$Ds\n" if $debug;
}

if ( defined $opt_c and not defined $opt_d ){ # do count(*) on auxiliary tables:
   my @temp_tables_used;
   my $sql = "select tablename from pg_tables";
   my $sth = $apiis->DataBase->sys_sql( "$sql");
   while ( my $data_ref = $sth->handle->fetch ) {
         my $table = $$data_ref[0];
         if ($table =~ /^tmp1/){
            push @temp_tables_used, $table;
         }
   }
   
   if ($debug){
       print "\nNumber of records created: ";
       foreach my $this_table (@temp_tables_used) {
           my $sth = $apiis->DataBase->sys_sql("select count(*) from $this_table");
           while ( my $data_ref = $sth->handle->fetch ) {
               my $counts = $$data_ref[0];
               print "$this_table: $counts records\n";
           }
       }
   }
}

##############################################################################
