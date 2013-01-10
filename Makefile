PROJECT = Libmacgpg
TARGET = Libmacgpg
CONFIG = Release
TEST_TARGET = UnitTest


include Dependencies/GPGTools_Core/newBuildSystem/Makefile.default


update-pinentry:
	$(MAKE) -C Dependencies/pinentry-mac update

update: update-pinentry

clean-all::
	$(MAKE) -C Dependencies/pinentry-mac clean #change to clean-all when pinentry is updated.

