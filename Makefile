SHELL := /bin/bash

.PHONY: help format lint test check build reminders clean

help:
	@printf "%s\n" \
		"make format    - swift format in-place" \
		"make lint      - swift format lint + swiftlint" \
		"make test      - swift test" \
		"make build     - release build into bin/ (codesigned)" \
		"make reminders - clean rebuild + run debug binary (ARGS=...)" \
		"make clean     - swift package clean"

format:
	swift format --in-place --recursive Sources Tests

lint:
	swift format lint --recursive Sources Tests
	swiftlint

test:
	swift test

build:
	mkdir -p bin
	swift build -c release --product reminders
	cp .build/release/reminders bin/reminders
	codesign --force --sign - --identifier com.henrisaksi.reminders bin/reminders

reminders:
	swift package clean
	swift build -c debug --product reminders
	./.build/debug/reminders $(ARGS)

clean:
	swift package clean
