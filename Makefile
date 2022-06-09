all: build

.PHONY: build
	
build:
	ENABLE_GIT=1 ENABLE_SSH=1 flutter build linux -v
