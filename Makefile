# Topo · atajos de desarrollo
#
#   make            compila en release y arma dist/Topo.app
#   make icon       regenera Assets/AppIcon.icns
#   make run        abre la app
#   make test       swift build + --selftest
#   make pkg        instalador .pkg (app + comando topo)
#   make install    instala en /Applications y /usr/local/bin
#   make clean      borra .build y dist

SHELL := /bin/bash
APP := Topo
CLI := topo
DIST := dist/$(APP).app
VERSION := 0.1.0

.PHONY: all build app icon run test pkg install clean help

all: app

build:
	@swift build

app:
	@./Scripts/bundle.sh release

icon:
	@./Scripts/build-icon.sh

run: app
	@open "$(DIST)"

test: build
	@swift run -c debug Topo --selftest

pkg: app
	@./Scripts/build-pkg.sh

install: app
	@./Scripts/install.sh

clean:
	@rm -rf .build dist
	@echo "▸ limpio"

help:
	@echo "Topo $(VERSION)"
	@echo ""
	@echo "  make            compila y arma $(DIST)"
	@echo "  make icon       regenera el icono (.icns)"
	@echo "  make run        compila y abre la app"
	@echo "  make test       compila y ejecuta --selftest"
	@echo "  make pkg        genera dist/$(CLI)-$(VERSION).pkg"
	@echo "  make install    instala app + comando en el sistema"
	@echo "  make clean      borra .build y dist"
