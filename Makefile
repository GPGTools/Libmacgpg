PROJECT = Libmacgpg
TARGET = Libmacgpg
PRODUCT = Libmacgpg.framework
TEST_TARGET = UnitTest


include Dependencies/GPGTools_Core/newBuildSystem/Makefile.default


update-pinentry:
	$(MAKE) -C Dependencies/pinentry-mac update

update: update-pinentry

clean-pinentry:
	$(MAKE) -C Dependencies/pinentry-mac clean #change to clean-all when pinentry is updated.

clean-all: clean-pinentry

$(PRODUCT): Source/* Resources/* Resources/*/* Libmacgpg.xcodeproj
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) -configuration $(CONFIG) build $(XCCONFIG)
