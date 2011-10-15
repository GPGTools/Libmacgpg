all: compile

compile:
	xcodebuild -project Libmacgpg.xcodeproj -target "Libmacgpg" -configuration Release build

clean:
	xcodebuild -project Libmacgpg.xcodeproj -target "Libmacgpg" -configuration Release clean


