
Take note, the ref_breedprg table for litter make
use of the following fields:

delivery_dt (birth date of offsping)
born_alive_no (total number born)
parity
that might be project specific.

To create the reports you need to run:

Create_Population_tables.pl -p breedprg -u demo -w Demo -m Males -f Females -d
To make sure none of the tmp1_* tables exist. The program will not run without
the -m and -f option.

Then run:
Create_Population_tables.pl -p breedprg -u demo -w Demo -b LW -l 1 -m Males -f Females -a BREED
to create al the tmp1_* tables. The program will not run without the -m and -f option.

Other options are:
 option -p <project>     => project
        -v               => Version
        -h               => Help
        -d               => drop all tables of these queries
        -l <number>      => If service and litter data is availible (1 = yes, 2 = no)
        -g <number>      => Gestation measure year, month or day (Default = year)
        -m               => DataBase ext_code for males in the codes table
        -f               => DataBase ext_code for females in the codes table
        -e               => Your field name in litter for number born alive (Default = born_alive_no)
        -i               => Your field name in litter for parity number (Default = parity)
        -j               => Your field name in litter for birth date (Default = delivery_dt)
        -c               => do count on temp. tables
        -x               => explain queries
        -o <out  file>   => output file for -x
        -r <number>      => restart execution at sql statement <number>
        -n <number>      => stop after <number> statements
        -u               => user
        -w               => passwoord
        -b               => DataBase short_name for breed (If not entered all breeds will run)
        -a               => Your name for BREED in class = 'BREED' in table codes (Default = BREED)

Finaly you can create the reports with:
PopulationReport.pl -p breedprg -u demo -w Demo -b LW -a BREED

Wich will create ./Population.pdf and ./Population.ps files.


The PopulationReport.pl require Gnuplot 4.2 for the graphics.
