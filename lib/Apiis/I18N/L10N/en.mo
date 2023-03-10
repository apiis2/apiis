# SOME DESCRIPTIVE TITLE.
# Copyright (C) YEAR THE PACKAGE'S COPYRIGHT HOLDER
# This file is distributed under the same license as the PACKAGE package.
# FIRST AUTHOR <EMAIL@ADDRESS>, YEAR.
#
#, fuzzy
msgid ""
msgstr ""

msgid "No menu for this language"
msgstr "No menu for this language"

msgid "No sessionID"
msgstr "No sessionID"

msgid "Wrong password"
msgstr "Wrong password"

msgid "User unknown"
msgstr "User unknown"

msgid "Can not execute Login-SQL without errors"
msgstr "Can not execute Login-SQL without errors"

msgid "Fehler beim Erstellen der Session-ID"
msgstr "Error creating the session ID "

msgid "Can not execute Login-SQL without errors"
msgstr "Can not execute Login-SQL without errors"

msgid "Sie besitzen nicht die erforderlichen Zugriffsrechte für das Formular [_1]"
msgstr "You do not have the required access rights for the form [_1] "

msgid "Die Anmeldung ist nicht mehr gültig"
msgstr "The registration is no longer valid "

msgid "Kein Formular für die Kombination [_1] verfügbar"
msgstr "No form available for the combination [_1]"

# "Project-Id-Version: PACKAGE VERSION\n"
# "POT-Creation-Date: YEAR-MO-DA HO:MI+ZONE\n"
# "PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n"
# "Last-Translator: FULL NAME <EMAIL@ADDRESS>\n"
# "Language-Team: LANGUAGE <LL@li.org>\n"
# "MIME-Version: 1.0\n"
# "Content-Type: text/plain; charset=CHARSET\n"
# "Content-Transfer-Encoding: 8bit\n"

#: bin/mkl10n:45 bin/mkl10n:51
msgid "mkl10n_USAGE_MESSAGE"
msgstr ""
"usage: mkl10n [options] <lang>\n"
"Scans APIIS_HOME/{bin|lib|etc} for localised messages and writes a file\n"
"APIIS_HOME/lib/Apiis/I18N/L10N/<lang>.mo\n"
"options:\n"
"       -h            prints help message and exits\n"
"       -q            quiet, don't print informational messages\n"
"       -m            man page, print detail documentation\n"
"       -p <project>  localize messages only for <project>.\n"
"                     The .mo file is written to the same location in APIIS_LOCAL.\n"


#: bin/check_integrity:
msgid "check_integrity_USAGE_MESSAGE"
msgstr ""
"usage:\n"
"check_integrity -p <modelfile> [-hvtseago]\n"
"                -h                      --> Help\n"
"                -v                      --> Version\n"
"                -p <modelfile>          --> Name of model file\n"
"                -t <table>              --> Name of table to check\n"
"                -s <number>             --> stop after <number> records\n"
"                -e                      --> written into error file\n"
"                -D                      --> Tables have a 'dirty' flag/column\n"
"                -g <output file>        --> Name of output file (default = check_integrity.erg)\n"

#: bin/xml2model.pl:
msgid "xml2model.pl_USAGE_MESSAGE"
msgstr ""
"usage:\n"
"xml2model.pl reverses a xml file to a model file \n"
"usage: xml2model.pl <project_name>\n"
"       xml2model.pl -h | -v\n"
"          -h      Help\n"
"          -v      Version\n"
"Example: xml2model.pl minipigs\n"

#: bin/show_rules.pm
msgid "show_rules_USAGE_MESSAGE"
msgstr ""
"usage:\n"
"show_rules -h   Help\n"
"           -v   Version\n"
"           -o <output file>\n"
"           -p <model file>\n"

#: bin/apiish
msgid "apiish_USAGE_MESSAGE"
msgstr ""
"usage:\n"
"apiish     -m Model file\n"
"           -h Help\n"

#: bin/mksql
msgid "mksql_USAGE_MESSAGE"
msgstr ""
"usage: mksql -f <modelfile> [-tdns]\n"
"mksql -h                Help\n"
"      -m                show man page\n"
"      -v                Version\n"
"      -f <modelfile>    Name of model file (required)\n"
"      -t <table>        only for table <table>\n"
"      -d                delete: DROP-statements are not commented out!\n"
"      -n                create no views\n"
"      -s                write to STDOUT\n"

#: bin/model2xml.pl:
msgid "model2xml.pl_USAGE_MESSAGE"
msgstr ""
"usage:\n"
"model2xml.pl reverses a model file to a xm file \n"
"usage: model2xml.pl <project_name>\n"
"       model2xml.pl -h | -v\n"
"          -h      Help\n"
"          -v      Version\n"
"Example: model2xml.pl minipigs\n"

#: bin/Report
msgid "Report_USAGE_MESSAGE"
msgstr ""
"usage: Report -r <reportname> -o <outputformat>\n"
"mksql -h                Help\n"
"      -r <name>         name of the report to run\n"
"      -o <format>       output format (html,pdf)\n"
"      -v                Version of this program\n"

#: bin/access_control.pl:
msgid "access_control_USAGE_MESSAGE"
msgstr ""
"\n"
"  NAME\n"
"       access_control.pl  - add and delete users, add and delete roles, grant roles to the users, revoke roles from the users,\n" 
"                            show users and roles already defined in the system\n"
"\n"
"  SYNOPIS\n"
"       access_control.pl  [OPTIONS]\n"
"\n"
"  COMMENTS\n"
"      If you want to add new role, first you have to define this role in APIIS_LOCAL/etc/Roles.conf file (initially all information\n" 
"      are taken from this file). Parameter [role name] has to be the same like you are defined in Roles.conf file (role name form\n"
"      quadrat brackets).\n"
"\n"
"  OPTIONS\n"
"         -p [project name]                       - sets project name (this paramaete has to be used with all other)\n"
"         -r [role name]                          - adds new role to the system; role name have to be defined in etc/Roles.conf file\n"
"         -u [login name]                         - adds new user to PostgreSQL and to the system\n"
"         -d user -r [login name]                 - deletes user [login name] from PostgreSQL and from the system\n"
"         -d role -r [role name]                  - deletes role [role name]  from the system\n"
"         -u [login name] -r [role name]          - assigns role to the user and also add role and user if they are not defined in the system\n"
"         -d revoke -u [user name] -r [role name] - revokes role [role name] from the user [login name]\n"
"         -s [roles|users]                        - prints all roles or users which are already defined in the system\n"
"         -v [login name]                         - creates system of view for the user [login name]\n"
"         -w [login name]                         - creates 'v_' views for each table unedr user schema [login name]\n"
"         -t [login name]                         - changes a password for defined user [login name]\n"
"         -h                                      - prints this help\n"

#: bin/load_db_from_INSPOOL
msgid "load_db_from_INSPOOL_USAGE_MESSAGE"
msgstr ""
"usage:                    [ * Required parameters]\n"
"load_db_from_INSPOOL_new.pl\n"
"   -h                    --> help\n"
"   -f  Model file      * --> Model file\n"
"   -s  Data stream     * --> List of data streams\n"
"   -v                    --> Version\n"
"   -q                    --> Verbose mode\n"
"   -p                    --> profiling\n"
"   -d [0-7]              --> debug\n"
"      1                  --> print more error messages on STDOUT\n"
"      5                  --> don't commit in load_db_from_INSPOOL (not in LoadObjects!)\n"
"      6                  --> run only one record\n"
"      7                  --> print detailed infos from ParsePseudoSQL\n"

#: bin/access_rights_manager.pl:
msgid "access_rights_manager_USAGE_MESSAGE"
msgstr ""
"\n"
"NAME\n"
"\n"
"access_rights_manager.pl -- perl script to manage of access rights. Add and delete users, add and delete roles,\n"
"                            grant roles to the users, revoke roles from the users, show users and roles\n"
"    	                    defined in the system.\n"
"\n"
"SYNOPSIS\n"
"\n"
"access_rights_manager.pl -p [project_name]  [OPTIONS]\n"
"\n"
"COMMENTS\n"
"\n"
"       If you want to add new role, first you have to define this role in \"APIIS_LOCAL/etc/AR_Batch.conf\" file (initially all\n"
"       information are taken from this file).\n"
"\n"
"OPTIONS\n"
"\n"
"       -p [project name]                       - set project name (always required); \n"
"       -s [roles|users]                        - print all roles or users which are already defined\n"
"                                                 in the system;\n"
"       -c [login name]                         - (re)create user access views (system tasks view \n"
"                                                 and database tasks view);\n"
"       -v [login name]                         - (re)create system of views in user schema;\n"
"       -w [login name]                         - (re)create 'v_' views for each table in user schema;\n"
"       -e [login name]                         - (re)create entry views in user schema [login name];\n"
"       -t [login name]                         - change a password for defined user;\n"
"       -r [role name]                          - add new role to the system; role name have \n"
"                                                 to be defined in \"etc/AR_Batch.conf\" file;\n"
"       -u [login name]                         - add new user to the PostgreSQL and to the system;\n" 
"       -u [login name]  -r [role1,role2,...]   - grant roles to the user;\n"
"       -d [user|user_p] -u [login name]        - delete user from the APIIS system (if you use \n"
"                                                 value 'user_p' then the user will be also removed\n" 
"                                                 from the PostgreSQL;\n"
"       -d role -r [role name]                  - delete role from the APIIS system;\n"
"       -u [login name] -r [role name]          - grant role to the user;\n"
"       -d revoke -u [user name] -r [role name] - revoke role from the user;\n"
"       -h                                      - print help;\n"
"\n"
"AUTHOR\n"
"Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>\n"
"(END)\n"
