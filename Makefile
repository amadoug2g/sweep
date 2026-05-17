.PHONY: dev build test clean app dmg

APP_NAME = Sweep

dev:
	swift run SweepMain

build:
	swift build -c release

test:
	swift test

# Full .app bundle + DMG packaging wired up once Info.plist and signing are ready
app:
	@echo "App bundle packaging coming in a follow-up PR. Use 'make build' for now."

dmg: app

clean:
	swift package clean
	rm -rf dist
