// Browser stand-in for the iOS app's native "downloads" bridge (see WebAppView.swift),
// so "📸 Save results" works on the website too. On phones it opens the share
// sheet ("Save Image" puts it in Photos); elsewhere it downloads the PNG.
(() => {
  if (window.claude && window.claude.use) return;
  const downloads = {
    async save({ filename, data }) {
      const file = new File([data], filename, { type: data.type || 'image/png' });
      if (navigator.canShare && navigator.canShare({ files: [file] })) {
        try {
          await navigator.share({ files: [file] });
        } catch (e) {
          // The page treats code 'declined' as "user said no thanks" and stays quiet.
          if (e && e.name === 'AbortError') { const err = new Error('declined'); err.code = 'declined'; throw err; }
          throw e;
        }
        return;
      }
      const url = URL.createObjectURL(file);
      const link = document.createElement('a');
      link.href = url;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    }
  };
  window.claude = { use: async (name) => (name === 'downloads' ? downloads : null) };
})();
