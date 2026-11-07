// Helium's new tab: the hour in the section line, to the minute (tools/build-themes.py writes this)
const t = document.getElementById("t");
const tick = () => {
  const d = new Date();
  t.textContent = d.toLocaleDateString("en-GB", {weekday: "short", day: "numeric", month: "short"}).toLowerCase()
    + "  " + d.toTimeString().slice(0, 5);
  setTimeout(tick, 60000 - d.getSeconds() * 1000 - d.getMilliseconds());
};
tick();
