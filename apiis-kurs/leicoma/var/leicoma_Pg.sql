-- DROP TABLE transfer;
CREATE TABLE transfer (
   db_animal         int4,       -- Interne ID der Tiernummer
   ext_animal        text,       -- Externe ID eines Tieres
   db_unit           int4,       -- Interne ID der Unit
   db_farm           int4,       -- Interne ID des Besitzers
   opening_dt        date,       -- Datum, ab dem Daten auf die Nummer gespeichert werden kann
   entry_dt          date,       -- Datum, ab dem Tier in einer Herde ist
   exit_dt           date,       -- Datum, wenn Tier die Herde verlaesst
   closing_dt        date,       -- Datum, ab dem keine Daten auf die Nummer eingegeben werde koennen
   db_entry_action   int4,       -- Grund fuer den Eintritt in die Herde
   db_exit_action    int4,       -- Grund fuer das Verlassen der Herde
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool,       -- is record targeted for synchronization
   id_set            int2        -- Set of categories for the numbering scheme
);
-- DROP INDEX  uidx_pk_transfer;
CREATE UNIQUE INDEX uidx_pk_transfer ON transfer ( db_unit, ext_animal )
WHERE closing_dt is NULL;

-- DROP INDEX idx_transfer_1;
CREATE  INDEX idx_transfer_1 ON transfer ( db_animal );
-- DROP INDEX idx_transfer_2;
CREATE  INDEX idx_transfer_2 ON transfer ( ext_animal, db_unit );
-- DROP INDEX idx_transfer_3;
CREATE  INDEX idx_transfer_3 ON transfer ( db_farm );
-- DROP INDEX idx_transfer_4;
CREATE  INDEX idx_transfer_4 ON transfer ( db_farm, closing_dt, exit_dt );
-- DROP INDEX idx_transfer_5;
CREATE  INDEX idx_transfer_5 ON transfer ( db_unit );

-- DROP INDEX uidx_transfer_rowid;
CREATE UNIQUE INDEX uidx_transfer_rowid ON transfer ( guid );

-- DROP SEQUENCE seq_transfer__db_animal;
CREATE SEQUENCE seq_transfer__db_animal;

-- DROP TABLE locations;
CREATE TABLE locations (
   db_animal         int4,       -- db_Tier
   db_location       int4,       -- db_unit
   entry_dt          date,       -- Eingegangen am
   exit_dt           date,       -- Abgangen am
   db_entry_action   int4,       -- Aktion_entering_herd
   db_exit_action    int4,       -- Aktion_leaving_herd
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- Zuechter
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_locations_1;
CREATE UNIQUE INDEX uidx_locations_1 ON locations ( db_animal, db_location, entry_dt );
-- DROP INDEX idx_locations_2;
CREATE  INDEX idx_locations_2 ON locations ( db_location );

-- DROP INDEX uidx_locations_rowid;
CREATE UNIQUE INDEX uidx_locations_rowid ON locations ( guid );

-- DROP TABLE codes;
CREATE TABLE codes (
   ext_code          text,       -- Externer Schluessel
   class             text,       -- Schluessel-Klasse
   db_code           int4,       -- Interne ID eines Schluessels
   short_name        text,       -- Kurzform des Namens
   long_name         text,       -- Langform des Schluessels
   description       text,       -- Beschreibung
   opening_dt        date,       -- Datum, ab dem der Code gueltig ist
   closing_dt        date,       -- Datum, ab dem der Code ungueltig ist
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX  uidx_pk_codes;
CREATE UNIQUE INDEX uidx_pk_codes ON codes ( class, ext_code )
WHERE closing_dt is NULL;

-- DROP INDEX uidx_codes_1;
CREATE UNIQUE INDEX uidx_codes_1 ON codes ( db_code );
-- DROP INDEX uidx_codes_2;
CREATE UNIQUE INDEX uidx_codes_2 ON codes ( class, ext_code, closing_dt );

-- DROP INDEX uidx_codes_rowid;
CREATE UNIQUE INDEX uidx_codes_rowid ON codes ( guid );

-- DROP SEQUENCE seq_codes__db_code;
CREATE SEQUENCE seq_codes__db_code;

-- DROP TABLE animal;
CREATE TABLE animal (
   db_animal         int4,       -- Interne ID des Tieres
   db_sex            int4,       -- Interne ID des Geschlechts
   db_color          int4,       -- Farbschlag
   birth_dt          date,       -- Geburtsdatum
   db_sire           int4,       -- Interne ID des Vaters
   db_dam            int4,       -- Interne ID der Mutter
   parity            int4,       -- Laktationsnummer
   db_breeder        int4,       -- Interne ID des Zuechters
   db_owner          int4,       -- Interne ID des Besitzers
   db_society        int4,       -- Verband
   leaving_dt        date,       -- Abgangsdatum
   db_leaving        int4,       -- Abgangsgrund
   db_selection      int4,       -- Interne ID des Selektionsstatus
   name              text,       -- Name
   la_rep            text,       -- Status des letzten Aktion
   la_rep_dt         date,       -- Datum der letzten Aktion
   db_gebtyp         int4,       -- Interne ID des Geburtstyps
   db_auftyp         int4,       -- Interne ID des Aufzuchttyps
   mz                int4,       -- Mehrlingszeichen
   teats_l_no        int4,       -- Mehrlingszeichen
   teats_r_no        int4,       -- Mehrlingszeichen
   db_breed          int4,       -- Interne ID der Rasse
   db_zb_abt         int4,       -- Interne ID der Zuchtbuchabteilung
   zuchttier         bool,       -- Zuchttier?
   comments          text,       -- Kommentare
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_animal_1;
CREATE UNIQUE INDEX uidx_animal_1 ON animal ( db_animal );
-- DROP INDEX idx_animal_2;
CREATE  INDEX idx_animal_2 ON animal ( db_animal, birth_dt );

-- DROP INDEX uidx_animal_rowid;
CREATE UNIQUE INDEX uidx_animal_rowid ON animal ( guid );

-- DROP TABLE checkallel;
CREATE TABLE checkallel (
   checkallel_id     int4,       -- Interne ID fuer den Datensatz
   class             text,       -- Kategorie
   db_id_animal      int4,       -- 
   db_id_sire        int4,       -- 
   db_id_dam         int4,       -- 
   db_species        int4,       -- 
   db_rk             int4,       -- 
   db_group          int4,       -- 
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_checkallel_1;
CREATE UNIQUE INDEX uidx_checkallel_1 ON checkallel ( checkallel_id );
-- DROP INDEX uidx_checkallel_2;
CREATE UNIQUE INDEX uidx_checkallel_2 ON checkallel ( class, db_id_animal );

-- DROP INDEX uidx_checkallel_rowid;
CREATE UNIQUE INDEX uidx_checkallel_rowid ON checkallel ( guid );

-- DROP SEQUENCE seq_checkallel__checkallel_id;
CREATE SEQUENCE seq_checkallel__checkallel_id;

-- DROP TABLE textblock;
CREATE TABLE textblock (
   textblock_ident    text,       -- Kategorie
   textblock_class    text,       -- Textbaustein
   textblock_content  text,       -- Inhalt Textbaustein
   last_change_dt     timestamp,  -- Timestamp of last change
   last_change_user   text,       -- Who did the last change
   dirty              bool,       -- report errors from check_integrity
   chk_lvl            int2,       -- check level
   guid               int4,       -- global identifier
   owner              text,       -- record class
   version            int4,       -- version
   synch              bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_textblock_1;
CREATE UNIQUE INDEX uidx_textblock_1 ON textblock ( textblock_ident );

-- DROP INDEX uidx_textblock_rowid;
CREATE UNIQUE INDEX uidx_textblock_rowid ON textblock ( guid );

-- DROP SEQUENCE seq_textblock__textblock_ident;
CREATE SEQUENCE seq_textblock__textblock_ident;

-- DROP TABLE event;
CREATE TABLE event (
   event_id          int4,       -- Interne ID der Aktion
   db_event_type     int4,       -- Interne ID der Art der Pruefung
   db_sampler        int4,       -- Interne ID des Pruefers
   event_dt          date,       -- Test-Datum
   db_location       int4,       -- Interne ID des Prueforts
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX idx_event_1;
CREATE  INDEX idx_event_1 ON event ( event_id );
-- DROP INDEX idx_event_2;
CREATE  INDEX idx_event_2 ON event ( db_event_type );
-- DROP INDEX uidx_event_3;
CREATE UNIQUE INDEX uidx_event_3 ON event ( event_id, db_event_type, db_location, event_dt );

-- DROP INDEX uidx_event_rowid;
CREATE UNIQUE INDEX uidx_event_rowid ON event ( guid );

-- DROP SEQUENCE seq_event__event_id;
CREATE SEQUENCE seq_event__event_id;

-- DROP TABLE costs;
CREATE TABLE costs (
   db_unit           int4,       -- Interne ID der Unit
   db_cost_kl        int4,       -- Interne ID der Kostenklasse
   preis             float4,     -- Preis
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX idx_costs_1;
CREATE  INDEX idx_costs_1 ON costs ( db_unit );
-- DROP INDEX uidx_costs_2;
CREATE UNIQUE INDEX uidx_costs_2 ON costs ( db_unit, db_cost_kl );

-- DROP INDEX uidx_costs_rowid;
CREATE UNIQUE INDEX uidx_costs_rowid ON costs ( guid );

-- DROP TABLE genes;
CREATE TABLE genes (
   event_id          int4,       -- Interne ID der Aktion
   db_animal         int4,       -- Interne ID des Tieres
   db_genes_class    int4,       -- Art des Genes
   db_genes          int4,       -- Interne ID Scrapie
   db_allel_1        int4,       -- Interne ID Allel 1
   db_allel_2        int4,       -- Interne ID Allel 2
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_genes_1;
CREATE UNIQUE INDEX uidx_genes_1 ON genes ( db_animal, event_id );

-- DROP INDEX uidx_genes_rowid;
CREATE UNIQUE INDEX uidx_genes_rowid ON genes ( guid );

-- DROP TABLE external_traits;
CREATE TABLE external_traits (
   db_animal         int4,       -- Datenbank interne Tier ID der Sau
   db_trait          text,       -- Traitname
   value             float4,     -- Value
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX idx_external_traits_1;
CREATE  INDEX idx_external_traits_1 ON external_traits ( db_animal, db_trait );

-- DROP INDEX uidx_external_traits_rowid;
CREATE UNIQUE INDEX uidx_external_traits_rowid ON external_traits ( guid );

-- DROP TABLE notice;
CREATE TABLE notice (
   db_animal         int4,       -- Datenbank interne Tier ID der Sau
   notice_dt         date,       -- Bemerkungsdatum
   notice            text,       -- Bemerkung
   db_notice_type    int4,       -- Bemerkungsart
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX idx_notice_1;
CREATE  INDEX idx_notice_1 ON notice ( db_animal );

-- DROP INDEX uidx_notice_rowid;
CREATE UNIQUE INDEX uidx_notice_rowid ON notice ( guid );

-- DROP TABLE litter;
CREATE TABLE litter (
   db_animal         int4,       -- Interne ID des Tieres
   db_sire           int4,       -- Interne ID des Ebers
   parity            int2,       -- Laktationsnummer
   delivery_dt       date,       -- Datum der Abferkelung
   db_breed_sire     int4,       -- Rasse des Anpaarungsebers
   db_help_birth     int4,       -- Interne ID fuer Geburtshilfe
   ewa               int2,       -- Erstwurfalter
   zwz               int2,       -- Zwischenwurfzeit
   born_alive_no     int2,       -- Gesamt Geborene
   male_born_no      int2,       -- Maennliche Ferkel
   mumien_no         int2,       -- mumifizierter Ferkel
   still_born_no     int2,       -- totgeborener Ferkel
   weaned_dt         date,       -- Absetzdatum
   db_weaned_typ     int2,       -- Absetztyp
   weaned_no         int2,       -- abgesetzte Ferkel
   foster_no         int2,       -- aufgezogene Tiere
   notch_start       int2,       -- 1. Spitzennummer
   birthweigh_dt     date,       -- Wiegedatum Geburtsgewicht
   gv                float4,     -- Geschlechtsverhaeltnis
   avg_birthweight   float4,     -- Mittleres Geburtsgewicht der Ferkel
   sda_birthweight   float4,     -- Streuung des Geburtsgewichts der Ferkel
   error_flag        int4,       -- Error Flag
   comment           text,       -- Kommentar
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX idx_litter_1;
CREATE  INDEX idx_litter_1 ON litter ( db_animal, delivery_dt );
-- DROP INDEX uidx_litter_2;
CREATE UNIQUE INDEX uidx_litter_2 ON litter ( db_animal, parity );

-- DROP INDEX uidx_litter_rowid;
CREATE UNIQUE INDEX uidx_litter_rowid ON litter ( guid );

-- DROP TABLE weight;
CREATE TABLE weight (
   event_id          int4,       -- Interne ID Aktion
   db_animal         int4,       -- Interne ID des Tieres
   test_wt           float4,     -- Lebendmasse
   ltz               int2,       -- LTZ
   alter             int2,       -- Alter
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX idx_weight_1;
CREATE  INDEX idx_weight_1 ON weight ( db_animal );
-- DROP INDEX idx_weight_2;
CREATE  INDEX idx_weight_2 ON weight ( event_id );
-- DROP INDEX uidx_weight_3;
CREATE UNIQUE INDEX uidx_weight_3 ON weight ( db_animal, event_id );

-- DROP INDEX uidx_weight_rowid;
CREATE UNIQUE INDEX uidx_weight_rowid ON weight ( guid );

-- DROP TABLE udder;
CREATE TABLE udder (
   event_id          int4,       -- Interne ID Aktion
   db_animal         int4,       -- Interne ID des Tieres
   mbk_n             int2,       -- Melkbarkeitsnote
   eut_n             int2,       -- Note Euter
   zit_n             int2,       -- Note Zitzen
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX idx_udder_1;
CREATE  INDEX idx_udder_1 ON udder ( db_animal );
-- DROP INDEX uidx_udder_2;
CREATE UNIQUE INDEX uidx_udder_2 ON udder ( db_animal, event_id );

-- DROP INDEX uidx_udder_rowid;
CREATE UNIQUE INDEX uidx_udder_rowid ON udder ( guid );

-- DROP TABLE exterior;
CREATE TABLE exterior (
   event_id          int4,       -- Interne ID Aktion
   db_animal         int4,       -- Interne ID des Tieres
   db_rating_class   int4,       -- Interne ID  Wertklasse
   wither_ht         float4,     -- Widerristhoehe
   legs_nt           float4,     -- Bein
   teats_nt          float4,     -- Gesaeuge
   head_nt           float4,     -- Kopf
   muscle_nt         float4,     -- Bemuskelung
   frame_nt          float4,     -- Rahmen
   basement_nt       float4,     -- Fundament
   type_nt           float4,     -- Typ
   back_nt           float4,     -- Ruecken
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX idx_exterior_1;
CREATE  INDEX idx_exterior_1 ON exterior ( db_animal );
-- DROP INDEX uidx_exterior_2;
CREATE UNIQUE INDEX uidx_exterior_2 ON exterior ( db_animal, event_id );

-- DROP INDEX uidx_exterior_rowid;
CREATE UNIQUE INDEX uidx_exterior_rowid ON exterior ( guid );

-- DROP TABLE ultrasound;
CREATE TABLE ultrasound (
   event_id          int4,       -- Interne ID zur Aktion
   db_animal         int4,       -- Interne ID zum Tier
   db_schema         int4,       -- Messschema
   us_lm             float4,     -- US-Lebendmasse
   us_md             float4,     -- US-Muskeldicke
   us_fa1            float4,     -- US-Fettauflage1
   us_fa2            float4,     -- US-Fettauflage2
   us_fa3            float4,     -- US-Fettauflage3
   us_fak            float4,     -- US-Fettauflage korrigiert
   us_mdk            float4,     -- US-Muskeldicke korrigiert
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX idx_ultrasound_1;
CREATE  INDEX idx_ultrasound_1 ON ultrasound ( db_animal );
-- DROP INDEX uidx_ultrasound_2;
CREATE UNIQUE INDEX uidx_ultrasound_2 ON ultrasound ( db_animal, event_id );

-- DROP INDEX uidx_ultrasound_rowid;
CREATE UNIQUE INDEX uidx_ultrasound_rowid ON ultrasound ( guid );

-- DROP TABLE feed;
CREATE TABLE feed (
   event_id          int4,       -- Interne ID Aktion
   db_animal         int4,       -- Interne ID Tier
   verzehr           float4,     -- Futterverbrauch
   aufwand           float4,     -- Futteraufwand
   verwertung        float4,     -- Futterverzehr/Tag
   comment           text,       -- Kommentar
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_feed_1;
CREATE UNIQUE INDEX uidx_feed_1 ON feed ( db_animal, event_id );

-- DROP INDEX uidx_feed_rowid;
CREATE UNIQUE INDEX uidx_feed_rowid ON feed ( guid );

-- DROP TABLE slaughter_extended;
CREATE TABLE slaughter_extended (
   event_id             int4,       -- Interne ID Aktion
   db_animal            int4,       -- Interne ID Tier
   dg                   text,       -- Durchgang
   abteil               text,       -- Abteil
   ptz                  float4,     -- PTZ
   sc_muscle_area       float4,     -- Kotelettflaeche
   sc_muscle_area_k     float4,     -- Kotelettflaeche-korr
   sc_fat_area          float4,     -- Fettflaeche
   sc_fat_area_k        float4,     -- Fettflaeche-korr
   sc_meat_fat_ration   float4,     -- Fleisch-Fett-Verh.
   sc_ph1s              float4,     -- ph1 Schinken
   sc_ph2s              float4,     -- ph2 Schinken
   sc_ph2k              float4,     -- ph2 Kotelett
   sc_lf2s              float4,     -- lf2 Schinken
   sc_lf2k              float4,     -- lf2 Kotelett
   sc_lf1s              float4,     -- lf1 Schinken
   sc_lf1k              float4,     -- lf1 Kotelett
   db_slaughter_result  float4,     -- Schlachtbefund
   db_organ_result      float4,     -- Organbefund
   db_skeleton_result   float4,     -- Skelettbefund
   sc_fbz               float4,     -- FBZ
   sc_opto              float4,     -- Opto
   sc_marbled           float4,     -- Marmorierung
   sc_carcass_wt_cold   float4,     -- Schlachtkoerpermasse cold
   sc_carcass_lt        float4,     -- Schlachtkoerperlaenge
   sc_backfat_loin      float4,     -- Rueckenspeck 1
   sc_backfat_wither    float4,     -- Rueckenspeck 2
   sc_backfat_ridge     float4,     -- Rueckenspeck 3
   sc_fatness_d         float4,     -- Seitenspeckdicke D
   sc_fatness_b         float4,     -- Seitenspeckdicke B
   sc_belly_nt          float4,     -- Bauchnote
   sc_imf               float4,     -- IMF
   sc_mf_bonn           float4,     -- MF-Bonner Formel
   sc_impk              float4,     -- Impedanz Kotelett
   sc_imps              float4,     -- Impedanz Schinken
   sc_mf_belly          float4,     -- Fleischanteil Bauch
   sc_dv                float4,     -- Dripverlust
   comment              text,       -- Kommentar
   last_change_dt       timestamp,  -- Date of last change, automatic timestamp
   last_change_user     text,       -- User who did the last change
   dirty                bool,       -- report errors from check_integrity
   chk_lvl              int2,       -- check level
   guid                 int4,       -- global identifier
   owner                text,       -- record class
   version              int4,       -- version
   synch                bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_slaughter_extended_1;
CREATE UNIQUE INDEX uidx_slaughter_extended_1 ON slaughter_extended ( db_animal, event_id );

-- DROP INDEX uidx_slaughter_extended_rowid;
CREATE UNIQUE INDEX uidx_slaughter_extended_rowid ON slaughter_extended ( guid );

-- DROP TABLE slaughter;
CREATE TABLE slaughter (
   event_id            int4,       -- Interne ID Aktion
   db_animal           int4,       -- Interne ID Tier
   sc_carcass_wt_warm  float4,     -- Schlachtkoerpermasse warm
   db_grade            float4,     -- Handelsklasse
   sc_ph1k             float4,     -- ph1 Kotelett
   sc_mf_fom           float4,     -- MF-Sondenmass
   sc_fat_measure      float4,     -- Speckmass
   sc_meat_measure     float4,     -- Fleischmass
   sc_reflection       float4,     -- Reflektionswert
   db_slaughter_house  int4,       -- Schlachtort
   last_change_dt      timestamp,  -- Date of last change, automatic timestamp
   last_change_user    text,       -- User who did the last change
   dirty               bool,       -- report errors from check_integrity
   chk_lvl             int2,       -- check level
   guid                int4,       -- global identifier
   owner               text,       -- record class
   version             int4,       -- version
   synch               bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_slaughter_1;
CREATE UNIQUE INDEX uidx_slaughter_1 ON slaughter ( db_animal, event_id );

-- DROP INDEX uidx_slaughter_rowid;
CREATE UNIQUE INDEX uidx_slaughter_rowid ON slaughter ( guid );

-- DROP TABLE slaughter_autofom;
CREATE TABLE slaughter_autofom (
   db_animal         int4,       -- Datenbankinterne Tier ID
   event_id          int4,       -- Datenbankinterne Leistungs ID
   ham_mass          float8,     -- Schinkenmasse
   cotlet_mass       float8,     -- Kotelettmasse
   shoulder_mass     float8,     -- Schultermasse
   belly_mass        float8,     -- Bauchmasse
   head_mass         float8,     -- Kopfmasse
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_slaughter_autofom_1;
CREATE UNIQUE INDEX uidx_slaughter_autofom_1 ON slaughter_autofom ( db_animal, event_id );

-- DROP INDEX uidx_slaughter_autofom_rowid;
CREATE UNIQUE INDEX uidx_slaughter_autofom_rowid ON slaughter_autofom ( guid );

-- DROP TABLE compute_traits;
CREATE TABLE compute_traits (
   db_event_type     int4,       -- ID for Events
   trait             text,       -- name of trait
   view_name         text,       -- name of view for trait
   view_sql          text,       -- sql of view for trait
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_compute_traits_1;
CREATE UNIQUE INDEX uidx_compute_traits_1 ON compute_traits ( db_event_type, trait );

-- DROP INDEX uidx_compute_traits_rowid;
CREATE UNIQUE INDEX uidx_compute_traits_rowid ON compute_traits ( guid );

-- DROP TABLE show_classes;
CREATE TABLE show_classes (
   event_id          int4,       -- ID for Events
   show_classes_id   int4,       -- ID of class
   breeds            text,       -- all breeds
   sexes             text,       -- all sexes
   birth_from        date,       -- first birth_dt
   birth_to          date,       -- last birth_dt
   short_name        text,       -- shortcut of class
   description       text,       -- description of class
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_show_classes_1;
CREATE UNIQUE INDEX uidx_show_classes_1 ON show_classes ( event_id, show_classes_id );

-- DROP INDEX uidx_show_classes_rowid;
CREATE UNIQUE INDEX uidx_show_classes_rowid ON show_classes ( guid );

-- DROP TABLE registrations;
CREATE TABLE registrations (
   event_id          int4,       -- ID for Events
   db_animal         int4,       -- Interne ID Tier
   registration_dt   date,       -- date of registration
   cancel_dt         date,       -- date of cancel registration
   show_classes_id   int4,       -- ID of class
   order_number      int4,       -- number of sequences
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_registrations_1;
CREATE UNIQUE INDEX uidx_registrations_1 ON registrations ( event_id, db_animal );

-- DROP INDEX uidx_registrations_rowid;
CREATE UNIQUE INDEX uidx_registrations_rowid ON registrations ( guid );

-- DROP TABLE auction;
CREATE TABLE auction (
   event_id          int4,       -- Interne ID Aktion
   db_animal         int4,       -- Interne ID Tier
   db_buyer          int4,       -- Interne ID Kaeufer
   cost              float4,     -- Preis
   rating            text,       -- Bewertung
   grading           text,       -- Benotung
   number            int2,       -- Auktionsnummer
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_auction_1;
CREATE UNIQUE INDEX uidx_auction_1 ON auction ( db_animal, event_id );

-- DROP INDEX uidx_auction_rowid;
CREATE UNIQUE INDEX uidx_auction_rowid ON auction ( guid );

-- DROP TABLE textident;
CREATE TABLE textident (
   db_textident      int4,       -- Interne ID Text
   ident             text,       -- Textbaustein
   ext_textident     text,       -- Inhalt Textbaustein
   condition         text,       -- Bedingung
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_textident_1;
CREATE UNIQUE INDEX uidx_textident_1 ON textident ( db_textident );

-- DROP INDEX uidx_textident_rowid;
CREATE UNIQUE INDEX uidx_textident_rowid ON textident ( guid );

-- DROP SEQUENCE seq_textident__db_textident;
CREATE SEQUENCE seq_textident__db_textident;

-- DROP TABLE naming;
CREATE TABLE naming (
   db_name           int4,       -- Interne ID Name
   db_language       int4,       -- Interne ID Sprache
   opening_dt        date,       -- Datum der ersten Gueltigkeit
   closing_dt        date,       -- Datum der letzten Gueltigkeit
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_naming_1;
CREATE UNIQUE INDEX uidx_naming_1 ON naming ( db_name );

-- DROP INDEX uidx_naming_rowid;
CREATE UNIQUE INDEX uidx_naming_rowid ON naming ( guid );

-- DROP SEQUENCE seq_naming__db_name;
CREATE SEQUENCE seq_naming__db_name;

-- DROP TABLE unit;
CREATE TABLE unit (
   db_unit           int4,       -- Internal sequence for this record
   ext_unit          text,       -- External Name of this unit
   ext_id            text,       -- External ID within this unit
   db_role           int4,       -- role from person
   db_member         int4,       -- Mitglied in
   db_address        int4,       -- Pointer to Address
   db_name           int4,       -- Pointer to Naming
   opening_dt        date,       -- Starting date for this unit
   closing_dt        date,       -- Closing date for this unit
   konto             text,       -- Kontonummer
   blz               text,       -- Bankleitzahl
   bank              text,       -- Bankverbindung
   comment           text,       -- Comments
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX  uidx_pk_unit;
CREATE UNIQUE INDEX uidx_pk_unit ON unit ( ext_unit, ext_id )
WHERE closing_dt is NULL;

-- DROP INDEX uidx_unit_1;
CREATE UNIQUE INDEX uidx_unit_1 ON unit ( db_unit );
-- DROP INDEX uidx_unit_2;
CREATE UNIQUE INDEX uidx_unit_2 ON unit ( ext_unit, ext_id, closing_dt );

-- DROP INDEX uidx_unit_rowid;
CREATE UNIQUE INDEX uidx_unit_rowid ON unit ( guid );

-- DROP SEQUENCE seq_unit__db_unit;
CREATE SEQUENCE seq_unit__db_unit;

-- DROP TABLE address;
CREATE TABLE address (
   db_address        int4,       -- Internal sequence
   firma_name        text,       -- Firmenbezeichnung
   zu_haenden        text,       -- zu Haenden
   vvo_nr            text,       -- VVO-Nummer
   lkv_nr            text,       -- LKV-Nummer
   steuer_nr         text,       -- Steuer-Nummer
   tsk_nr            text,       -- Tierseuchenkassen-Nummer
   title             text,       -- Titel
   salutation        text,       -- Anrede
   first_name        text,       -- Vorname
   second_name       text,       -- Nachname
   formatted_name    text,       -- Zusammengesetzter Name
   birth_dt          date,       -- Geburtsdatum
   street            text,       -- Name der Strasse und Nummer
   zip               text,       -- Postleitzahl
   town              text,       -- Ort
   landkreis         text,       -- Landkreis
   db_country        int4,       -- Pointer to country code
   db_language       int4,       -- Interne ID Sprache
   phone_priv        text,       -- Private Telefonnummer
   phone_firma       text,       -- Dienstliche Telefonnummer
   phone_mobil       text,       -- Mobiltelefon
   fax               text,       -- Fax
   email             text,       -- eMail-Adresse
   http              text,       -- Webaddresse
   comment           text,       -- Comments
   hz                text,       -- Herdenzeichen
   hz_pos            text,       -- Position Herdenzeichen
   bank              text,       -- Bank
   blz               text,       -- Bankleitzahl
   konto             text,       -- Kontonummer
   db_zahlung        int4,       -- Zahlungart
   mg_seit_dt        date,       -- Mitgliedsdatum seit:
   mg_bis_dt         date,       -- Mitgliedsdatum bis:
   mg_verein         text,       -- Mitglied im Verein
   mg_hbz            bool,       -- Herdbuchzuechter
   mg_gsh            bool,       -- Gebrauchsschafhalter
   mg_vorstand       bool,       -- Vorstandsmitglied
   mg_ehren          bool,       -- Ehrenmitglied
   mg_ausschuss      bool,       -- Ausschuszmitglied
   mg_passiv         bool,       -- Passives Mitglied
   gs_maedi          bool,       -- Gesundheitsstatus Maedi
   gs_cae            bool,       -- Gesundheitsstatus CAE
   gs_ptk            bool,       -- Gesundheitsstatus Paratuberkulose
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX  uidx_pk_address;
CREATE UNIQUE INDEX uidx_pk_address ON address ( first_name, second_name );

-- DROP INDEX uidx_address_1;
CREATE UNIQUE INDEX uidx_address_1 ON address ( db_address );

-- DROP INDEX uidx_address_rowid;
CREATE UNIQUE INDEX uidx_address_rowid ON address ( guid );

-- DROP SEQUENCE seq_address__db_address;
CREATE SEQUENCE seq_address__db_address;

-- DROP TABLE stickers;
CREATE TABLE stickers (
   sticker_id        int4,       -- ID of class
   name              text,       -- Format
   height            text,       -- Hoehe
   width             text,       -- Breite
   margintop         text,       -- Hoehe Rand
   marginright       text,       -- Breite Rand
   fontsize          text,       -- Spalten
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_stickers_1;
CREATE UNIQUE INDEX uidx_stickers_1 ON stickers ( sticker_id );

-- DROP INDEX uidx_stickers_rowid;
CREATE UNIQUE INDEX uidx_stickers_rowid ON stickers ( guid );

-- DROP SEQUENCE seq_stickers__sticker_id;
CREATE SEQUENCE seq_stickers__sticker_id;

-- DROP TABLE service;
CREATE TABLE service (
   db_animal         int4,       -- Datenbank-ID
   service_dt        date,       -- Besamungsdatum
   db_sire           int4,       -- bedeckender Eber
   db_technician     int4,       -- Besamer
   service_nr        int2,       -- Nummer der Besamung
   db_service_type   int4,       -- Bedeckungstyp (Gefriersperma, Sprung aus der Hand...)
   comments          text,       -- Bemerkung
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX idx_service_1;
CREATE  INDEX idx_service_1 ON service ( db_animal );
-- DROP INDEX uidx_service_2;
CREATE UNIQUE INDEX uidx_service_2 ON service ( db_animal, service_dt );

-- DROP INDEX uidx_service_rowid;
CREATE UNIQUE INDEX uidx_service_rowid ON service ( guid );

-- DROP TABLE inspool;
CREATE TABLE inspool (
   ds                text,       -- datastream (dataset) name
   record_seq        int4,       -- unique ID of record(sequence)
   in_date           date,       -- Time stamp for initial entry
   ext_unit          int4,       -- Reporting Unit
   proc_dt           date,       -- time stamp for processing
   status            text,       -- Status column
   record            text,       -- the data record
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_inspool_1;
CREATE UNIQUE INDEX uidx_inspool_1 ON inspool ( record_seq );

-- DROP INDEX uidx_inspool_rowid;
CREATE UNIQUE INDEX uidx_inspool_rowid ON inspool ( guid );

-- DROP SEQUENCE seq_inspool__record_seq;
CREATE SEQUENCE seq_inspool__record_seq;

-- DROP TABLE inspool_err;
CREATE TABLE inspool_err (
   record_seq        int4,       -- unique ID of record
   err_type          text,       -- Error type ( DB OS DATA...)
   action            text,       -- Error action
   dbtable           text,       -- Error point to table
   dbcol             text,       -- Error point to column (inside table)
   err_source        text,       -- Location where error occurred
   short_msg         text,       -- Error short message
   long_msg          text,       -- Error long message
   ext_col           text,       -- which external cols are involved
   ext_val           text,       -- external (incoming) value
   mod_val           text,       -- modified value
   comp_val          text,       -- compare values (2 in case of la)
   target_col        text,       -- Main/primary column of this record
   ds                text,       -- data stream
   ext_unit          text,       -- external unit
   status            text,       -- Active of historic?
   err_dt            timestamp,  -- timestamp for setting status
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX idx_inspool_err_1;
CREATE  INDEX idx_inspool_err_1 ON inspool_err ( record_seq );

-- DROP INDEX uidx_inspool_err_rowid;
CREATE UNIQUE INDEX uidx_inspool_err_rowid ON inspool_err ( guid );

-- DROP TABLE load_stat;
CREATE TABLE load_stat (
   ds                text,       -- Program name
   job_start         timestamp,  -- timestamp start of job
   job_end           timestamp,  -- timestamp end of job
   status            int4,       -- completion code
   rec_tot_no        int2,       -- Number of Records processed
   rec_err_no        int2,       -- Number of erroneous records
   rec_ok_no         int2,       -- Number of correct records - inserted
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_load_stat_rowid;
CREATE UNIQUE INDEX uidx_load_stat_rowid ON load_stat ( guid );

-- DROP TABLE new_pest;
CREATE TABLE new_pest (
   class             text,       -- group/class (animal, perm_u, fix...)
   key               text,       -- db_animal...
   trait             text,       -- which estimator
   estimator         float8,     -- predictor / estimator
   pev               float8,     -- predicted error variance
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_new_pest_1;
CREATE UNIQUE INDEX uidx_new_pest_1 ON new_pest ( class, key, trait );

-- DROP INDEX uidx_new_pest_rowid;
CREATE UNIQUE INDEX uidx_new_pest_rowid ON new_pest ( guid );

-- DROP TABLE sources;
CREATE TABLE sources (
   source            text,       -- source node
   tablename         text,       -- table name
   class             text,       -- owner node
   columnnames       text,       -- columns
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_sources_1;
CREATE UNIQUE INDEX uidx_sources_1 ON sources ( guid );

-- DROP INDEX uidx_sources_rowid;
CREATE UNIQUE INDEX uidx_sources_rowid ON sources ( guid );

-- DROP TABLE targets;
CREATE TABLE targets (
   target            text,       -- target node
   tablename         text,       -- table name
   class             text,       -- owner node
   columnnames       text,       -- columns
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_targets_1;
CREATE UNIQUE INDEX uidx_targets_1 ON targets ( guid );

-- DROP INDEX uidx_targets_rowid;
CREATE UNIQUE INDEX uidx_targets_rowid ON targets ( guid );

-- DROP TABLE nodes;
CREATE TABLE nodes (
   nodename          text,       -- node name
   address           text,       -- node ip address
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_nodes_1;
CREATE UNIQUE INDEX uidx_nodes_1 ON nodes ( guid );

-- DROP INDEX uidx_nodes_rowid;
CREATE UNIQUE INDEX uidx_nodes_rowid ON nodes ( guid );

-- DROP SEQUENCE seq_database__guid;
CREATE SEQUENCE seq_database__guid;

-- DROP TABLE blobs;
CREATE TABLE blobs (
   blob_id           int4,       -- number of blob
   blob              bytea,      -- binary large objects
   filename          text,       -- file name
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_blobs_rowid;
CREATE UNIQUE INDEX uidx_blobs_rowid ON blobs ( guid );

-- DROP SEQUENCE seq_blobs__blob_id;
CREATE SEQUENCE seq_blobs__blob_id;

-- DROP TABLE users;
CREATE TABLE users (
   user_id           int4,       -- unique user number
   name              text,       -- user name
   login             text,       -- login name
   password          text,       -- user password
   user_node         text,       -- user node name
   lang_id           int4,       -- language
   session_id        text,       -- session_id for the interface
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_users_1;
CREATE UNIQUE INDEX uidx_users_1 ON users ( user_id );
-- DROP INDEX uidx_users_2;
CREATE UNIQUE INDEX uidx_users_2 ON users ( login );
-- DROP INDEX uidx_users_3;
CREATE UNIQUE INDEX uidx_users_3 ON users ( guid );

-- DROP INDEX uidx_users_rowid;
CREATE UNIQUE INDEX uidx_users_rowid ON users ( guid );

-- DROP SEQUENCE seq_users__user_id;
CREATE SEQUENCE seq_users__user_id;

-- DROP TABLE roles;
CREATE TABLE roles (
   role_id           int4,       -- role number
   role              text,       -- role shortcut
   role_type         text,       -- role type - db, os
   role_name_sh      text,       -- short role name
   role_name_lng     text,       -- long role name
   description       text,       -- role description
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_roles_1;
CREATE UNIQUE INDEX uidx_roles_1 ON roles ( role_id );
-- DROP INDEX uidx_roles_2;
CREATE UNIQUE INDEX uidx_roles_2 ON roles ( role );
-- DROP INDEX uidx_roles_3;
CREATE UNIQUE INDEX uidx_roles_3 ON roles ( guid );

-- DROP INDEX uidx_roles_rowid;
CREATE UNIQUE INDEX uidx_roles_rowid ON roles ( guid );

-- DROP SEQUENCE seq_roles__role_id;
CREATE SEQUENCE seq_roles__role_id;

-- DROP TABLE user_roles;
CREATE TABLE user_roles (
   user_id           int4,       -- unique user number
   role_id           int4,       -- role number
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_user_roles_1;
CREATE UNIQUE INDEX uidx_user_roles_1 ON user_roles ( guid );

-- DROP INDEX uidx_user_roles_rowid;
CREATE UNIQUE INDEX uidx_user_roles_rowid ON user_roles ( guid );

-- DROP TABLE policies;
CREATE TABLE policies (
   policy_id         int4,       -- policy number
   tablename         text,       -- allowed table name
   columns           text,       -- allowed column names ( |column1|column2|column3|...| )
   class             text,       -- allowed class names
   action            text,       -- allowed event names (insert/update/select/delete )
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_policies_1;
CREATE UNIQUE INDEX uidx_policies_1 ON policies ( policy_id );
-- DROP INDEX uidx_policies_2;
CREATE UNIQUE INDEX uidx_policies_2 ON policies ( guid );

-- DROP INDEX uidx_policies_rowid;
CREATE UNIQUE INDEX uidx_policies_rowid ON policies ( guid );

-- DROP TABLE role_policies;
CREATE TABLE role_policies (
   role_id           int4,       -- role number
   policy_id         int4,       -- policy number
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_role_policies_1;
CREATE UNIQUE INDEX uidx_role_policies_1 ON role_policies ( guid );

-- DROP INDEX uidx_role_policies_rowid;
CREATE UNIQUE INDEX uidx_role_policies_rowid ON role_policies ( guid );

-- DROP TABLE policies_app;
CREATE TABLE policies_app (
   app_policy_id     int4,       -- policy number
   app_name          text,       -- name of: application or form or report or some event (add user)
   app_class         text,       -- allowed class names
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_policies_app_1;
CREATE UNIQUE INDEX uidx_policies_app_1 ON policies_app ( app_policy_id );
-- DROP INDEX uidx_policies_app_2;
CREATE UNIQUE INDEX uidx_policies_app_2 ON policies_app ( guid );

-- DROP INDEX uidx_policies_app_rowid;
CREATE UNIQUE INDEX uidx_policies_app_rowid ON policies_app ( guid );

-- DROP SEQUENCE seq_policies_app__app_policy_id;
CREATE SEQUENCE seq_policies_app__app_policy_id;

-- DROP TABLE role_policies_app;
CREATE TABLE role_policies_app (
   role_id           int4,       -- role number
   app_policy_id     int4,       -- policy number
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_role_policies_app_1;
CREATE UNIQUE INDEX uidx_role_policies_app_1 ON role_policies_app ( guid );

-- DROP INDEX uidx_role_policies_app_rowid;
CREATE UNIQUE INDEX uidx_role_policies_app_rowid ON role_policies_app ( guid );

-- DROP TABLE languages;
CREATE TABLE languages (
   lang_id           int4,       -- language id
   iso_lang          text,       -- ISO 639-1
   lang              text,       -- language
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   creation_dt       timestamp,  -- Timestamp of creation
   creation_user     text,       -- Who did the creation
   end_dt            timestamp,  -- Timestamp of end using
   end_user          text,       -- Who did the end status
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_languages_1;
CREATE UNIQUE INDEX uidx_languages_1 ON languages ( lang_id );
-- DROP INDEX uidx_languages_2;
CREATE UNIQUE INDEX uidx_languages_2 ON languages ( iso_lang );
-- DROP INDEX uidx_languages_3;
CREATE UNIQUE INDEX uidx_languages_3 ON languages ( guid );

-- DROP INDEX uidx_languages_rowid;
CREATE UNIQUE INDEX uidx_languages_rowid ON languages ( guid );

-- DROP SEQUENCE seq_languages__lang_id;
CREATE SEQUENCE seq_languages__lang_id;

-- DROP TABLE ar_users;
CREATE TABLE ar_users (
   user_id               int4,       -- unique user number - internal sequence
   user_login            text,       -- login name
   user_password         text,       -- user password
   user_language_id      int4,       -- default language of the user
   user_marker           text,       -- private user identifier which is insert into the owner column
   user_disabled         bool,       -- checking if the user can login to the system
   user_status           bool,       -- current login status of the user (is logged or not)
   user_last_login       timestamp,  -- date of the last login to the system
   user_last_activ_time  time,       -- the time which is updated during the user session after each opertion
   user_session_id       text,       -- session_id  for the interface
   last_change_dt        timestamp,  -- Date of last change, automatic timestamp
   last_change_user      text,       -- User who did the last change
   dirty                 bool,       -- report errors from check_integrity
   chk_lvl               int2,       -- check level
   guid                  int4,       -- global identifier
   owner                 text,       -- record class
   version               int4,       -- version
   synch                 bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_ar_users_1;
CREATE UNIQUE INDEX uidx_ar_users_1 ON ar_users ( user_id );
-- DROP INDEX uidx_ar_users_2;
CREATE UNIQUE INDEX uidx_ar_users_2 ON ar_users ( user_login );
-- DROP INDEX uidx_ar_users_3;
CREATE UNIQUE INDEX uidx_ar_users_3 ON ar_users ( guid );

-- DROP INDEX uidx_ar_users_rowid;
CREATE UNIQUE INDEX uidx_ar_users_rowid ON ar_users ( guid );

-- DROP SEQUENCE seq_ar_users__user_id;
CREATE SEQUENCE seq_ar_users__user_id;

-- DROP TABLE ar_users_data;
CREATE TABLE ar_users_data (
   user_id           int4,       -- Foreign Key to the user table
   user_first_name   text,       -- First name/Department
   user_second_name  text,       -- Family/company name
   user_institution  text,       -- company name
   user_email        text,       -- Email address
   user_country      text,       -- country of the user
   user_street       text,       -- Name of Street + Nr.
   user_town         text,       -- Town name
   user_zip          text,       -- Postal zip code
   user_other_info   text,       -- Comments
   opening_dt        date,       -- Date of opening this record
   closing_dt        date,       -- Date of closing this record
   last_change_dt    timestamp,  -- Timestamp of last change
   last_change_user  text,       -- Who did the last change
   creation_dt       timestamp,  -- Timestamp of creation
   creation_user     text,       -- Who did the creation
   end_dt            timestamp,  -- Timestamp of end using
   end_user          text,       -- Who did the end status
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_ar_users_data_1;
CREATE UNIQUE INDEX uidx_ar_users_data_1 ON ar_users_data ( user_id );
-- DROP INDEX uidx_ar_users_data_2;
CREATE UNIQUE INDEX uidx_ar_users_data_2 ON ar_users_data ( guid );

-- DROP INDEX uidx_ar_users_data_rowid;
CREATE UNIQUE INDEX uidx_ar_users_data_rowid ON ar_users_data ( guid );

-- DROP TABLE ar_roles;
CREATE TABLE ar_roles (
   role_id           int4,       -- unique role number - internal sequence
   role_name         text,       -- unique name of the role
   role_long_name    text,       -- long role name
   role_type         text,       -- the role type which can be specified as ST (System Task) or DBT (Database Task)
   role_subset       text,       -- Names of the roles which are defined as a subset of role
   role_descr        text,       -- description of the role
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_ar_roles_1;
CREATE UNIQUE INDEX uidx_ar_roles_1 ON ar_roles ( role_id );
-- DROP INDEX uidx_ar_roles_2;
CREATE UNIQUE INDEX uidx_ar_roles_2 ON ar_roles ( role_name, role_type );
-- DROP INDEX uidx_ar_roles_3;
CREATE UNIQUE INDEX uidx_ar_roles_3 ON ar_roles ( guid );

-- DROP INDEX uidx_ar_roles_rowid;
CREATE UNIQUE INDEX uidx_ar_roles_rowid ON ar_roles ( guid );

-- DROP SEQUENCE seq_ar_roles__role_id;
CREATE SEQUENCE seq_ar_roles__role_id;

-- DROP TABLE ar_user_roles;
CREATE TABLE ar_user_roles (
   user_id           int4,       -- Foreign Key to the user table
   role_id           int4,       -- Foreign Key to the role table
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_ar_user_roles_1;
CREATE UNIQUE INDEX uidx_ar_user_roles_1 ON ar_user_roles ( user_id, role_id );
-- DROP INDEX uidx_ar_user_roles_2;
CREATE UNIQUE INDEX uidx_ar_user_roles_2 ON ar_user_roles ( guid );

-- DROP INDEX uidx_ar_user_roles_rowid;
CREATE UNIQUE INDEX uidx_ar_user_roles_rowid ON ar_user_roles ( guid );

-- DROP TABLE ar_dbtpolicies;
CREATE TABLE ar_dbtpolicies (
   dbtpolicy_id      int4,       -- unique policy number for the database tasks - internal sequence
   action_id         int4,       -- Foreign Key to the codes table - SQL action type
   table_id          int4,       -- Foreign Key to the ar_dbttables
   descriptor_id     int4,       -- Foreign Key to the descriptor table
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_ar_dbtpolicies_1;
CREATE UNIQUE INDEX uidx_ar_dbtpolicies_1 ON ar_dbtpolicies ( dbtpolicy_id );
-- DROP INDEX uidx_ar_dbtpolicies_2;
CREATE UNIQUE INDEX uidx_ar_dbtpolicies_2 ON ar_dbtpolicies ( action_id, table_id, descriptor_id );
-- DROP INDEX uidx_ar_dbtpolicies_3;
CREATE UNIQUE INDEX uidx_ar_dbtpolicies_3 ON ar_dbtpolicies ( guid );

-- DROP INDEX uidx_ar_dbtpolicies_rowid;
CREATE UNIQUE INDEX uidx_ar_dbtpolicies_rowid ON ar_dbtpolicies ( guid );

-- DROP SEQUENCE seq_ar_dbtpolicies__dbtpolicy_id;
CREATE SEQUENCE seq_ar_dbtpolicies__dbtpolicy_id;

-- DROP TABLE ar_role_dbtpolicies;
CREATE TABLE ar_role_dbtpolicies (
   role_id           int4,       -- Foreign Key to the role table
   dbtpolicy_id      int4,       -- Foreign Key to the database policies table
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_ar_role_dbtpolicies_1;
CREATE UNIQUE INDEX uidx_ar_role_dbtpolicies_1 ON ar_role_dbtpolicies ( role_id, dbtpolicy_id );
-- DROP INDEX uidx_ar_role_dbtpolicies_2;
CREATE UNIQUE INDEX uidx_ar_role_dbtpolicies_2 ON ar_role_dbtpolicies ( guid );

-- DROP INDEX uidx_ar_role_dbtpolicies_rowid;
CREATE UNIQUE INDEX uidx_ar_role_dbtpolicies_rowid ON ar_role_dbtpolicies ( guid );

-- DROP TABLE ar_dbttables;
CREATE TABLE ar_dbttables (
   table_id          int4,       -- unique number - internal sequence
   table_name        text,       -- table name
   table_columns     text,       -- the columns of defined table
   table_desc        text,       -- description of the table
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_ar_dbttables_1;
CREATE UNIQUE INDEX uidx_ar_dbttables_1 ON ar_dbttables ( table_id );
-- DROP INDEX uidx_ar_dbttables_2;
CREATE UNIQUE INDEX uidx_ar_dbttables_2 ON ar_dbttables ( table_name, table_columns );
-- DROP INDEX uidx_ar_dbttables_3;
CREATE UNIQUE INDEX uidx_ar_dbttables_3 ON ar_dbttables ( guid );

-- DROP INDEX uidx_ar_dbttables_rowid;
CREATE UNIQUE INDEX uidx_ar_dbttables_rowid ON ar_dbttables ( guid );

-- DROP SEQUENCE seq_ar_dbttabels__table_id;
CREATE SEQUENCE seq_ar_dbttabels__table_id;

-- DROP TABLE ar_dbtdescriptors;
CREATE TABLE ar_dbtdescriptors (
   descriptor_id     int4,       -- unique descriptor number - internal sequence
   descriptor_name   text,       -- descriptor name is a column name which is used as a one of the filter for the access rights
   descriptor_value  text,       -- the values for defined descriptor (column)
   descriptor_desc   text,       -- description of the descriptor
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_ar_dbtdescriptors_1;
CREATE UNIQUE INDEX uidx_ar_dbtdescriptors_1 ON ar_dbtdescriptors ( descriptor_id );
-- DROP INDEX uidx_ar_dbtdescriptors_2;
CREATE UNIQUE INDEX uidx_ar_dbtdescriptors_2 ON ar_dbtdescriptors ( descriptor_name, descriptor_value );
-- DROP INDEX uidx_ar_dbtdescriptors_3;
CREATE UNIQUE INDEX uidx_ar_dbtdescriptors_3 ON ar_dbtdescriptors ( guid );

-- DROP INDEX uidx_ar_dbtdescriptors_rowid;
CREATE UNIQUE INDEX uidx_ar_dbtdescriptors_rowid ON ar_dbtdescriptors ( guid );

-- DROP SEQUENCE seq_ar_dbtdescriptor__descriptor_id;
CREATE SEQUENCE seq_ar_dbtdescriptor__descriptor_id;

-- DROP TABLE ar_stpolicies;
CREATE TABLE ar_stpolicies (
   stpolicy_id       int4,       -- unique policy number for the system tasks - internal sequence
   stpolicy_name     text,       -- name of the application or form or report or some other action
   stpolicy_type     text,       -- type of system task policy (www, report, form, action, subroutine)
   stpolicy_desc     text,       -- system policy description
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_ar_stpolicies_1;
CREATE UNIQUE INDEX uidx_ar_stpolicies_1 ON ar_stpolicies ( stpolicy_id );
-- DROP INDEX uidx_ar_stpolicies_2;
CREATE UNIQUE INDEX uidx_ar_stpolicies_2 ON ar_stpolicies ( stpolicy_name, stpolicy_type );
-- DROP INDEX uidx_ar_stpolicies_3;
CREATE UNIQUE INDEX uidx_ar_stpolicies_3 ON ar_stpolicies ( guid );

-- DROP INDEX uidx_ar_stpolicies_rowid;
CREATE UNIQUE INDEX uidx_ar_stpolicies_rowid ON ar_stpolicies ( guid );

-- DROP SEQUENCE seq_ar_stpolicies__stpolicy_id;
CREATE SEQUENCE seq_ar_stpolicies__stpolicy_id;

-- DROP TABLE ar_role_stpolicies;
CREATE TABLE ar_role_stpolicies (
   role_id           int4,       -- Foreign Key to the role table
   stpolicy_id       int4,       -- Foreign Key to the system policies table
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_ar_role_stpolicies_1;
CREATE UNIQUE INDEX uidx_ar_role_stpolicies_1 ON ar_role_stpolicies ( role_id, stpolicy_id );
-- DROP INDEX uidx_ar_role_stpolicies_2;
CREATE UNIQUE INDEX uidx_ar_role_stpolicies_2 ON ar_role_stpolicies ( guid );

-- DROP INDEX uidx_ar_role_stpolicies_rowid;
CREATE UNIQUE INDEX uidx_ar_role_stpolicies_rowid ON ar_role_stpolicies ( guid );

-- DROP TABLE ar_constraints;
CREATE TABLE ar_constraints (
   cons_id           int4,       -- unique constraints number - internal sequence
   cons_name         text,       -- constraints name
   cons_type         text,       -- constraints type which can be defined as: user-group, group-group, role-group
   cons_desc         text,       -- constraint description
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_ar_constraints_1;
CREATE UNIQUE INDEX uidx_ar_constraints_1 ON ar_constraints ( cons_id );
-- DROP INDEX uidx_ar_constraints_2;
CREATE UNIQUE INDEX uidx_ar_constraints_2 ON ar_constraints ( cons_name, cons_type );
-- DROP INDEX uidx_ar_constraints_3;
CREATE UNIQUE INDEX uidx_ar_constraints_3 ON ar_constraints ( guid );

-- DROP INDEX uidx_ar_constraints_rowid;
CREATE UNIQUE INDEX uidx_ar_constraints_rowid ON ar_constraints ( guid );

-- DROP SEQUENCE seq_ar_constraints__cons_id;
CREATE SEQUENCE seq_ar_constraints__cons_id;

-- DROP TABLE ar_role_constraints;
CREATE TABLE ar_role_constraints (
   cons_id           int4,       -- Foreign Key to the constraints table
   first_role_id     int4,       -- Foreign Key to the roles table
   second_role_id    int4,       -- Foreign Key to the roles table
   last_change_dt    timestamp,  -- Date of last change, automatic timestamp
   last_change_user  text,       -- User who did the last change
   dirty             bool,       -- report errors from check_integrity
   chk_lvl           int2,       -- check level
   guid              int4,       -- global identifier
   owner             text,       -- record class
   version           int4,       -- version
   synch             bool        -- is record targeted for synchronization
);
-- DROP INDEX uidx_ar_role_constraints_1;
CREATE UNIQUE INDEX uidx_ar_role_constraints_1 ON ar_role_constraints ( cons_id, first_role_id, second_role_id );
-- DROP INDEX uidx_ar_role_constraints_2;
CREATE UNIQUE INDEX uidx_ar_role_constraints_2 ON ar_role_constraints ( guid );

-- DROP INDEX uidx_ar_role_constraints_rowid;
CREATE UNIQUE INDEX uidx_ar_role_constraints_rowid ON ar_role_constraints ( guid );

-- DROP VIEW v_transfer;
CREATE VIEW v_transfer AS
SELECT a.guid AS v_guid,
       a.db_animal,
       a.ext_animal,
       a.db_unit,
       b.ext_unit || ':::' || b.ext_id AS ext_unit,
       a.db_farm,
       c.ext_unit || ':::' || c.ext_id AS ext_farm,
       a.opening_dt,
       a.entry_dt,
       a.exit_dt,
       a.closing_dt,
       a.db_entry_action,
       d.ext_code AS ext_entry_action,
       a.db_exit_action,
       e.ext_code AS ext_exit_action,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch,
       a.id_set,
       f.ext_code AS ext_id_set
FROM transfer a LEFT OUTER JOIN unit b ON a.db_unit = b.db_unit
                LEFT OUTER JOIN unit c ON a.db_farm = c.db_unit
                LEFT OUTER JOIN codes d ON a.db_entry_action = d.db_code
                LEFT OUTER JOIN codes e ON a.db_exit_action = e.db_code
                LEFT OUTER JOIN codes f ON a.id_set = f.db_code;

-- DROP VIEW v_locations;
CREATE VIEW v_locations AS
SELECT a.guid AS v_guid,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.db_location,
       d.ext_unit || ':::' || d.ext_id AS ext_location,
       a.entry_dt,
       a.exit_dt,
       a.db_entry_action,
       e.ext_code AS ext_entry_action,
       a.db_exit_action,
       f.ext_code AS ext_exit_action,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM locations a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
                 LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit
                 LEFT OUTER JOIN unit d ON a.db_location = d.db_unit
                 LEFT OUTER JOIN codes e ON a.db_entry_action = e.db_code
                 LEFT OUTER JOIN codes f ON a.db_exit_action = f.db_code;

-- DROP VIEW v_codes;
CREATE VIEW v_codes AS
SELECT a.guid AS v_guid,
       a.ext_code,
       a.class,
       a.db_code,
       a.short_name,
       a.long_name,
       a.description,
       a.opening_dt,
       a.closing_dt,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM codes a;

-- DROP VIEW v_animal;
CREATE VIEW v_animal AS
SELECT a.guid AS v_guid,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.db_sex,
       d.ext_code AS ext_sex,
       a.db_color,
       e.ext_code AS ext_color,
       a.birth_dt,
       a.db_sire,
       g.ext_unit || ':::' || g.ext_id || ':::' || f.ext_animal AS ext_sire,
       a.db_dam,
       i.ext_unit || ':::' || i.ext_id || ':::' || h.ext_animal AS ext_dam,
       a.parity,
       a.db_breeder,
       j.ext_unit || ':::' || j.ext_id AS ext_breeder,
       a.db_owner,
       k.ext_unit || ':::' || k.ext_id AS ext_owner,
       a.db_society,
       l.ext_unit || ':::' || l.ext_id AS ext_society,
       a.leaving_dt,
       a.db_leaving,
       m.ext_code AS ext_leaving,
       a.db_selection,
       n.ext_code AS ext_selection,
       a.name,
       a.la_rep,
       a.la_rep_dt,
       a.db_gebtyp,
       o.ext_code AS ext_gebtyp,
       a.db_auftyp,
       p.ext_code AS ext_auftyp,
       a.mz,
       a.teats_l_no,
       a.teats_r_no,
       a.db_breed,
       q.ext_code AS ext_breed,
       a.db_zb_abt,
       r.ext_code AS ext_zb_abt,
       a.zuchttier,
       a.comments,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM animal a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
              LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit
              LEFT OUTER JOIN codes d ON a.db_sex = d.db_code
              LEFT OUTER JOIN codes e ON a.db_color = e.db_code
              LEFT OUTER JOIN transfer f ON a.db_sire = f.db_animal
              LEFT OUTER JOIN unit g ON f.db_unit = g.db_unit
              LEFT OUTER JOIN transfer h ON a.db_dam = h.db_animal
              LEFT OUTER JOIN unit i ON h.db_unit = i.db_unit
              LEFT OUTER JOIN unit j ON a.db_breeder = j.db_unit
              LEFT OUTER JOIN unit k ON a.db_owner = k.db_unit
              LEFT OUTER JOIN unit l ON a.db_society = l.db_unit
              LEFT OUTER JOIN codes m ON a.db_leaving = m.db_code
              LEFT OUTER JOIN codes n ON a.db_selection = n.db_code
              LEFT OUTER JOIN codes o ON a.db_gebtyp = o.db_code
              LEFT OUTER JOIN codes p ON a.db_auftyp = p.db_code
              LEFT OUTER JOIN codes q ON a.db_breed = q.db_code
              LEFT OUTER JOIN codes r ON a.db_zb_abt = r.db_code;

-- DROP VIEW v_checkallel;
CREATE VIEW v_checkallel AS
SELECT a.guid AS v_guid,
       a.checkallel_id,
       a.class,
       a.db_id_animal,
       a.db_id_sire,
       a.db_id_dam,
       a.db_species,
       b.ext_code AS ext_species,
       a.db_rk,
       c.ext_code AS ext_rk,
       a.db_group,
       d.ext_code AS ext_group,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM checkallel a LEFT OUTER JOIN codes b ON a.db_species = b.db_code
                  LEFT OUTER JOIN codes c ON a.db_rk = c.db_code
                  LEFT OUTER JOIN codes d ON a.db_group = d.db_code;

-- DROP VIEW v_textblock;
CREATE VIEW v_textblock AS
SELECT a.guid AS v_guid,
       a.textblock_ident,
       a.textblock_class,
       a.textblock_content,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM textblock a;

-- DROP VIEW v_event;
CREATE VIEW v_event AS
SELECT a.guid AS v_guid,
       a.event_id,
       a.db_event_type,
       b.ext_code AS ext_event_type,
       a.db_sampler,
       c.ext_unit || ':::' || c.ext_id AS ext_sampler,
       a.event_dt,
       a.db_location,
       d.ext_unit || ':::' || d.ext_id AS ext_location,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM event a LEFT OUTER JOIN codes b ON a.db_event_type = b.db_code
             LEFT OUTER JOIN unit c ON a.db_sampler = c.db_unit
             LEFT OUTER JOIN unit d ON a.db_location = d.db_unit;

-- DROP VIEW v_costs;
CREATE VIEW v_costs AS
SELECT a.guid AS v_guid,
       a.db_unit,
       b.ext_unit || ':::' || b.ext_id AS ext_unit,
       a.db_cost_kl,
       c.ext_code AS ext_cost_kl,
       a.preis,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM costs a LEFT OUTER JOIN unit b ON a.db_unit = b.db_unit
             LEFT OUTER JOIN codes c ON a.db_cost_kl = c.db_code;

-- DROP VIEW v_genes;
CREATE VIEW v_genes AS
SELECT a.guid AS v_guid,
       a.event_id,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.db_genes_class,
       d.ext_code AS ext_genes_class,
       a.db_genes,
       e.ext_code AS ext_genes,
       a.db_allel_1,
       f.ext_code AS ext_allel_1,
       a.db_allel_2,
       g.ext_code AS ext_allel_2,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM genes a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
             LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit
             LEFT OUTER JOIN codes d ON a.db_genes_class = d.db_code
             LEFT OUTER JOIN codes e ON a.db_genes = e.db_code
             LEFT OUTER JOIN codes f ON a.db_allel_1 = f.db_code
             LEFT OUTER JOIN codes g ON a.db_allel_2 = g.db_code;

-- DROP VIEW v_external_traits;
CREATE VIEW v_external_traits AS
SELECT a.guid AS v_guid,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.db_trait,
       d.ext_code AS ext_trait,
       a.value,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM external_traits a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
                       LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit
                       LEFT OUTER JOIN codes d ON a.db_trait = d.db_code;

-- DROP VIEW v_notice;
CREATE VIEW v_notice AS
SELECT a.guid AS v_guid,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.notice_dt,
       a.notice,
       a.db_notice_type,
       d.ext_code AS ext_notice_type,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM notice a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
              LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit
              LEFT OUTER JOIN codes d ON a.db_notice_type = d.db_code;

-- DROP VIEW v_litter;
CREATE VIEW v_litter AS
SELECT a.guid AS v_guid,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.db_sire,
       e.ext_unit || ':::' || e.ext_id || ':::' || d.ext_animal AS ext_sire,
       a.parity,
       a.delivery_dt,
       a.db_breed_sire,
       f.ext_code AS ext_breed_sire,
       a.db_help_birth,
       g.ext_code AS ext_help_birth,
       a.ewa,
       a.zwz,
       a.born_alive_no,
       a.male_born_no,
       a.mumien_no,
       a.still_born_no,
       a.weaned_dt,
       a.db_weaned_typ,
       a.weaned_no,
       a.foster_no,
       a.notch_start,
       a.birthweigh_dt,
       a.gv,
       a.avg_birthweight,
       a.sda_birthweight,
       a.error_flag,
       a.comment,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM litter a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
              LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit
              LEFT OUTER JOIN transfer d ON a.db_sire = d.db_animal
              LEFT OUTER JOIN unit e ON d.db_unit = e.db_unit
              LEFT OUTER JOIN codes f ON a.db_breed_sire = f.db_code
              LEFT OUTER JOIN codes g ON a.db_help_birth = g.db_code;

-- DROP VIEW v_weight;
CREATE VIEW v_weight AS
SELECT a.guid AS v_guid,
       a.event_id,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.test_wt,
       a.ltz,
       a.alter,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM weight a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
              LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit;

-- DROP VIEW v_udder;
CREATE VIEW v_udder AS
SELECT a.guid AS v_guid,
       a.event_id,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.mbk_n,
       a.eut_n,
       a.zit_n,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM udder a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
             LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit;

-- DROP VIEW v_exterior;
CREATE VIEW v_exterior AS
SELECT a.guid AS v_guid,
       a.event_id,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.db_rating_class,
       d.ext_code AS ext_rating_class,
       a.wither_ht,
       a.legs_nt,
       a.teats_nt,
       a.head_nt,
       a.muscle_nt,
       a.frame_nt,
       a.basement_nt,
       a.type_nt,
       a.back_nt,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM exterior a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
                LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit
                LEFT OUTER JOIN codes d ON a.db_rating_class = d.db_code;

-- DROP VIEW v_ultrasound;
CREATE VIEW v_ultrasound AS
SELECT a.guid AS v_guid,
       a.event_id,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.db_schema,
       d.ext_code AS ext_schema,
       a.us_lm,
       a.us_md,
       a.us_fa1,
       a.us_fa2,
       a.us_fa3,
       a.us_fak,
       a.us_mdk,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM ultrasound a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
                  LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit
                  LEFT OUTER JOIN codes d ON a.db_schema = d.db_code;

-- DROP VIEW v_feed;
CREATE VIEW v_feed AS
SELECT a.guid AS v_guid,
       a.event_id,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.verzehr,
       a.aufwand,
       a.verwertung,
       a.comment,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM feed a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
            LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit;

-- DROP VIEW v_slaughter_extended;
CREATE VIEW v_slaughter_extended AS
SELECT a.guid AS v_guid,
       a.event_id,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.dg,
       a.abteil,
       a.ptz,
       a.sc_muscle_area,
       a.sc_muscle_area_k,
       a.sc_fat_area,
       a.sc_fat_area_k,
       a.sc_meat_fat_ration,
       a.sc_ph1s,
       a.sc_ph2s,
       a.sc_ph2k,
       a.sc_lf2s,
       a.sc_lf2k,
       a.sc_lf1s,
       a.sc_lf1k,
       a.db_slaughter_result,
       d.ext_code AS ext_slaughter_result,
       a.db_organ_result,
       a.db_skeleton_result,
       a.sc_fbz,
       a.sc_opto,
       a.sc_marbled,
       a.sc_carcass_wt_cold,
       a.sc_carcass_lt,
       a.sc_backfat_loin,
       a.sc_backfat_wither,
       a.sc_backfat_ridge,
       a.sc_fatness_d,
       a.sc_fatness_b,
       a.sc_belly_nt,
       a.sc_imf,
       a.sc_mf_bonn,
       a.sc_impk,
       a.sc_imps,
       a.sc_mf_belly,
       a.sc_dv,
       a.comment,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM slaughter_extended a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
                          LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit
                          LEFT OUTER JOIN codes d ON a.db_slaughter_result = d.db_code;

-- DROP VIEW v_slaughter;
CREATE VIEW v_slaughter AS
SELECT a.guid AS v_guid,
       a.event_id,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.sc_carcass_wt_warm,
       a.db_grade,
       a.sc_ph1k,
       a.sc_mf_fom,
       a.sc_fat_measure,
       a.sc_meat_measure,
       a.sc_reflection,
       a.db_slaughter_house,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM slaughter a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
                 LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit;

-- DROP VIEW v_slaughter_autofom;
CREATE VIEW v_slaughter_autofom AS
SELECT a.guid AS v_guid,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.event_id,
       a.ham_mass,
       a.cotlet_mass,
       a.shoulder_mass,
       a.belly_mass,
       a.head_mass,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM slaughter_autofom a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
                         LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit;

-- DROP VIEW v_compute_traits;
CREATE VIEW v_compute_traits AS
SELECT a.guid AS v_guid,
       a.db_event_type,
       b.ext_code AS ext_event_type,
       a.trait,
       a.view_name,
       a.view_sql,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM compute_traits a LEFT OUTER JOIN codes b ON a.db_event_type = b.db_code;

-- DROP VIEW v_show_classes;
CREATE VIEW v_show_classes AS
SELECT a.guid AS v_guid,
       a.event_id,
       a.show_classes_id,
       a.breeds,
       a.sexes,
       a.birth_from,
       a.birth_to,
       a.short_name,
       a.description,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM show_classes a;

-- DROP VIEW v_registrations;
CREATE VIEW v_registrations AS
SELECT a.guid AS v_guid,
       a.event_id,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.registration_dt,
       a.cancel_dt,
       a.show_classes_id,
       a.order_number,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM registrations a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
                     LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit;

-- DROP VIEW v_auction;
CREATE VIEW v_auction AS
SELECT a.guid AS v_guid,
       a.event_id,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.db_buyer,
       d.ext_unit || ':::' || d.ext_id AS ext_buyer,
       a.cost,
       a.rating,
       a.grading,
       a.number,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM auction a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
               LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit
               LEFT OUTER JOIN unit d ON a.db_buyer = d.db_unit;

-- DROP VIEW v_textident;
CREATE VIEW v_textident AS
SELECT a.guid AS v_guid,
       a.db_textident,
       a.ident,
       a.ext_textident,
       a.condition,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM textident a;

-- DROP VIEW v_naming;
CREATE VIEW v_naming AS
SELECT a.guid AS v_guid,
       a.db_name,
       a.db_language,
       b.ext_code AS ext_language,
       a.opening_dt,
       a.closing_dt,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM naming a LEFT OUTER JOIN codes b ON a.db_language = b.db_code;

-- DROP VIEW v_unit;
CREATE VIEW v_unit AS
SELECT a.guid AS v_guid,
       a.db_unit,
       a.ext_unit,
       a.ext_id,
       a.db_role,
       b.ext_code AS ext_role,
       a.db_member,
       a.db_address,
       c.first_name || ':::' || c.second_name AS ext_address,
       a.db_name,
       a.opening_dt,
       a.closing_dt,
       a.konto,
       a.blz,
       a.bank,
       a.comment,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM unit a LEFT OUTER JOIN codes b ON a.db_role = b.db_code
            LEFT OUTER JOIN address c ON a.db_address = c.db_address;

-- DROP VIEW v_address;
CREATE VIEW v_address AS
SELECT a.guid AS v_guid,
       a.db_address,
       a.firma_name,
       a.zu_haenden,
       a.vvo_nr,
       a.lkv_nr,
       a.steuer_nr,
       a.tsk_nr,
       a.title,
       a.salutation,
       a.first_name,
       a.second_name,
       a.formatted_name,
       a.birth_dt,
       a.street,
       a.zip,
       a.town,
       a.landkreis,
       a.db_country,
       b.ext_code AS ext_country,
       a.db_language,
       c.ext_code AS ext_language,
       a.phone_priv,
       a.phone_firma,
       a.phone_mobil,
       a.fax,
       a.email,
       a.http,
       a.comment,
       a.hz,
       a.hz_pos,
       a.bank,
       a.blz,
       a.konto,
       a.db_zahlung,
       d.ext_code AS ext_zahlung,
       a.mg_seit_dt,
       a.mg_bis_dt,
       a.mg_verein,
       a.mg_hbz,
       a.mg_gsh,
       a.mg_vorstand,
       a.mg_ehren,
       a.mg_ausschuss,
       a.mg_passiv,
       a.gs_maedi,
       a.gs_cae,
       a.gs_ptk,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM address a LEFT OUTER JOIN codes b ON a.db_country = b.db_code
               LEFT OUTER JOIN codes c ON a.db_language = c.db_code
               LEFT OUTER JOIN codes d ON a.db_zahlung = d.db_code;

-- DROP VIEW v_stickers;
CREATE VIEW v_stickers AS
SELECT a.guid AS v_guid,
       a.sticker_id,
       a.name,
       a.height,
       a.width,
       a.margintop,
       a.marginright,
       a.fontsize,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM stickers a;

-- DROP VIEW v_service;
CREATE VIEW v_service AS
SELECT a.guid AS v_guid,
       a.db_animal,
       c.ext_unit || ':::' || c.ext_id || ':::' || b.ext_animal AS ext_animal,
       a.service_dt,
       a.db_sire,
       e.ext_unit || ':::' || e.ext_id || ':::' || d.ext_animal AS ext_sire,
       a.db_technician,
       f.ext_unit || ':::' || f.ext_id AS ext_technician,
       a.service_nr,
       a.db_service_type,
       g.ext_code AS ext_service_type,
       a.comments,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM service a LEFT OUTER JOIN transfer b ON a.db_animal = b.db_animal
               LEFT OUTER JOIN unit c ON b.db_unit = c.db_unit
               LEFT OUTER JOIN transfer d ON a.db_sire = d.db_animal
               LEFT OUTER JOIN unit e ON d.db_unit = e.db_unit
               LEFT OUTER JOIN unit f ON a.db_technician = f.db_unit
               LEFT OUTER JOIN codes g ON a.db_service_type = g.db_code;

-- DROP VIEW v_inspool;
CREATE VIEW v_inspool AS
SELECT a.guid AS v_guid,
       a.ds,
       a.record_seq,
       a.in_date,
       a.ext_unit,
       a.proc_dt,
       a.status,
       a.record,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM inspool a;

-- DROP VIEW v_inspool_err;
CREATE VIEW v_inspool_err AS
SELECT a.guid AS v_guid,
       a.record_seq,
       a.err_type,
       a.action,
       a.dbtable,
       a.dbcol,
       a.err_source,
       a.short_msg,
       a.long_msg,
       a.ext_col,
       a.ext_val,
       a.mod_val,
       a.comp_val,
       a.target_col,
       a.ds,
       a.ext_unit,
       a.status,
       a.err_dt,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM inspool_err a;

-- DROP VIEW v_load_stat;
CREATE VIEW v_load_stat AS
SELECT a.guid AS v_guid,
       a.ds,
       a.job_start,
       a.job_end,
       a.status,
       a.rec_tot_no,
       a.rec_err_no,
       a.rec_ok_no,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM load_stat a;

-- DROP VIEW v_new_pest;
CREATE VIEW v_new_pest AS
SELECT a.guid AS v_guid,
       a.class,
       a.key,
       a.trait,
       a.estimator,
       a.pev,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM new_pest a;

-- DROP VIEW v_sources;
CREATE VIEW v_sources AS
SELECT a.guid AS v_guid,
       a.source,
       a.tablename,
       a.class,
       a.columnnames,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM sources a;

-- DROP VIEW v_targets;
CREATE VIEW v_targets AS
SELECT a.guid AS v_guid,
       a.target,
       a.tablename,
       a.class,
       a.columnnames,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM targets a;

-- DROP VIEW v_nodes;
CREATE VIEW v_nodes AS
SELECT a.guid AS v_guid,
       a.nodename,
       a.address,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM nodes a;

-- DROP VIEW v_blobs;
CREATE VIEW v_blobs AS
SELECT a.guid AS v_guid,
       a.blob_id,
       a.blob,
       a.filename,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM blobs a;

-- DROP VIEW v_users;
CREATE VIEW v_users AS
SELECT a.guid AS v_guid,
       a.user_id,
       a.name,
       a.login,
       a.password,
       a.user_node,
       a.lang_id,
       a.session_id,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM users a;

-- DROP VIEW v_roles;
CREATE VIEW v_roles AS
SELECT a.guid AS v_guid,
       a.role_id,
       a.role,
       a.role_type,
       a.role_name_sh,
       a.role_name_lng,
       a.description,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM roles a;

-- DROP VIEW v_user_roles;
CREATE VIEW v_user_roles AS
SELECT a.guid AS v_guid,
       a.user_id,
       a.role_id,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM user_roles a;

-- DROP VIEW v_policies;
CREATE VIEW v_policies AS
SELECT a.guid AS v_guid,
       a.policy_id,
       a.tablename,
       a.columns,
       a.class,
       a.action,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM policies a;

-- DROP VIEW v_role_policies;
CREATE VIEW v_role_policies AS
SELECT a.guid AS v_guid,
       a.role_id,
       a.policy_id,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM role_policies a;

-- DROP VIEW v_policies_app;
CREATE VIEW v_policies_app AS
SELECT a.guid AS v_guid,
       a.app_policy_id,
       a.app_name,
       a.app_class,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM policies_app a;

-- DROP VIEW v_role_policies_app;
CREATE VIEW v_role_policies_app AS
SELECT a.guid AS v_guid,
       a.role_id,
       a.app_policy_id,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM role_policies_app a;

-- DROP VIEW v_languages;
CREATE VIEW v_languages AS
SELECT a.guid AS v_guid,
       a.lang_id,
       a.iso_lang,
       a.lang,
       a.last_change_dt,
       a.last_change_user,
       a.creation_dt,
       a.creation_user,
       a.end_dt,
       a.end_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM languages a;

-- DROP VIEW v_ar_users;
CREATE VIEW v_ar_users AS
SELECT a.guid AS v_guid,
       a.user_id,
       a.user_login,
       a.user_password,
       a.user_language_id,
       a.user_marker,
       a.user_disabled,
       a.user_status,
       a.user_last_login,
       a.user_last_activ_time,
       a.user_session_id,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM ar_users a;

-- DROP VIEW v_ar_users_data;
CREATE VIEW v_ar_users_data AS
SELECT a.guid AS v_guid,
       a.user_id,
       a.user_first_name,
       a.user_second_name,
       a.user_institution,
       a.user_email,
       a.user_country,
       a.user_street,
       a.user_town,
       a.user_zip,
       a.user_other_info,
       a.opening_dt,
       a.closing_dt,
       a.last_change_dt,
       a.last_change_user,
       a.creation_dt,
       a.creation_user,
       a.end_dt,
       a.end_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM ar_users_data a;

-- DROP VIEW v_ar_roles;
CREATE VIEW v_ar_roles AS
SELECT a.guid AS v_guid,
       a.role_id,
       a.role_name,
       a.role_long_name,
       a.role_type,
       a.role_subset,
       a.role_descr,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM ar_roles a;

-- DROP VIEW v_ar_user_roles;
CREATE VIEW v_ar_user_roles AS
SELECT a.guid AS v_guid,
       a.user_id,
       a.role_id,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM ar_user_roles a;

-- DROP VIEW v_ar_dbtpolicies;
CREATE VIEW v_ar_dbtpolicies AS
SELECT a.guid AS v_guid,
       a.dbtpolicy_id,
       a.action_id,
       b.ext_code AS ext_action_id,
       a.table_id,
       a.descriptor_id,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM ar_dbtpolicies a LEFT OUTER JOIN codes b ON a.action_id = b.db_code;

-- DROP VIEW v_ar_role_dbtpolicies;
CREATE VIEW v_ar_role_dbtpolicies AS
SELECT a.guid AS v_guid,
       a.role_id,
       a.dbtpolicy_id,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM ar_role_dbtpolicies a;

-- DROP VIEW v_ar_dbttables;
CREATE VIEW v_ar_dbttables AS
SELECT a.guid AS v_guid,
       a.table_id,
       a.table_name,
       a.table_columns,
       a.table_desc,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM ar_dbttables a;

-- DROP VIEW v_ar_dbtdescriptors;
CREATE VIEW v_ar_dbtdescriptors AS
SELECT a.guid AS v_guid,
       a.descriptor_id,
       a.descriptor_name,
       a.descriptor_value,
       a.descriptor_desc,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM ar_dbtdescriptors a;

-- DROP VIEW v_ar_stpolicies;
CREATE VIEW v_ar_stpolicies AS
SELECT a.guid AS v_guid,
       a.stpolicy_id,
       a.stpolicy_name,
       a.stpolicy_type,
       a.stpolicy_desc,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM ar_stpolicies a;

-- DROP VIEW v_ar_role_stpolicies;
CREATE VIEW v_ar_role_stpolicies AS
SELECT a.guid AS v_guid,
       a.role_id,
       a.stpolicy_id,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM ar_role_stpolicies a;

-- DROP VIEW v_ar_constraints;
CREATE VIEW v_ar_constraints AS
SELECT a.guid AS v_guid,
       a.cons_id,
       a.cons_name,
       a.cons_type,
       a.cons_desc,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM ar_constraints a;

-- DROP VIEW v_ar_role_constraints;
CREATE VIEW v_ar_role_constraints AS
SELECT a.guid AS v_guid,
       a.cons_id,
       a.first_role_id,
       a.second_role_id,
       a.last_change_dt,
       a.last_change_user,
       a.dirty,
       a.chk_lvl,
       a.guid,
       a.owner,
       a.version,
       a.synch
FROM ar_role_constraints a;


-- DROP VIEW entry_transfer;
CREATE VIEW entry_transfer AS
SELECT      db_animal, ext_animal, db_unit, db_farm, opening_dt, entry_dt, exit_dt, closing_dt, db_entry_action, db_exit_action, last_change_dt, last_change_user, dirty, chk_lvl, guid, owner, version, synch, id_set
FROM        transfer
WHERE       closing_dt is NULL;

-- DROP VIEW entry_codes;
CREATE VIEW entry_codes AS
SELECT      ext_code, class, db_code, short_name, long_name, description, opening_dt, closing_dt, last_change_dt, last_change_user, dirty, chk_lvl, guid, owner, version, synch
FROM        codes
WHERE       closing_dt is NULL;

-- DROP VIEW entry_unit;
CREATE VIEW entry_unit AS
SELECT      db_unit, ext_unit, ext_id, db_role, db_member, db_address, db_name, opening_dt, closing_dt, konto, blz, bank, comment, last_change_dt, last_change_user, dirty, chk_lvl, guid, owner, version, synch
FROM        unit
WHERE       closing_dt is NULL;

