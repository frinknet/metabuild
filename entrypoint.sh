#!/bin/bash
set -e
cd /build

cpmaybe() {
	local src="$1"
	local dir="$2"
	local file="${src##*/}"
	local dest="$dir/$file"
	if [[ -f "$dest" ]]; then
		read -p "$dest exists. Overwrite? (y/N): " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			cp "$src" "$dir"
			echo "✓ $dest"
		else
			echo "✗ $dest"
		fi
	else
		cp "$src" "$dir"
		echo "✓ $dest"
	fi
}

case "${1:-}" in
	cli)
		shift
		echo -e "\n\n\e[1;33m  You are now DEEP in the build system... BEWARE OF THE GRUE!!!\e[0m"
		exec bash "$@"
		;;
	init)
		echo "Installing metabuild files..."
		for file in build.sh build.bat; do
			cpmaybe "/metabuild/$file" .
		done
		mkdir -p .metabuild
		for file in /metabuild/*.mk; do
			cpmaybe "$file" .metabuild
		done
		echo "Run 'metabuild' to build your project."
		;;
	extend)
		cpmaybe /metabuild/Makefile .
		;;
	*)
		mkdir -p .metabuild
		cp -n /metabuild/*.mk .metabuild/
		if [[ -f Makefile ]]; then
			exec make "$@"
		else
			exec make -f /metabuild/Makefile "$@"
		fi
		;;
esac

