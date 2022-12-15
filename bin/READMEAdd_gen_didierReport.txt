NEEDS UPDATING ONCE ALL THE CODE IS UPDATED AND STREAMLINED

This is the procedure to compute the effective population size on the basis
of the average additive relationship of animals within a birth year.

#####################################################################
# tmp1 and temp2 tables from report 1 and 2 must exist because      #
# this report use some of these tables to skip re-calculating them. #
#####################################################################
To create a report:

Run Add_gen_didierReport.pl -p breedprg -d demo -w Demo -b DL -g 2 -s m

which will create ./Additivegenetic_DL.ps and ./Additivegenetic_DL.pdf

Attension: Care must be taken that if option -b is not specified 
the program will run for each breed in the database.
This option will take very long.

usage:
  require gnuplot 4.2  !!!!!
   -h this message
   -d <> database user
   -w <> database password
   -p <project_name>
   -b <> database short_name for breed 
   -g <> generation interval if you want a fixed generation else
         the generation will be pigup from the Population report 
   -s <> your table codes short_name for Male (Default = Male)	
