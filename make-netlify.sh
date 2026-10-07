#!/bin/zsh
# Builds the Netlify/ folder (generated, not in git): a website copy of the app
# plus the files in Website/.
#   ./make-netlify.sh            build only (then drag the folder onto Netlify)
#   ./make-netlify.sh --deploy   build and publish to creekgolfgames.netlify.app
# Run again after changing the app's index.html.
set -e
cd "${0:A:h}"

src="Creek Golf Games"
out="Netlify"
# The creekgolfgames site on Netlify.
site_id="553c1809-a41d-40e7-b20d-1d2a3846e665"

rm -rf "$out"
mkdir -p "$out"

cp "$src"/WebApp/* "$out"/
# Website-only files: the browser bridge and the privacy policy page.
cp Website/* "$out"/
# Load the browser bridge before the page's own scripts.
sed 's|<meta charset="UTF-8">|<meta charset="UTF-8">\
<script src="web-bridge.js"></script>|' "$src/index.html" > "$out/index.html"

echo "Built $out/"

if [[ "$1" == "--deploy" ]]; then
  # Netlify CLI installed in the home folder (npm install -g --prefix ~/.local netlify-cli).
  "$HOME/.local/bin/netlify" deploy --prod --dir "$out" --site "$site_id" --message "Update from make-netlify.sh"
else
  echo "Publish with: ./make-netlify.sh --deploy   (or drag the folder onto Netlify)"
fi
