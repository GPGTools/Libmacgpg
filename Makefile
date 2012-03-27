PROJECT = Libmacgpg
TARGET = Libmacgpg
CONFIG = Release

.PRE :=
ifndef CFG
compile clean:
        $(foreach cfg,$(cfg_list), $(MAKE) CFG=$(cfg) $@;)
.PRE := foo-
endif

include Dependencies/GPGTools_Core/make/default

all: compile

update-core:
	@cd Dependencies/GPGTools_Core; git pull origin master; cd -

update-me:
	@git pull

update: update-me update-core

test:
	@xcodebuild -project $(PROJECT).xcodeproj -scheme Test -configuration $(CONFIG) build

compile:
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) -configuration $(CONFIG) build

clean:
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) -configuration $(CONFIG) clean > /dev/null


