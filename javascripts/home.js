(() => {
  const home = document.querySelector(".alz-home");
  if (!home) return;

  const selectors = new Map();
  home.querySelectorAll("[data-home-tabs]").forEach(group => {
    const tablist = group.querySelector('[role="tablist"]');
    const tabs = [...tablist.querySelectorAll('[role="tab"]')];
    function select(tab) {
      tabs.forEach(item => {
        const active = item === tab;
        item.setAttribute("aria-selected", String(active));
        item.tabIndex = active ? 0 : -1;
        document.getElementById(item.getAttribute("aria-controls")).hidden = !active;
      });
    }
    tabs.forEach(tab => {
      selectors.set(tab.getAttribute("aria-controls"), () => select(tab));
      tab.addEventListener("click", () => select(tab));
      tab.addEventListener("keydown", event => {
        let index = tabs.indexOf(tab);
        if (event.key === "ArrowRight") index = (index + 1) % tabs.length;
        else if (event.key === "ArrowLeft") index = (index + tabs.length - 1) % tabs.length;
        else if (event.key === "Home") index = 0;
        else if (event.key === "End") index = tabs.length - 1;
        else return;
        event.preventDefault();
        select(tabs[index]);
        tabs[index].focus();
      });
    });
    select(tabs[0]);
    tablist.hidden = false;
    group.setAttribute("data-home-enhanced", "");
  });

  function revealAnchor() {
    const target = document.getElementById(location.hash.slice(1));
    if (!target || !home.contains(target)) return;
    let revealed = false;
    const panel = target.closest('[role="tabpanel"]');
    if (panel?.hidden) {
      selectors.get(panel.id)();
      revealed = true;
    }
    for (let parent = target.parentElement; parent && parent !== home; parent = parent.parentElement) {
      if (parent.tagName === "DETAILS" && !parent.open) {
        parent.open = true;
        revealed = true;
      }
    }
    const destination = target.matches(".home-panel-title") ? panel : target;
    if (revealed || destination !== target) {
      requestAnimationFrame(() => destination.scrollIntoView({ block: "start" }));
    }
  }
  window.addEventListener("hashchange", revealAnchor);
  home.addEventListener("click", event => {
    const link = event.target.closest("a");
    if (link?.hash === location.hash) revealAnchor();
  });
  revealAnchor();
})();
