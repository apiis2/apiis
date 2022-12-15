##############################################################################
# $Id: Makefile,v 1.2 2005/09/07 11:55:31 marek Exp $
##############################################################################
#  Syntax: make 
###############################################################################
# avoid error messages when env not set correctly:
ifneq ($(APIIS_HOME),)
ifneq ($(APIIS_LOCAL),)
endif
endif
###############################################################################

		
arc-doc:	# pod2latex 
	@(      latex arc_master-tex.tex; \
		makeindex arc_master-tex; \
		latex arc_master-tex.tex; \
		latex arc_master-tex.tex; \
		dvips arc_master-tex -o $(APIIS_HOME)/doc/developer/access-control/arc-doc.ps; \
		mv -f arc_master-tex.dvi $(APIIS_HOME)/doc/developer/access-control/arc-doc.dvi; \
		ps2pdf $(APIIS_HOME)/doc/developer/access-control/arc-doc.ps $(APIIS_HOME)/doc/developer/access-control/arc-doc.pdf; \
		dvi2booklet arc-doc.dvi; \
		rm *.aux *.log *.ilg *.idx *.ind *.toc; \
	)
