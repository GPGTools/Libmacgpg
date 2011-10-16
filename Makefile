all: compile
update-me:
	@git pull

update: update-me

compile:
	xcodebuild -project Libmacgpg.xcodeproj -target "Libmacgpg" -configuration Release build

clean:
	xcodebuild -project Libmacgpg.xcodeproj -target "Libmacgpg" -configuration Release clean
