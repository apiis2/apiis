##############################################################################
# $Id: Makefile,v 1.11 2005/09/15 09:27:07 detlef Exp $
##############################################################################
#  Syntax: make 
###############################################################################
# avoid error messages when env not set correctly:
ifneq ($(APIIS_HOME),)
ifneq ($(APIIS_LOCAL),)
endif
endif
###############################################################################

FILES_CORE    = $(APIIS_HOME)/lib/Apiis.pm \
                $(APIIS_HOME)/lib/Apiis/Init.pm \
                $(APIIS_HOME)/lib/Apiis/Init/Config.pm \
                $(APIIS_HOME)/lib/Apiis/Init/Date.pm \
                $(APIIS_HOME)/lib/Apiis/Init/XML.pm \
		$(APIIS_HOME)/lib/Apiis/Model.pm \
		$(APIIS_HOME)/lib/Apiis/Errors.pm \
		$(APIIS_HOME)/lib/Apiis/Record.pm \
		$(APIIS_HOME)/lib/Apiis/Misc.pm \
		$(APIIS_HOME)/lib/Apiis/CheckFile.pm

FILES_AUTH  =   $(APIIS_HOME)/lib/Apiis/Auth/Auth.pm \
                $(APIIS_HOME)/lib/Apiis/Auth/Role.pm \
                $(APIIS_HOME)/lib/Apiis/Auth/AppAuth.pm \
                $(APIIS_HOME)/lib/Apiis/Auth/AccessControl.pm

FILES_DB      = $(APIIS_HOME)/lib/Apiis/DataBase/Init.pm \
                $(APIIS_HOME)/lib/Apiis/DataBase/DBCreation.pm \
                $(APIIS_HOME)/lib/Apiis/DataBase/User.pm
		
FILES_DB_RECORD = \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Column.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Insert.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Update.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Delete.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Fetch.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Coding.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Check.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Modify.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Trigger.pm

FILES_DB_RECORD_CHECK = \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Check/DateDiff.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Check/ForeignKey.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Check/IsAFloat.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Check/IsANumber.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Check/IsEqual.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Check/LastAction.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Check/List.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Check/NoCheck.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Check/NoNumber.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Check/NotNull.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Check/PrimaryKey.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Check/Range.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Check/ReservedStrings.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Check/Unique.pm

FILES_DB_RECORD_MODIFY = \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Modify/CommaToDot.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Modify/ConvertBool.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Modify/DotToColon.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Modify/LowerCase.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Modify/SetNow.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Modify/SetUser.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Modify/UpperCase.pm

FILES_DB_RECORD_TRIGGER = \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Trigger/SetGuid.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Trigger/SetNode.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/Record/Trigger/SetVersion.pm

FILES_DB_SQL =  $(APIIS_HOME)/lib/Apiis/DataBase/SQL/DataStream.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/SQL/DirectSQL.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/SQL/PseudoStatement.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/SQL/Statement.pm \
		$(APIIS_HOME)/lib/Apiis/DataBase/SQL/MakeSQL.pm

FILES_DB_SYNC = $(APIIS_HOME)/lib/Apiis/DataBase/Sync/Node.pm \
		$(APIIS_HOME)/lib/apiis_synchro.pm

FILES_FORMS   = $(APIIS_HOME)/lib/Apiis/Form/Init.pm \
		$(APIIS_HOME)/lib/Apiis/Form/Base.pm \
		$(APIIS_HOME)/lib/Apiis/Form/Tk.pm \
		$(APIIS_HOME)/lib/Apiis/Form/HTML.pm

FILES_FORMS_OLD = $(APIIS_HOME)/lib/yaform.pm \
		$(APIIS_HOME)/lib/form_ulib.pm \
		$(APIIS_HOME)/bin/apiish \
		$(APIIS_HOME)/lib/MenuFiles.pm \
		$(APIIS_HOME)/lib/MenuForms.pm

FILES_MISC    = $(APIIS_HOME)/lib/ref_breedprg_alib.pm \
		$(APIIS_HOME)/lib/xfig_lib.pm


FILES_BIN     = $(APIIS_HOME)/bin/check_integrity \
		$(APIIS_HOME)/bin/csv.init \
		$(APIIS_HOME)/bin/cvs2cl \
		$(APIIS_HOME)/bin/extract_for_blupMEM.pl \
		$(APIIS_HOME)/bin/file2inspool.pl \
		$(APIIS_HOME)/bin/Form \
		$(APIIS_HOME)/bin/FormDesigner \
		$(APIIS_HOME)/bin/hashtable \
		$(APIIS_HOME)/bin/load_db_from_INSPOOL \
		$(APIIS_HOME)/bin/load_stat \
		$(APIIS_HOME)/bin/mkdescr \
		$(APIIS_HOME)/bin/mkform \
		$(APIIS_HOME)/bin/mkLOfForm \
		$(APIIS_HOME)/bin/mkLOform \
		$(APIIS_HOME)/bin/mkLOWform \
		$(APIIS_HOME)/bin/mkmodel \
		$(APIIS_HOME)/bin/mkmodinst \
		$(APIIS_HOME)/bin/mksql \
		$(APIIS_HOME)/bin/model2xfig \
		$(APIIS_HOME)/bin/model2xml.pl \
		$(APIIS_HOME)/bin/pedigree_loops.pl \
		$(APIIS_HOME)/bin/renumber \
		$(APIIS_HOME)/bin/selection.pl \
		$(APIIS_HOME)/bin/show_rules \
		$(APIIS_HOME)/bin/viz_db_struct \
		$(APIIS_HOME)/bin/WebForm.pl \
		$(APIIS_HOME)/bin/xml2model.pl

		
dev-doc:	# pod2latex 
	@( 	xtract_undoc; \
		echo "\chapter{PERL Subroutine Documentation}" > pod/pod-chapter.tex; \
		\
		pod2latex -h1level=2 -modify -out=pod/FILES_CORE.tex $(FILES_CORE); \
		echo "\section{The Core}" >> pod/pod-chapter.tex; \
		echo "\input{./pod/FILES_CORE.tex}" >> pod/pod-chapter.tex; \
		\
		pod2latex -h1level=2 -modify -out=pod/FILES_AUTH.tex $(FILES_AUTH); \
		echo "\section{Authentication and Authorisation}" >> pod/pod-chapter.tex; \
		echo "\input{./pod/FILES_AUTH.tex}" >> pod/pod-chapter.tex; \
		\
		pod2latex -h1level=2 -modify -out=pod/FILES_DB.tex $(FILES_DB); \
		echo "\section{The Database}" >> pod/pod-chapter.tex; \
		echo "\input{./pod/FILES_DB.tex}" >> pod/pod-chapter.tex; \
		\
		pod2latex -h1level=3 -modify -out=pod/FILES_DB_RECORD.tex $(FILES_DB_RECORD); \
		echo "\subsection{The Database Record Object}" >> pod/pod-chapter.tex; \
		echo "\input{./pod/FILES_DB_RECORD.tex}" >> pod/pod-chapter.tex; \
		\
		pod2latex -h1level=3 -modify -out=pod/FILES_DB_RECORD_MODIFY.tex $(FILES_DB_RECORD_MODIFY); \
		echo "\subsection{Modify Rules}" >> pod/pod-chapter.tex; \
		echo "\input{./pod/FILES_DB_RECORD_MODIFY.tex}" >> pod/pod-chapter.tex; \
		\
		pod2latex -h1level=3 -modify -out=pod/FILES_DB_RECORD_CHECK.tex $(FILES_DB_RECORD_CHECK); \
		echo "\subsection{Check Rules}" >> pod/pod-chapter.tex; \
		echo "\input{./pod/FILES_DB_RECORD_CHECK.tex}" >> pod/pod-chapter.tex; \
		\
		pod2latex -h1level=3 -modify -out=pod/FILES_DB_RECORD_TRIGGER.tex $(FILES_DB_RECORD_TRIGGER); \
		echo "\subsection{Triggers}" >> pod/pod-chapter.tex; \
		echo "\input{./pod/FILES_DB_RECORD_TRIGGER.tex}" >> pod/pod-chapter.tex; \
		\
		pod2latex -h1level=3 -modify -out=pod/FILES_DB_SQL.tex $(FILES_DB_SQL); \
		echo "\subsection{Using SQL}" >> pod/pod-chapter.tex; \
		echo "\input{./pod/FILES_DB_SQL.tex}" >> pod/pod-chapter.tex; \
		\
		pod2latex -h1level=3 -modify -out=pod/FILES_DB_SYNC.tex $(FILES_DB_SYNC); \
		echo "\subsection{The Synchronization}" >> pod/pod-chapter.tex; \
		echo "\input{./pod/FILES_DB_SYNC.tex}" >> pod/pod-chapter.tex; \
		\
		pod2latex -h1level=2 -modify -out=pod/FILES_FORMS.tex $(FILES_FORMS); \
		echo "\section{The Forms}" >> pod/pod-chapter.tex; \
		echo "\input{./pod/FILES_FORMS.tex}" >> pod/pod-chapter.tex; \
		\
		touch pod/FILES_FORMS_OLD.tex; \
		pod2latex -h1level=2 -modify -out=pod/FILES_FORMS_OLD.tex $(FILES_FORMS_OLD); \
		echo "\subsection{The Forms old}" >> pod/pod-chapter.tex; \
		echo "\input{./pod/FILES_FORMS_OLD.tex}" >> pod/pod-chapter.tex; \
		\
		pod2latex -h1level=2 -modify -out=pod/FILES_MISC.tex $(FILES_MISC); \
		echo "\section{The Misc}" >> pod/pod-chapter.tex; \
		echo "\input{./pod/FILES_MISC.tex}" >> pod/pod-chapter.tex; \
		\
		pod2latex -h1level=2 -modify -out=pod/FILES_BIN.tex $(FILES_BIN); \
		echo "\section{The Binaries}" >> pod/pod-chapter.tex; \
		echo "\input{./pod/FILES_BIN.tex}" >> pod/pod-chapter.tex; \
		\
		latex master-tex.tex; \
		makeindex master-tex; \
		latex master-tex.tex; \
		latex master-tex.tex; \
		dvips master-tex -o $(APIIS_HOME)/doc/developer-doc.ps; \
		mv -f master-tex.dvi $(APIIS_HOME)/doc/developer-doc.dvi; \
		ps2pdf $(APIIS_HOME)/doc/developer-doc.ps $(APIIS_HOME)/doc/developer-doc.pdf; \
		rm *.aux *.log *.ilg *.idx *.ind *.toc; \
	)
