#!/bin/sh
REPO="ghcr.io/frinknet/metabuild"
IMAGE="${REPO##*/}"
PREFIX="${HOME}/bin"
VER="${1:-latest}"

# Is prefix in path
mkdir -p "$PREFIX"
case ":$PATH:" in
  "$PREFIX":*) ;;
  *:"$PREFIX":*) ;;
  *:"$PREFIX") ;;
  *) echo "export PATH=\"$PREFIX:\$PATH\"" >> "$HOME/.bashrc"; . "$HOME/.bashrc";;
esac

# Pull the container
if ! docker pull "$REPO:$VER"; then
  echo "could not pull docker container $REPO:$VER"

  exit 1
fi

# Tag image
docker tag "$REPO:$VER" "$IMAGE"

# Create a shell wrapper
cat > "$PREFIX/$IMAGE" <<EOF
#!/bin/sh
if [ "\$1" = "update" ]; then
  exec curl -L https://github.com/${REPO#*/}/raw/main/install.sh | sh -s -- $VER
else
  exec docker run --rm -it -u $(id -u):$(id -g) -v "\$(pwd):/build" $IMAGE "\$@"
fi
EOF

# Make executable
chmod +x "$PREFIX/$IMAGE"

# Report what you did
echo
echo "✓ installed: $PREFIX/$IMAGE"
echo
echo "Run 'metabuild init' to get started."
echo
