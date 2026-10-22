.PHONY: help render build clean distclean

help:
	@echo "make render     只渲染 overlay（不编译，秒出）"
	@echo "make build      完整编译固件（需 Linux / WSL）"
	@echo "make clean      清掉渲染产物"
	@echo "make distclean  连源码树一起删（下次重新 clone）"

render:
	@sh scripts/render-files.sh

build:
	@sh build.sh

clean:
	@rm -rf build

distclean: clean
	@rm -rf .src
