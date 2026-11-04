// ~/.local/share/fedokawaii/browser — the one thing only the browser knows: how big a download will
// be (its files say how much has come; its History holds no row while one runs: measured). Told to
// kawa-downloads as each download gets its name and its size (kawa-browser loads this extension, and
// names kawa-downloads as its native messaging host).
const tell = (d) => chrome.runtime.sendNativeMessage("fedokawaii.downloads", { file: d.filename, total: d.totalBytes }, () => void chrome.runtime.lastError);
chrome.downloads.onCreated.addListener((d) => { if (d.filename) tell(d); });
chrome.downloads.onChanged.addListener((c) => {
  if (c.filename || c.totalBytes) chrome.downloads.search({ id: c.id }, ([d]) => { if (d && d.filename) tell(d); });
});
