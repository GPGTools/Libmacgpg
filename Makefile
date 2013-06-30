PROJECT = Libmacgpg
TARGET = Libmacgpg
PRODUCT = Libmacgpg.framework
TEST_TARGET = UnitTest
MAKE_DEFAULT = Dependencies/GPGTools_Core/newBuildSystem/Makefile.default

-include $(MAKE_DEFAULT)

$(MAKE_DEFAULT):
	@bash -c "$$(curl -fsSL https://raw.github.com/GPGTools/GPGTools_Core/master/newBuildSystem/prepare-core.sh)"

init: $(MAKE_DEFAULT)


update-pinentry:
	$(MAKE) -C Dependencies/pinentry-mac update

update: update-pinentry

clean-pinentry:
	$(MAKE) -C Dependencies/pinentry-mac clean #change to clean-all when pinentry is updated.

clean-all: clean-pinentry

$(PRODUCT): Source/* Resources/* Resources/*/* Libmacgpg.xcodeproj
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) -configuration $(CONFIG) build $(XCCONFIG)

install: $(PRODUCT)
	@echo Installing Libmacgpg...
	@[[ $$UID -eq 0 ]] || ( echo "This command needs to be run as root!"; exit 1 )
	@rsync -rltD build/Release/$(PRODUCT) /Library/Frameworks/
	@mkdir -p "/Library/Application Support/GPGTools"
	@cp build/Release/org.gpgtools.Libmacgpg.xpc "/Library/Application Support/GPGTools/"
	@cp build/org.gpgtools.Libmacgpg.xpc.plist "/Library/LaunchAgents/"
	@sudo -u "#$$SUDO_UID" launchctl remove org.gpgtools.Libmacgpg.xpc 2>/dev/null || true
	@sudo -u "#$$SUDO_UID" launchctl load /Library/LaunchAgents/org.gpgtools.Libmacgpg.xpc.plist
	@echo Done

