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

# The app manifest and home-screen icon (website only).
sed -i '' 's|<meta charset="UTF-8">|<meta charset="UTF-8">\
<link rel="manifest" href="manifest.webmanifest">\
<link rel="apple-touch-icon" sizes="180x180" href="apple-touch-icon.png">|' "$out/index.html"
# Offline copy (sw.js): a new version name and the list of files to save on the
# phone, so each publish replaces the copy saved by the last one.
files=$(cd "$out" && ls -1 | grep -v -e '^sw\.js$' -e '^_' | python3 -c 'import json,sys; print(json.dumps(["./"] + [l.strip() for l in sys.stdin if l.strip()]))')
version=$(date +%Y%m%d%H%M%S)
python3 - "$out/sw.js" "$version" "$files" <<'END'
import sys
p, version, files = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding='utf-8').read().replace("'__VERSION__'", repr(version)).replace('__FILES__', files)
open(p, 'w', encoding='utf-8').write(s)
END

echo "Built $out/"

if [[ "$1" == "--deploy" ]]; then
  # Netlify CLI installed in the home folder (npm install -g --prefix ~/.local netlify-cli).
  "$HOME/.local/bin/netlify" deploy --prod --dir "$out" --site "$site_id" --message "Update from make-netlify.sh"
else
  echo "Publish with: ./make-netlify.sh --deploy   (or drag the folder onto Netlify)"
fi
