PROJECT = Libmacgpg
TARGET = Libmacgpg
CONFIG = Release

include Dependencies/GPGTools_Core/make/default

all: compile

update-core:
	@cd Dependencies/GPGTools_Core; git pull origin master; cd -

update-me:
	@git pull

update: update-me update-core

compile:
	xcodebuild -project Libmacgpg.xcodeproj -target "Libmacgpg" -configuration Release build

clean:
	xcodebuild -project Libmacgpg.xcodeproj -target "Libmacgpg" -configuration Release clean

test:
	@echo "Nothing to test"


