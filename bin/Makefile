#
# TransFig makefile
#

all: languages.xml.pdf 

# translation into pdf

languages.xml.pdf: languages.xml.fig Makefile
	fig2dev -L pdf languages.xml.fig languages.xml.pdf
clean::
	rm -f languages.xml.pdf

