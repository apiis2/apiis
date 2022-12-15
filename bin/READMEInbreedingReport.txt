THE FOLLOWING TEXT IS NOT UPTODATE ANY MORE AS THE COMPLETE STRUCTURE HAS BEEN MODIFIED
TO ALLOW LARGE POPULATIONS TO BE PROCESSED

CURRENTYL THE SEQUENCE OF EVENTS IS:
1. Inbreeding-report
   this is a wrapper that executes the following separate processes

1.1 agr-extract_files - extracts file for agr-run_parallel
1.2 agr-run_parallel  - computes AGR per birth year by executing
                        in parallel add_gen_didier
1.3 inbreeding_report - create tex output for the complete Inbreeding
                        report, also by utilizing the output from 1.2


THE FOLLOWING NEEDS TO GET UPDATED

It seems that breedprg is created as user demo with password Demo
                                                                                                
To create the reports you need to run:
Create_inbreeding_tables.pl -p breedprg -d demo -w Demo -k 1
to make sure none of the tmp2_* tables exist.

Then run:
Create_inbreeding_tables.pl -p breedprg -d demo -w Demo -b 42 -r -c 1 -s -e BREED
option -r will Re-calqulate gene_stuf
The tmp2_* tables are now created.

Other options are:

 -h this message
 -f formatted print of external animal id
 -a print all animals with inbreeding coefficient
 -o print only animals with inbreeding coefficient
 -u <> unknown animal
 -r Re-calqulate gene_stuf
 -s make faster but need much RAM
 -t <filename> create numerical sorted ped and translation file
 -p <project_name>
 -d <> database user
 -w <> database password
 -c Count all tmp2 tables
 -k Delete all tmp2 tables
 -e Your name for BREED in class = 'BREED' in table codes (Default = $brd)
 -b database short_name for breed (If not entered all breeds will run)
 -g 1 - n for max generation depth in pedigree completeness (Default = 5)



Run now: InbreedingReport
 options are:
    -h    help, this message

    required:
    -p <project_name>
    -u <> database user
    -P <> database password
    -b <> breed
    optional:
    -n <> no of animals (agr-run_parallel)
    -e <> name of class for breed, default is BREED
    -m <> your table codes short_name for male, default is male
          (agr-extract_files)
    -g <> generation interval if you want a fixed generation, else
          the generation will be picked up from Population report
          (agr-extract_files)
    -t    creates a tar archive of all relevant files
          (agr-extract_files and agr-run_parallel)

InbreedingReport.pl -p breedprg -d demo -w Demo -b DUR -m Male -e BREED 
wich will create ./InbreedingDUR.pdf and ./InbreedingDUR.ps files.
