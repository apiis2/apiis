##############################################################################
# $Id: Makefile,v 1.14 2015/11/13 08:59:52 heli Exp $
# create a tar file for distribution
##############################################################################
TAG=
LASTTAG=

help: #		show targets
	@echo -e "\ntarget            description";\
	echo "==================================================";\
	egrep "^[[:alnum:].+_()-]*:" Makefile |sed -e 's/:[^#]*#/: /';\
	echo "";\


apiis-home: #	auxiliary target to check correct command line parameters
	@if test -z "$(APIIS_HOME)"; then \
	echo '*****************************************************';\
	echo 'APIIS_HOME is not set.'; \
	echo '.... terminated.'; \
	echo \
	'*****************************************************'; \
	exit 1;\
	fi       

tag: #		auxiliary target to check correct command line parameters
	@if test -z "$(TAG)"; then \
	echo '*****************************************************';\
	echo 'usage: make <target> TAG=XXX'; \
	echo 'No tag given.'; \
	echo '.... terminated.'; \
	echo \
	'*****************************************************'; \
	exit 1;\
	fi       

lasttag: #	auxiliary target to check correct command line parameters
	@if test -z "$(LASTTAG)"; then \
	echo '*****************************************************';\
	echo 'usage: make <target> LASTTAG=XXX'; \
	echo 'No last/previous tag given.'; \
	echo 'Changelog is created for changes between TAG and LASTTAG'; \
	echo '.... terminated.'; \
	echo \
	'*****************************************************'; \
	exit 1;\
	fi       

dist: apiis-home changelog docs #		pack a distribution tar file for this tag
	@rm -rf tmp_only_for_dist
	@mkdir tmp_only_for_dist
	@(umask 0022;\
	cd tmp_only_for_dist;\
	cvs -d :pserver:`whoami`@cvs-server.tzv.fal.de:/usr/local/lib/cvsroot \
	     export -r $(TAG) \
	     -d apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'` \
	     apiis;\
	cd apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`;\
	echo "`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`"  > etc/VERSION;\
	cp $(APIIS_HOME)/ChangeLog-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'` doc;\
	cp $(APIIS_HOME)/doc/developer-doc.pdf doc; \
	cp $(APIIS_HOME)/doc/implementer-doc.pdf doc; \
	mkdir var;\
	mkdir var/log;\
	cd ..;\
	tar czvf apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`.tar.gz \
	   apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`/bin/\
	   apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`/contrib/\
	   apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`/etc/\
	   apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`/lib/\
	   apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`/test/\
	   apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`/var/\
	   apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`/index.html\
	   apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`/LICENSE\
	   apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`/CVSTags\
	   apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`/doc/HOWTO/\
	   apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`/doc/INSTALL\
	   apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`/doc/ChangeLog*\
	   apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`/doc/developer-doc.pdf\
	   apiis-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'`/doc/implementer-doc.pdf;\
	mv apiis-*.tar.gz ..;\
	cd ..;\
	rm -rf tmp_only_for_dist)

changelog: tag lasttag #	create the ChangeLog file
	cvs2cl \
	   -f ChangeLog-`echo $(TAG) |sed -e 's/^v//i' -e 's/-/./g'` \
	   -P -W 180 -t --delta $(LASTTAG):$(TAG) \
	   lib bin contrib doc etc

changelog-head: lasttag #create the ChangeLog file for the lasttag against HEAD
	cvs2cl \
	   -f ChangeLog-HEAD -P -W 180 -t --delta $(LASTTAG):HEAD \
	   lib bin contrib doc etc

docs:		#		create the .pdf files in the doc subdirectory
	@(cd doc;\
	make all-doc)

# vim: noexpandtab
