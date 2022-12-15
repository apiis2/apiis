############################################################################### 
# $Id: Makefile,v 1.5 2004/02/17 10:11:58 detlef Exp $
############################################################################### 
  
###############################################################################
# avoid error messages when env not set correctly:
ifneq ($(APIIS_HOME),)
ifneq ($(APIIS_LOCAL),)
endif
endif
###############################################################################

docclean:   #  cleans the doc subdir
	@(cd $(APIIS_HOME)/$(DOC_DIR); $(MAKE) clean)
	
docs: #      create .ps and .lj files of the manual
	@(cd $(APIIS_HOME)/$(DOC_DIR); \
	$(MAKE) "MAKEFLAGS=$(MAKEFLAGS)" "DOC_VERSION=$(DOC_VERSION)" $@ )
imp-doc: # create docs for implementers
	latex master-tex.tex; \
	makeindex master-tex; \
	latex master-tex.tex; \
	latex master-tex.tex; \
	dvips master-tex -o $(APIIS_HOME)/doc/implementer-doc.ps; \
	ps2pdf $(APIIS_HOME)/doc/implementer-doc.ps $(APIIS_HOME)/doc/implementer-doc.pdf; \
	rm *.aux *.log *.dvi *.ilg *.idx *.ind *.toc; \

