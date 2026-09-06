.PHONY: build test app run clean

build: app

test:
	swift test

app:
	./scripts/build-app.sh

run: app
	open .build/UsageHarness.app

clean:
	rm -rf .build
