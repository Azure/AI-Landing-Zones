(() => {
  const article = document.querySelector("article.md-content__inner");
  if (!article || !location.pathname.split("/").includes("agent-landing-zone") ||
      typeof HTMLDialogElement === "undefined" || !HTMLDialogElement.prototype.showModal) return;

  const images = [...article.querySelectorAll("img")].filter(image =>
    /\/(?:media\/runbooks\/[^/]+\.(?:svg|png)|media\/agent-application-overview\.svg|architecture\/media\/AI-Landing-Zone-without-platform\.png)$/
      .test(new URL(image.src).pathname));
  if (!images.length) return;

  const icon = path => `<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="${path}"/></svg>`;
  const expand = icon("M8 3H3v5M16 3h5v5M21 16v5h-5M8 21H3v-5");
  const viewer = document.createElement("dialog");
  viewer.id = "alz-diagram-viewer";
  viewer.className = "alz-diagram-viewer";
  viewer.setAttribute("aria-labelledby", "alz-diagram-title");
  viewer.setAttribute("aria-describedby", "alz-diagram-help");
  viewer.innerHTML = `
    <header class="alz-diagram-viewer__toolbar">
      <h2 id="alz-diagram-title"></h2>
      <div class="alz-diagram-viewer__controls">
        <button type="button" data-zoom-out aria-label="Zoom out">${icon("M5 12h14")}</button>
        <output aria-label="Zoom relative to fit">100%</output>
        <button type="button" data-zoom-in aria-label="Zoom in">${icon("M5 12h14M12 5v14")}</button>
        <button type="button" data-fit aria-label="Fit diagram">${expand}</button>
        <a data-original target="_blank" rel="noopener" aria-label="Open image in new tab">${icon("M14 3h7v7M21 3l-9 9M10 3H3v18h18v-7")}</a>
        <button type="button" data-close aria-label="Close diagram" autofocus>${icon("M6 6l12 12M18 6L6 18")}</button>
      </div>
    </header>
    <p id="alz-diagram-help">Use the zoom controls, scroll or drag to explore. Press Esc to close.</p>
    <p class="alz-diagram-viewer__status" role="status" hidden></p>
    <div class="alz-diagram-viewer__viewport" tabindex="0" aria-label="Enlarged diagram">
      <img alt="" draggable="false" hidden>
    </div>`;
  document.body.append(viewer);

  const viewport = viewer.querySelector(".alz-diagram-viewer__viewport");
  const enlarged = viewport.querySelector("img");
  const status = viewer.querySelector(".alz-diagram-viewer__status");
  const zoomIn = viewer.querySelector("[data-zoom-in]");
  const zoomOut = viewer.querySelector("[data-zoom-out]");
  const fit = viewer.querySelector("[data-fit]");
  const original = viewer.querySelector("[data-original]");
  let zoom = 1;
  let loaded = false;
  let opener;
  let vector = false;
  let scrollPosition = 0;
  let drag;

  function sizeDiagram() {
    if (!loaded || !viewer.open) return;
    // Scrollbars change client dimensions while zooming, not the viewport frame.
    const fitWidth = Math.min(viewport.offsetWidth - 32,
      (viewport.offsetHeight - 32) * enlarged.naturalWidth / enlarged.naturalHeight);
    const maximum = vector ? 8 : Math.max(1, enlarged.naturalWidth / fitWidth);
    zoom = Math.max(1, Math.min(zoom, maximum));
    enlarged.style.width = `${Math.floor(fitWidth * zoom)}px`;
    viewer.querySelector("output").value = `${Math.round(zoom * 100)}%`;
    zoomIn.disabled = zoom >= maximum;
    zoomOut.disabled = zoom <= 1;
    fit.disabled = zoom <= 1;
  }

  function openDiagram(source, trigger, alt, isVector) {
    opener = trigger;
    scrollPosition = window.scrollY;
    vector = isVector;
    zoom = 1;
    loaded = false;
    enlarged.hidden = true;
    status.hidden = false;
    status.setAttribute("role", "status");
    status.textContent = "Loading diagram...";
    viewport.setAttribute("aria-busy", "true");
    zoomIn.disabled = zoomOut.disabled = fit.disabled = true;
    viewer.querySelector("output").value = "100%";
    viewer.querySelector("h2").textContent = article.querySelector("h1").textContent.trim();
    original.href = source;
    enlarged.alt = alt;
    viewer.showModal();
    enlarged.src = source;
    viewport.scrollTo(0, 0);
  }

  enlarged.addEventListener("load", () => {
    if (!viewer.open) return;
    loaded = true;
    enlarged.hidden = false;
    status.hidden = true;
    viewport.setAttribute("aria-busy", "false");
    sizeDiagram();
  });
  enlarged.addEventListener("error", () => {
    if (!viewer.open) return;
    loaded = false;
    enlarged.hidden = true;
    status.hidden = false;
    status.setAttribute("role", "alert");
    status.textContent = "The diagram could not load. Use Open image in new tab to open it directly.";
    viewport.setAttribute("aria-busy", "false");
    zoomIn.disabled = zoomOut.disabled = fit.disabled = true;
  });
  zoomIn.addEventListener("click", () => { zoom *= 1.5; sizeDiagram(); });
  zoomOut.addEventListener("click", () => { zoom /= 1.5; sizeDiagram(); });
  fit.addEventListener("click", () => { zoom = 1; sizeDiagram(); viewport.scrollTo(0, 0); });
  viewer.querySelector("[data-close]").addEventListener("click", () => viewer.close());
  viewer.addEventListener("keydown", event => {
    if (event.key !== "Tab") return;
    const controls = [...viewer.querySelectorAll('button:not(:disabled), a[href], [tabindex="0"]')];
    const destination = event.shiftKey ? controls.at(-1) : controls[0];
    if (document.activeElement === (event.shiftKey ? controls[0] : controls.at(-1))) {
      event.preventDefault();
      destination.focus();
    }
  });
  viewer.addEventListener("click", event => {
    if (event.target !== viewer) return;
    const bounds = viewer.getBoundingClientRect();
    if (event.clientX < bounds.left || event.clientX > bounds.right ||
        event.clientY < bounds.top || event.clientY > bounds.bottom) viewer.close();
  });
  viewer.addEventListener("close", () => {
    drag = undefined;
    viewport.classList.remove("is-dragging");
    enlarged.removeAttribute("src");
    opener.focus({ preventScroll: true });
    window.scrollTo(0, scrollPosition);
  });
  viewport.addEventListener("pointerdown", event => {
    if (event.pointerType !== "mouse" || event.button || zoom <= 1) return;
    viewport.setPointerCapture(event.pointerId);
    drag = { x: event.clientX, y: event.clientY, left: viewport.scrollLeft, top: viewport.scrollTop };
    viewport.classList.add("is-dragging");
  });
  viewport.addEventListener("pointermove", event => {
    if (drag) viewport.scrollTo(drag.left + drag.x - event.clientX, drag.top + drag.y - event.clientY);
  });
  for (const event of ["pointerup", "pointercancel"]) {
    viewport.addEventListener(event, () => {
      drag = undefined;
      viewport.classList.remove("is-dragging");
    });
  }
  window.addEventListener("resize", sizeDiagram);

  function figureFor(source) {
    let figure = source.closest(".runbook-diagram");
    if (!figure) {
      figure = document.createElement("figure");
      const content = source.closest("p") || source;
      content.replaceWith(figure);
      figure.append(content);
    }
    figure.classList.add("alz-diagram");
    const toolbar = document.createElement("div");
    toolbar.className = "alz-diagram__toolbar";
    figure.append(toolbar);
    return { figure, toolbar };
  }

  function expandControl() {
    const control = document.createElement("a");
    control.className = "alz-diagram__expand";
    control.setAttribute("aria-label", "Expand diagram");
    control.setAttribute("aria-haspopup", "dialog");
    control.setAttribute("aria-controls", viewer.id);
    control.innerHTML = expand;
    return control;
  }

  // Keep the original source links as a working no-JavaScript fallback.
  images.forEach(image => {
    const { toolbar } = figureFor(image);
    const control = expandControl();
    control.href = image.src;
    toolbar.append(control);
    const open = event => {
      if (event.button || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      openDiagram(image.currentSrc || image.src, control, image.alt, /\.svg$/.test(new URL(image.src).pathname));
    };
    control.addEventListener("click", open);
    let imageLink = image.closest("a");
    if (!imageLink) {
      imageLink = document.createElement("a");
      imageLink.href = image.src;
      image.replaceWith(imageLink);
      imageLink.append(image);
    }
    imageLink.tabIndex = -1;
    imageLink.addEventListener("click", open);
    for (const link of article.querySelectorAll("a[href]")) {
      if (link === control || link === imageLink || link.href !== image.src ||
          !/^(?:open .*diagram|enlarge .*diagram)$/i.test(link.textContent.trim())) continue;
      const parent = link.parentElement;
      if (parent.tagName === "P" && parent.children.length === 1) parent.remove();
      else link.remove();
    }
  });

})();
