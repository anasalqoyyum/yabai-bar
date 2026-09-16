.PHONY: build test icon app dmg release clean

build:
	swift build

test:
	swift test

icon:
	./scripts/build-icon.sh

app: icon
	./scripts/package-app.sh

dmg: icon
	./scripts/package-dmg.sh

release:
	./scripts/release.sh

clean:
	swift package clean
	rm -rf "$(CURDIR)/dist/YabaiBar.app"
