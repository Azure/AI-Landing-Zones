(() => {
  const home = document.querySelector(".alz-home");
  if (!home) return;

  const viewer = home.querySelector(".home-diagram-viewer");
  const viewport = viewer.querySelector(".home-diagram-viewport");
  const enlarged = viewer.querySelector(".home-diagram-image");
  const imageError = viewer.querySelector(".home-diagram-error");
  const zoomIn = viewer.querySelector("[data-diagram-in]");
  const zoomOut = viewer.querySelector("[data-diagram-out]");
  let sourceImage;
  let zoom = 2;
  function sizeDiagram() {
    const width = sourceImage.naturalWidth || Number(sourceImage.getAttribute("width"));
    const height = sourceImage.naturalHeight || Number(sourceImage.getAttribute("height"));
    const fitWidth = Math.min(viewport.clientWidth, viewport.clientHeight * width / height);
    const maximum = Math.max(1, width / fitWidth);
    zoom = Math.max(1, Math.min(zoom, maximum));
    enlarged.style.width = `${Math.floor(fitWidth * zoom)}px`;
    zoomOut.disabled = zoom <= 1;
    zoomIn.disabled = zoom >= maximum;
  }
  function openDiagram(image) {
    sourceImage = image;
    zoom = 2;
    imageError.hidden = true;
    enlarged.hidden = false;
    enlarged.src = image.currentSrc || image.src;
    enlarged.alt = image.alt;
    viewer.querySelector("#home-diagram-title").textContent =
      document.getElementById(image.closest('[role="tabpanel"]').getAttribute("aria-labelledby")).textContent + " architecture";
    viewer.querySelector("[data-diagram-original]").href = enlarged.src;
    viewer.showModal();
    document.documentElement.classList.add("home-diagram-visible");
    sizeDiagram();
    viewport.scrollTo(0, 0);
  }
  home.querySelectorAll(".architecture-figure").forEach(figure => {
    const image = figure.querySelector("img");
    const trigger = document.createElement("button");
    trigger.type = "button";
    trigger.className = "home-diagram-trigger";
    trigger.setAttribute("aria-label", `Enlarge ${image.alt}`);
    trigger.setAttribute("aria-haspopup", "dialog");
    image.replaceWith(trigger);
    trigger.append(image);
    trigger.addEventListener("click", () => openDiagram(image));
    figure.querySelector("figcaption a").addEventListener("click", event => {
      if (event.button || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      openDiagram(image);
    });
  });
  zoomIn.addEventListener("click", () => { zoom *= 1.5; sizeDiagram(); });
  zoomOut.addEventListener("click", () => { zoom /= 1.5; sizeDiagram(); });
  viewer.querySelector("[data-diagram-fit]").addEventListener("click", () => {
    zoom = 1;
    sizeDiagram();
    viewport.scrollTo(0, 0);
  });
  viewer.querySelector("[data-diagram-close]").addEventListener("click", () => viewer.close());
  viewer.addEventListener("close", () => document.documentElement.classList.remove("home-diagram-visible"));
  viewer.addEventListener("click", event => {
    if (event.target !== viewer) return;
    const bounds = viewer.getBoundingClientRect();
    if (event.clientX < bounds.left || event.clientX > bounds.right ||
        event.clientY < bounds.top || event.clientY > bounds.bottom) viewer.close();
  });
  enlarged.addEventListener("error", () => {
    imageError.hidden = false;
    enlarged.hidden = true;
  });
  window.addEventListener("resize", () => { if (viewer.open) sizeDiagram(); });

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
