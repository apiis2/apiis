# SOME DESCRIPTIVE TITLE.
# Copyright (C) YEAR THE PACKAGE'S COPYRIGHT HOLDER
# This file is distributed under the same license as the PACKAGE package.
# FIRST AUTHOR <EMAIL@ADDRESS>, YEAR.
#
#, fuzzy

msgid ""
msgstr ""

msgid "No menu for this language"
msgstr "Kein Menü gefunden für diese Spracheinstellung"

msgid "No sessionID"
msgstr "Keine Session-ID gefunden"

msgid "Wrong password"
msgstr "Paßwort ungültig"

msgid "User unknown"
msgstr "Nutzer unbekannt"

msgid "Can not execute Login-SQL without errors"
msgstr "Login-SQL ist fehlerhaft"

msgid "Fehler beim Erstellen der Session-ID"
msgstr "Fehler beim Erstellen der Session-ID"

msgid "Can not execute Login-SQL without errors"
msgstr "SQL ist fehlerhaft"

msgid "Sie besitzen nicht die erforderlichen Zugriffsrechte für das Formular [_1]"
msgstr "Sie besitzen nicht die erforderlichen Zugriffsrechte für das Formular [_1]"

msgid "Die Anmeldung ist nicht mehr gültig"
msgstr "Die Anmeldung ist nicht mehr gültig"

msgid "Kein Formular für die Kombination [_1] verfügbar"
msgstr "Kein Formular für die Kombination [_1] verfügbar"

# "Project-Id-Version: PACKAGE VERSION\n"
# "POT-Creation-Date: YEAR-MO-DA HO:MI+ZONE\n"
# "PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n"
# "Last-Translator: FULL NAME <EMAIL@ADDRESS>\n"
# "Language-Team: LANGUAGE <LL@li.org>\n"
# "MIME-Version: 1.0\n"
# "Content-Type: text/plain; charset=utf8\n"
# "Content-Transfer-Encoding: 8bit\n"

# --- for l10n-testing

msgid "Hello World!"
msgstr "Hallo Fans!"

#: lib/Apiis/DataBase/Record/Check/IsAFloat.pm:86 lib/Apiis/DataBase/Record/Check/IsANumber.pm:83 lib/Apiis/DataBase/Record/Check/NoCheck.pm:70 lib/Apiis/DataBase/Record/Check/NoNumber.pm:84 lib/Apiis/DataBase/Record/Check/NotNull.pm:87 lib/Apiis/DataBase/Record/Check/ReservedStrings.pm:97
#. ('IsAFloat',               join ( ',', @args)
#. ('IsANumber',               join ( ',', @args)
#. ('NoCheck', join ( ',', @args)
#. ('NoNumber', join ( ',', @args)
#. ('NotNull', join ( ',', @args)
#. ('ReservedStrings', join ( ',', @rest)
msgid "%1 does not accept parameters (%2)"
msgstr "%1 akzeptiert keine Parameter (%2)"

#: lib/Apiis/DataBase/Record/Check/DateDiff.pm:35 lib/Apiis/DataBase/Record/Check/ForeignKey.pm:36 lib/Apiis/DataBase/Record/Check/LastAction.pm:35 lib/Apiis/DataBase/Record/Check/List.pm:36 lib/Apiis/DataBase/Record/Check/PrimaryKey.pm:35 lib/Apiis/DataBase/Record/Check/Unique.pm:35
#. ('DateDiff')
#. ('ForeignKey')
#. ('LastAction')
#. ('List')
#. ('PrimaryKey')
#. ('Unique')
msgid "%1 not implemented"
msgstr "%1 ist noch nicht geschrieben"

#: bin/check_integrity:199
#. ($table, $k)
msgid "%1: %2 records successfully checked against the rules"
msgstr "%1: %2 Datensätze erfolgreich überprüft"

#: bin/check_integrity:200
#. ($table, $j)
msgid "%1: %2 records violate rules"
msgstr "%1: %2 Datensätze verletzen Regeln"

#: bin/check_integrity:46
msgid "-s <num> must provide a number!\n"
msgstr "-s <Zahl> benötigt eine Zahl!\n"

#: lib/Apiis/DataBase/Record/Check/NotNull.pm:53
#. ($empty)
msgid "The passed value was: %1"
msgstr "Der übergebene Wert war: %1"

#: bin/mkl10n:64
#. ($apiis->APIIS_HOME, $!)
msgid "Cannot change to dir %1: %2"
msgstr "Wechsel in Verzeichnis %1 nicht möglich: %2"

#: lib/Apiis/DataBase/Init.pm:185
msgid "Cannot connect to database."
msgstr "Keine Verbindung zur Datenbank möglich."

#: lib/Apiis/DataBase/Record/Delete.pm:62
msgid "Cannot delete record without rowid"
msgstr "Datensatz ohne Rowid kann nicht gelöscht werden"

#: lib/Apiis/DataBase/Init.pm:267
msgid "Cannot disconnect from database"
msgstr "Verbindung zur Datenbank nicht möglich"

#: lib/Apiis/DataBase/Init.pm:89
msgid "Cannot find database configuration file."
msgstr "Die Konfigurationsdatei für die Datenbank kann nicht gefunden werden."

#: lib/Apiis/DataBase/Record/Modify/ConvertBool.pm:49
#. ($data[$i])
msgid "Cannot translate value '%1' to boolean datatype"
msgstr "Kann Wert '%1' nicht in boolschen Datentyp wandeln"

#: lib/Apiis/DataBase/Record/Update.pm:109
msgid "Cannot update record without rowid"
msgstr "Kann Datensatz ohne rowid nicht aktualisieren"

#: lib/Apiis/DataBase/Init.pm:287
msgid "Could not commit the current transaction"
msgstr "Kann aktuelle Transaktion nicht speichern"

#: lib/Apiis/DataBase/Init.pm:308
msgid "Could not rollback the current transaction"
msgstr "Kann aktuelle Transaktion nicht zurückrollen"

#: bin/mksql:52
msgid "DROP-statements are not commented out!"
msgstr "Löschanweisungen (DROP) werden nicht auskommentiert!"

#: lib/Apiis/DataBase/Record/Check/Range.pm:74
#. ($data, "$min <=> $max")
msgid "Data '%1' exceeds Range limits '%2'"
msgstr "Daten '%1' verlassen Bereichsgrenzen '%2'"

#: lib/Apiis/DataBase/Record/Check/Range.pm:55 lib/Apiis/DataBase/Record/Check/Range.pm:72
msgid "Data error in CHECK rule"
msgstr "Datenfehler in CHECK-Regel"

#: lib/Apiis/DataBase/Init.pm:186
#. ($err_msg)
msgid "Database error: %1"
msgstr "Datenbankfehler: %1"

#: lib/Apiis/CheckFile.pm:145
#. ($thisfile,            join ( ', ', @_locations)
msgid "Did not find '%1' in %2 with extensions %3"
msgstr "Kann '%1' nicht in %2 mit Endungen %3 finden"

#:
msgid "ENTRY_ACTION"
msgstr "EINGANGS_GRUND"

#: lib/Apiis/Errors.pm:435
msgid "Error"
msgstr "Fehler"

#: lib/Apiis/DataBase/SQL/DirectSQL.pm:94
#. ($thisuser, $err_text)
msgid "Error in SQL statement (%1): %2"
msgstr "Fehler im SQL (%1): %2"

#: bin/mksql:48
msgid "Help"
msgstr "Hilfe"

#: lib/Apiis/DataBase/Record/Check/DateDiff.pm:64 lib/Apiis/DataBase/Record/Check/ForeignKey.pm:66 lib/Apiis/DataBase/Record/Check/IsAFloat.pm:83 lib/Apiis/DataBase/Record/Check/IsANumber.pm:80 lib/Apiis/DataBase/Record/Check/IsEqual.pm:141 lib/Apiis/DataBase/Record/Check/LastAction.pm:64 lib/Apiis/DataBase/Record/Check/List.pm:66 lib/Apiis/DataBase/Record/Check/NoCheck.pm:68 lib/Apiis/DataBase/Record/Check/NoNumber.pm:82 lib/Apiis/DataBase/Record/Check/NotNull.pm:85 lib/Apiis/DataBase/Record/Check/PrimaryKey.pm:64 lib/Apiis/DataBase/Record/Check/Range.pm:109 lib/Apiis/DataBase/Record/Check/Range.pm:124 lib/Apiis/DataBase/Record/Check/ReservedStrings.pm:95 lib/Apiis/DataBase/Record/Check/Unique.pm:64 lib/Apiis/DataBase/Record/Trigger/SetGuid.pm:58 lib/Apiis/DataBase/Record/Trigger/SetGuid.pm:72 lib/Apiis/DataBase/Record/Trigger/SetNode.pm:51 lib/Apiis/DataBase/Record/Trigger/SetNode.pm:65 lib/Apiis/DataBase/Record/Trigger/SetVersion.pm:65 lib/Apiis/DataBase/Record/Trigger/SetVersion.pm:79
#. ('CHECK')
#. ('TRIGGER')
msgid "Incorrect %1 entry in model file"
msgstr "Falscher %1 Eintrag in der Modeldatei"

#: lib/Apiis/Init.pm:200 lib/Apiis/Init.pm:205
msgid "Just another Perl hacker"
msgstr "Und wieder ein Perl Hacker"

#: bin/mkl10n:50
msgid "Language name required."
msgstr "Angabe der Sprache notwendig."

#: lib/Apiis/Auth/Role.pm:37 lib/Apiis/Form/Init.pm:31 lib/Apiis/Record.pm:101 lib/Apiis/Record.pm:183
#. (__PACKAGE__)
msgid "Missing initialisation in main file (%1)."
msgstr "Fehlende Initialisierung in der Hauptdatei (%1)."

#: lib/Apiis/DataBase/Record/Check/IsAFloat.pm:52
msgid "Must be a float"
msgstr "Muß vom Typ 'float' sein"

#: lib/Apiis/DataBase/Record/Check/IsANumber.pm:49
msgid "Must be a number"
msgstr "Muß eine Zahl sein"

#: lib/Apiis/DataBase/Record/Check/NoNumber.pm:51
msgid "Must not be a number"
msgstr "Darf keine Zahl sein"

#: lib/Apiis/Auth/Auth.pm:142 lib/Apiis/Auth/Auth.pm:264
msgid "NO ACCESS RIGHTS"
msgstr "Keine Zugriffsrechte"

#: bin/mksql:51
msgid "Name of model file"
msgstr "Name der Modeldatei"

#: bin/check_integrity:134
msgid "Name of table to check"
msgstr "Name der zu überprüfenden Tabelle"

#: lib/Apiis/Auth/Auth.pm:144
#. ($sqlaction, $table_name)
msgid "No access rights for the action '%1' on the table '%2'"
msgstr "Keine Zugriffsrechte für Aktion '%1' auf Tabelle '%2'"

#: lib/Apiis/Form/Init.pm:209
#. ('form', 'Apiis::Form::Init')
msgid "No key %1 passed to %2"
msgstr "%2 wurde kein Schlüssel %1 übergeben"

#: lib/Apiis/Record.pm:114
msgid "No key 'name' passed to Apiis::Record"
msgstr "Kein Schlüssel 'name' an Apiis::Record übergeben"

#: lib/Apiis/Form/Init.pm:155
#. ('Apiis::Form::Init::sectionkeys')
msgid "No parameter passed to %1."
msgstr "Kein Parameter an %1 übergeben."

#: lib/Apiis/Auth/Auth.pm:98
msgid "No parameters for the WHERE clause to get access rights"
msgstr "Kein WHERE-clause-Parameter für Zugriffsrechte"

#: lib/Apiis/DataBase/SQL/DirectSQL.pm:112
#. (uc $action)
msgid "No records affected by %1 statement"
msgstr "Durch die %1 Anweisung wurden keine Datensätze betroffen"

#: bin/check_integrity:65
msgid "No valid table given!"
msgstr "Keine gültige Tabelle"

#: lib/Apiis/DataBase/Record.pm:231
#. ($args{tablename})
msgid "Non existing tablename '%1' passed to Apiis::DataBase::Record"
msgstr "Nicht-existierende Tabelle '%1' an Apiis::DataBase::Record übergeben"

#: lib/Apiis/DataBase/Record/Fetch.pm:189
msgid "One record expected and many retrieved"
msgstr "Ein Datensatz erwartet und mehrere erhalten"

#: lib/Apiis/DataBase/Record/Check/Range.pm:56
#. ($data)
msgid "Parameter '%1' is not a number"
msgstr "Parameter '%1' is keine Zahl"

#: lib/Apiis/DataBase/Record/Check/Range.pm:125
#. ($min, $max)
msgid "Parameter '%1,%2' is not a number"
msgstr "Parameter '%1,%2' is keine Zahl"

#: lib/Apiis/DataBase/Record/Check/Range.pm:110
msgid "Parameter min or max is not defined"
msgstr "Parameter min/max nicht definiert"

#: lib/Apiis/DataBase/Record/Coding.pm:118 lib/Apiis/DataBase/Record/Coding.pm:435
#. ('column name')
msgid "Parameter missing: %1"
msgstr "fehlender Parameter: %1"

#: lib/Apiis/CheckFile.pm:139
#. ($thisfile)
msgid "Problems opening file %1"
msgstr "Kann Datei %1 nicht öffnen"

#: bin/check_integrity:86 lib/Apiis/DataBase/SQL/MakeSQL.pm:306
#. ($err_file, $!)
#. ($filename, $!)
msgid "Problems opening file %1: %2"
msgstr "Kann Datei %1 nicht öffnen: %2"

#: lib/Apiis/DataBase/Init.pm:216
msgid "Problems to set ISO-dateformat"
msgstr "Kann das ISO-Datumsformat nicht setzen"

#: lib/Apiis/DataBase/Record/Check.pm:78
#. ($thisrule)
msgid "Rule '%1' returned fatal error"
msgstr "Regel '%1' gibt fatalen Fehler zurück"

#: lib/Apiis/DataBase/Record/Check/IsEqual.pm:106 lib/Apiis/DataBase/Record/Check/IsEqual.pm:73 lib/Apiis/DataBase/Record/Check/IsEqual.pm:89
msgid "Rule violated"
msgstr "Regel verletzt"

#: lib/Apiis/DataBase/SQL/DirectSQL.pm:114 lib/Apiis/DataBase/SQL/DirectSQL.pm:127 lib/Apiis/DataBase/SQL/DirectSQL.pm:143
#. ($thisuser, $statement, $rv)
msgid "SQL Statement(%1): %2 (Return value: %3)"
msgstr "SQL Kommando(%1): %2 (Rückgabewert: %3)"

#: lib/Apiis/DataBase/SQL/DirectSQL.pm:95
#. ($statement)
msgid "SQL Statement: %1"
msgstr "SQL Kommando: %1"

#: bin/mkl10n:120
msgid "Scanning files ..."
msgstr "Durchsuche Datei ..."

#: lib/Apiis/DataBase/Record/Check.pm:51 lib/Apiis/DataBase/Record/Delete.pm:21 lib/Apiis/DataBase/Record/Fetch.pm:88 lib/Apiis/DataBase/Record/Insert.pm:22 lib/Apiis/DataBase/Record/Modify.pm:37 lib/Apiis/DataBase/Record/Update.pm:20 lib/Apiis/DataBase/SQL/DirectSQL.pm:22
#. ('_check_record', 'Apiis::DataBase::Record::*', $package)
#. ('_delete', 'Apiis::DataBase::Record', $package)
#. ('_fetch', 'Apiis::DataBase::Record', $package)
#. ('_insert', 'Apiis::DataBase::Record', $package)
#. ('_modify', 'Apiis::DataBase::Record::*', $package)
#. ('_update', 'Apiis::DataBase::Record', $package)
#. ('_sql', 'Apiis::DataBase::SQL::DirectSQL', $package)
msgid ""
"This method %1 may only be invoked from package %2.\n"
"You called it from package %3"
msgstr ""
"Diese Methode %1 darf nur aus Paket %2 aufgerufen werden.\n"
"Der Aufruf erfolgte jedoch aus Paket %3"

#: lib/Apiis/DataBase/Record/Trigger/SetGuid.pm:59 lib/Apiis/DataBase/Record/Trigger/SetNode.pm:52 lib/Apiis/DataBase/Record/Trigger/SetVersion.pm:66
#. ('SetGuid')
#. ('SetNode')
#. ('SetVersion')
msgid "Trigger %1 needs a column name as parameter"
msgstr "Trigger %1 braucht einen Spaltennamen als Parameter"

#: lib/Apiis/DataBase/Record/Trigger/SetGuid.pm:74 lib/Apiis/DataBase/Record/Trigger/SetNode.pm:67 lib/Apiis/DataBase/Record/Trigger/SetVersion.pm:81
#. ('SetGuid', join(',', @args)
#. ('SetNode', join(',', @args)
#. ('SetVersion', join(',', @args)
msgid "Trigger %1 only needs a column name as parameter, not '%2'"
msgstr "Trigger %1 braucht nur einen Spaltennamen als Parameter, nicht '%2'"

#: lib/Apiis/DataBase/Record/Trigger.pm:63
#. ($this_trigger)
msgid "Trigger '%1' returned fatal error"
msgstr "Trigger '%1' gibt fatalen Fehler zurück"

#: lib/Apiis/Record.pm:71 lib/Apiis/Record.pm:90
#. ($text, 'addcolumn')
#. ('name', 'delcolumn')
msgid "Undefined %1 in method %2"
msgstr "%1 ist in Methode %2 nicht definiert"

#: lib/Apiis/Record.pm:199
#. ($attrname)
msgid "Undefined parameter %1 in new column object."
msgstr "Undefinierter Parameter %1 in neuem Spaltenobject."

#: lib/Apiis/Init.pm:477
msgid "Unknown error type passed"
msgstr "Unbekannter Fehlertyp übergeben"

#: lib/Apiis/DataBase/SQL/DirectSQL.pm:125
#. (uc $action)
msgid "Unknown number of records affected by %1 statement"
msgstr "Unbekannte Anzahl von Datensätzen durch Kommando '%1' betroffen"

#: lib/Apiis/DataBase/Record/Fetch.pm:116
#. ($thisarg)
msgid "Unknown parameter '%1'"
msgstr "Unbekannter Parameter '%1'"

#: lib/Apiis/DataBase/SQL/DirectSQL.pm:141
#. ($action)
msgid "Unknown return value from DBI in action %1 "
msgstr "Unbekannter Rückgabewert von DBI in Aktion '%1'"

#: lib/Apiis/DataBase/Record/Check/NotNull.pm:52
msgid "Value must not be NULL"
msgstr "Der Wert darf nicht NULL sein"

#: bin/mksql:49 lib/Apiis/Init.pm:160
msgid "Version"
msgstr "Version"

#: lib/Apiis/Errors.pm:241
#. ($thiskey)
msgid "Wrong attribute '%1'"
msgstr "Falsches Merkmal '%1'"

#: lib/Apiis/Errors.pm:212 lib/Apiis/Errors.pm:217 lib/Apiis/Errors.pm:308 lib/Apiis/Errors.pm:317 lib/Apiis/Errors.pm:333
#. ($val, $thiskey)
#. ($args{$thiskey}, $thiskey)
#. ($val, $elem)
#. ($newval, $elem)
msgid "Wrong value '%1' for method '%2' (allowed: "
msgstr "Falscher Wert '%1' für Methode '%2' (erlaubt: "

#: lib/Apiis/Errors.pm:227
#. ($newval, $thiskey, join(' ', $self->$predef_values)
msgid ""
"Wrong value '%1' for method '%2' (allowed: %3),\n"
"called in %4, line %5\n"
msgstr ""
"Falscher Wert '%1' für Methode '%2' (erlaubt: %3),\n"
"aufgerufen in %4, Zeile %5\n"

#: lib/Apiis/Errors.pm:268 lib/Apiis/Errors.pm:275 lib/Apiis/Errors.pm:282
#. ('type_values')
#. ('severity_values')
#. ('action_values')
msgid "You cannot assign values to %1, readonly."
msgstr "%1 ist schreibgeschützt."

#: lib/Apiis/Record.pm:123 lib/Apiis/Record.pm:210
#. ('Apiis::Record')
#. ('Apiis::Column')
msgid "You reached _init in the base class %1. This should not happen."
msgstr "_init in der Basisklasse %1 wurde aufgerufen. Das sollte nicht passieren."

#:
msgid "buy"
msgstr "Kauf"

#:
msgid "buy (inside)"
msgstr "Kauf (intern)"

#:
msgid "buy / change the place inside the society"
msgstr "Kauf / Umstellung innerhalb des Verbandes"

#: bin/check_integrity:295
msgid "check_integrity_USAGE_MESSAGE"
msgstr ""
"Aufruf:\n"
"check_integrity -f <Modeldatei> [-hvtseago]\n"
"                -h                      --> Hilfe\n"
"                -v                      --> Version\n"
"                -f <modelfile>          --> Name der Modeldatei\n"
"                -t <table>              --> Name der zu überprüfenden Tabelle\n"
"                -s <number>             --> Stopp nach <Anzahl> Datensätzen\n"
"                -e                      --> in Fehlerdatei geschrieben\n"
"                -D                      --> Die Tabellen haben eine 'dirty' Spalte\n"
"                -g <output file>        --> Name der Ausgabedatei (Standard = check_integrity.erg)\n"

#: lib/Apiis/Record.pm:64
msgid "column name"
msgstr "Spaltenname"

#: lib/Apiis/Record.pm:65
msgid "column object"
msgstr "Spaltenobjekt"

#: bin/mksql:53
msgid "create no views"
msgstr "Keine Sichten (views) anlegen"

#: bin/mksql:52
msgid "delete"
msgstr "löschen"

#: lib/Apiis/DataBase/Record/Check/NotNull.pm:41
msgid "empty"
msgstr "leer"

#: lib/Apiis/Init.pm:680
#. ($filename, $line)
msgid "error initiated in %1 at line %2"
msgstr "Fehler verursacht in %1, Zeile %2"

#: bin/mkl10n:45 bin/mkl10n:51
msgid "mkl10n_USAGE_MESSAGE"
msgstr ""
"Aufruf: mkl10n -h        => diese Hilfe\n"
"               -q        => (engl. quiet) unterdrückt informative Meldungen\n"
"        mkl10n <Sprache> => durchsucht $APIIS_HOME/{bin|lib} nach lokalisierten Texten\n"
"                            und schreibt eine Datei\n"
"                            $APIIS_HOME/lib/Apiis/I18N/L10N/<Sprache>.mo\n"

#: bin/mksql:47 bin/mksql:51
msgid "modelfile"
msgstr "Modeldatei"

#: lib/ref_breedprg_alib.pm:127
#. ($sql)
msgid "no key defined: %1\n"
msgstr "kein Schlüssel definiert: %1\n"

#: lib/ref_breedprg_alib.pm:141
#. (@where_cl)
msgid "no proper id for given where clause: %1\n"
msgstr "keine richtige ID für diese WHERE-Regel: %1\n"

#: lib/Apiis/DataBase/Record/Check/IsEqual.pm:107
msgid "no record found to compare with"
msgstr "kein Vergleichsdatensatz gefunden"

#: lib/ref_breedprg_alib.pm:124
#. ($sql)
msgid "no unique key: %1\n"
msgstr "kein eindeutiger Schlüssel: %1\n"

#: bin/mksql:50
msgid "only for table <table>"
msgstr "nur für Tabelle <Tabelle>"

#: lib/Apiis/DataBase/Record/Check/IsEqual.pm:74 lib/Apiis/DataBase/Record/Check/IsEqual.pm:91
#. ($comp_val, 'NULL')
#. ($comp_val,                     $records[0]->column($comp_col)
msgid "passed value: %1, compared value: %2"
msgstr "übergebener Wert: %1, Vergleichswert: %2"

#:
msgid "purchase"
msgstr "Kauf"

#: lib/Apiis/DataBase/Record/Check/ReservedStrings.pm:62
#. ($thiskey)
msgid "reserved string %1 used in data"
msgstr "Reservierte Zeichenkette '%1' in Daten benutzt"

#: lib/Apiis/DataBase/Record/Modify.pm:69
#. ($thisrule)
msgid "rule '%1' returned fatal error"
msgstr "Regel '%1' gab fatalen Fehler zurück"

#: bin/mksql:50
msgid "table"
msgstr "Tabelle"

#: lib/Apiis/DataBase/Record/Check/NotNull.pm:39
msgid "undefined"
msgstr "undefiniert"

#: lib/Apiis/DataBase/Record/Check.pm:96 lib/Apiis/DataBase/Record/Modify.pm:95
#. ($thisrule)
msgid "undefined rule '%1'"
msgstr "undefinierte Regel '%1'"

#: lib/Apiis/Auth/Auth.pm:55
#. (.$sqlaction)
msgid "unknown definition sql action type: "
msgstr "unbekannte SQL-Aktion: "

#: bin/apiish
msgid "apiish_USAGE_MESSAGE"
msgstr ""
"Aufruf:\n"
"apiish     -m Modell Datei\n"
"           -h Hilfe\n"

#: bin/mksql:47
msgid "usage"
msgstr "Aufruf"

#: bin/mksql:54
msgid "write to STDOUT"
msgstr "schreibe auf Standardausgabekanal (STDOUT)"

#: bin/check_integrity:203
#. ($err_file)
msgid "written into %1"
msgstr "nach %1 geschrieben"

#: bin/xml2model.pl:28
msgid "xml2model.pl_USAGE_MESSAGE"
msgstr ""
"xml2model.pl schreibt eine XML-Datei in eine Modelldatei\n"
"Aufruf: xml2model.pl <Projekt Name>\n"
"        xml2model.pl -h | -v\n"
"          -h      Hilfe\n"
"          -v      Version\n"
"Beispiel: xml2model.pl minipigs\n"
"\n"

# xml forms:
msgid "Animal Exit"
msgstr "Abgangsmeldung"

# Buttons:
msgid "Quit"
msgstr "Abbruch"

msgid "Query"
msgstr "Abfrage"

msgid "First"
msgstr "Erster"

msgid "Previous"
msgstr "Voriger"

msgid "Next"
msgstr "Nächster"

msgid "Last"
msgstr "Letzter"

msgid "Insert"
msgstr "Einfügen"

msgid "Update"
msgstr "Aktualisieren"

msgid "Clear Form"
msgstr "Maske leeren"

msgid "Projects"
msgstr "Projekte"

msgid "Forms"
msgstr "Masken"

msgid "Reports"
msgstr "Reports"

msgid "Login"
msgstr "Anmelden"

msgid "The Apiis Shell"
msgstr "Die Apiis Oberfläche"

msgid "The Apiis Shell"
msgstr "Die Apiis Oberfläche"

msgid "Login name"
msgstr "Anmeldename"

msgid "Password"
msgstr "Paßwort"

msgid "my"
msgstr "mein"

