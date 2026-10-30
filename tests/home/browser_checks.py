"""Verify the approved homepage inside the built MkDocs site."""

import argparse
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import re
import threading

from playwright.sync_api import expect, sync_playwright


ROOT = Path(__file__).resolve().parents[2]
LEGACY_ANCHORS = (
    "ai-landing-zones", "architecture", "implementation", "workloads",
    "use-cases-scenarios", "use-cases", "reference-architectures",
    "agent-landing-zone", "standalone", "with-platform-hub",
    "ai-gateway-landing-zone", "foundry-modules", "agent-landing-zone_1",
    "ai-gateway-landing-zone_1", "extensible-implementations", "whats-new",
    "frequently-asked-questions", "design-checklist", "design-areas",
    "design-and-resources", "cloud-adoption-framework", "well-architected-framework",
    "roadmap", "contributing", "trademarks",
)


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass


def check_application_navigation(page, base, screenshots):
    labels = (
        "Agent Application", "Chat & channels", "Knowledge & retrieval",
        "Document ingestion", "Development & customization",
    )
    for width in (1880, 1440, 1280):
        page.set_viewport_size({"width": width, "height": 1000})
        for path in ("", "agent-landing-zone/application/"):
            page.goto(base + path)
            sidebar = page.locator(".md-sidebar--primary")
            expect(sidebar).to_be_visible()
            nav = sidebar.locator(".md-nav--primary")
            for name in ("Agent Landing Zone", "Agent Application"):
                label = nav.locator("label.md-nav__link").filter(
                    has_text=re.compile(r"^\s*" + re.escape(name) + r"\s*$")
                )
                toggle = page.locator("#" + label.get_attribute("for"))
                if not toggle.is_checked():
                    label.click()
            for name in labels:
                link = nav.locator(".md-nav__link:visible").filter(
                    has_text=re.compile(r"^\s*" + re.escape(name) + r"\s*$")
                )
                text = link.locator(":scope > .md-ellipsis")
                metrics = text.evaluate("""element => {
                    const style = getComputedStyle(element);
                    return {
                        height: element.getBoundingClientRect().height,
                        lineHeight: parseFloat(style.lineHeight),
                        fontSize: parseFloat(style.fontSize),
                        overflow: element.scrollWidth > element.clientWidth
                    };
                }""")
                assert metrics["height"] <= metrics["lineHeight"] + 1, (width, path, name, metrics)
                assert metrics["fontSize"] >= 14 and not metrics["overflow"], (width, path, name, metrics)
            assert page.evaluate("document.documentElement.scrollWidth <= document.documentElement.clientWidth"), (width, path)
            if screenshots and width == 1280:
                name = "navigation-application-desktop.png" if path else "navigation-home-desktop.png"
                page.screenshot(path=str(screenshots / name))


def check_prose_wrapping(page, base, screenshots):
    for width in (1880, 1440, 1280, 1024, 768, 390, 320):
        for text_scale in (1, 1.25):
            page.set_viewport_size({"width": width, "height": 1000})
            page.goto(base + "agent-landing-zone/")
            if text_scale != 1:
                page.evaluate("""scale => {
                    const root = document.documentElement;
                    root.style.fontSize = `${parseFloat(getComputedStyle(root).fontSize) * scale}px`;
                }""", text_scale)
            page.evaluate("document.fonts.ready")
            content = page.locator(".md-content__inner")
            targets = [
                content.locator(":scope > p").filter(has_text="The default full-stack deployment"),
                content.locator(":scope > p").filter(has_text="The planning and Agent Application"),
                *content.locator(":scope > ul > li").all(),
            ]
            assert len(targets) == 7
            for target in targets:
                metrics = target.evaluate(r"""element => {
                    const words = [];
                    const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
                    while (walker.nextNode()) {
                        const node = walker.currentNode;
                        for (const match of node.textContent.matchAll(/\S+/g)) {
                            if (!/[\p{L}\p{N}]/u.test(match[0])) continue;
                            const range = document.createRange();
                            range.setStart(node, match.index);
                            range.setEnd(node, match.index + match[0].length);
                            const rect = range.getBoundingClientRect();
                            if (rect.height) words.push({word: match[0], top: Math.round(rect.top)});
                        }
                    }
                    const lastTop = Math.max(...words.map(word => word.top));
                    return {
                        lastLine: words.filter(word => word.top === lastTop).map(word => word.word),
                        lines: new Set(words.map(word => word.top)).size,
                        fontSize: parseFloat(getComputedStyle(element).fontSize),
                        overflow: element.scrollWidth > element.clientWidth
                    };
                }""")
                assert metrics["lines"] == 1 or len(metrics["lastLine"]) >= 2, (
                    width, text_scale, target.inner_text(), metrics
                )
                assert metrics["fontSize"] >= 16 and not metrics["overflow"], (width, text_scale, metrics)
            assert page.evaluate("document.documentElement.scrollWidth <= document.documentElement.clientWidth"), (
                width, text_scale
            )
            if screenshots and text_scale == 1 and width in (1280, 390):
                targets[0].evaluate("element => window.scrollTo(0, element.getBoundingClientRect().top + window.scrollY - 80)")
                name = "prose-desktop.png" if width == 1280 else "prose-mobile.png"
                page.screenshot(path=str(screenshots / name))


def run(base, screenshots):
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(ignore_default_args=["--hide-scrollbars"])
        page = browser.new_page(viewport={"width": 1440, "height": 1000})
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(base)
        page.locator("[data-home-enhanced]").first.wait_for()
        if screenshots:
            screenshots.mkdir(parents=True, exist_ok=True)
            page.screenshot(path=str(screenshots / "home-desktop.png"))
            page.locator(".guidance-layout").screenshot(path=str(screenshots / "home-guidance.png"))
            page.set_viewport_size({"width": 390, "height": 950})
            page.goto(base)
            page.screenshot(path=str(screenshots / "home-mobile.png"))
            page.set_viewport_size({"width": 1440, "height": 1000})
            page.goto(base)
        expect(page.locator(".hero h1")).to_have_text("Build AI.On solid ground.")
        expect(page.locator(".home-button--primary")).to_have_text("Deploy AI Landing Zone")
        assert "not a blank page" not in page.locator(".hero").inner_text()
        assert not page.locator(".alz-home a[href$='.md']").count()
        assert page.locator(".alz-home img:not(.home-diagram-image)").count() == 7
        assert page.locator(".implementation-table tbody a").count() == 8
        card_links = (
            (
                ("Documentation", "agent-landing-zone/"),
                ("GitHub repository", "https://github.com/Azure/agent-landing-zone"),
            ),
            (
                ("Documentation", "ai-gateway-landing-zone/"),
                ("GitHub (Bicep)", "https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator"),
                ("GitHub (Terraform)", "https://github.com/Azure/terraform-ai-gateway-landing-zone"),
            ),
        )
        for index, links in enumerate(card_links):
            card = page.locator(".paths .path").nth(index)
            expect(card.locator(".text-link")).to_have_count(len(links))
            for label, href in links:
                expect(card.get_by_role("link", name=label, exact=True)).to_have_attribute("href", href)
        assert page.locator(".resources a").count() == 3
        assert page.locator(".resources strong").count() == 3
        assert ":octicons-" not in page.locator(".alz-home").inner_text()
        ids = page.locator(".alz-home [id]").evaluate_all("(elements) => elements.map(element => element.id)")
        assert len(ids) == len(set(ids)), "Duplicate homepage anchor IDs"
        for anchor in LEGACY_ANCHORS:
            assert page.locator(f'[id="{anchor}"]').count() == 1, anchor
        for width in (1880, 1440, 1280, 1024, 768, 390, 320):
            page.set_viewport_size({"width": width, "height": 1000})
            assert page.evaluate("document.documentElement.scrollWidth <= document.documentElement.clientWidth"), width
            assert page.locator(".md-sidebar--secondary").is_hidden()
            assert page.locator(".home-mobile-contents").count() == 0
            short_copy = page.locator(
                ".hero > p, .section > p, .path > p, .use-case > p, "
                ".guidance-layout header > p, .resources > p"
            )
            for paragraph in short_copy.all():
                assert paragraph.evaluate("""element => {
                    const parent = element.parentElement;
                    const style = getComputedStyle(parent);
                    let available = parent.clientWidth -
                        parseFloat(style.paddingLeft) - parseFloat(style.paddingRight);
                    if (parent.matches(".use-case")) {
                        available = parseFloat(style.gridTemplateColumns.split(" ").at(-1));
                    }
                    return Math.abs(element.getBoundingClientRect().width - available) < 2;
                }
                """), (width, paragraph.inner_text())
            assert page.locator(
                ".alz-home .home-disclosure > p"
            ).evaluate_all("""elements => elements.length > 0 && elements.every(element =>
                getComputedStyle(element).maxWidth !== "none")
            """), width
            for index, links in enumerate(card_links):
                card = page.locator(".paths .path").nth(index)
                bounds = card.bounding_box()
                for label, _ in links:
                    link = card.get_by_role("link", name=label, exact=True)
                    expect(link).to_be_visible()
                    link_bounds = link.bounding_box()
                    assert link_bounds["x"] >= bounds["x"] - 1, (width, label)
                    assert link_bounds["x"] + link_bounds["width"] <= bounds["x"] + bounds["width"] + 1, (width, label)
            for name in ("standalone", "hub", "gateway"):
                page.locator(f"#tab-{name}").click()
                expect(page.locator(f"#architecture-{name}")).to_be_visible()
                assert page.locator(".architecture-panel:visible").count() == 1
                assert not page.locator(f"#architecture-{name} details").count()
                assert page.locator(f"#architecture-{name} img").is_visible()
                panel = page.locator(f"#architecture-{name}").bounding_box()
                description = page.locator(f"#architecture-{name} > p")
                assert abs(description.bounding_box()["width"] - panel["width"]) < 2, (width, name)
                assert description.evaluate("element => element.scrollWidth <= element.clientWidth"), (width, name)
                if width >= 1440 and name in ("standalone", "hub"):
                    lines = description.evaluate("""element => {
                        const range = document.createRange();
                        range.selectNodeContents(element);
                        return range.getClientRects().length;
                    }""")
                    assert lines == 1, (width, name, lines)
                diagram = page.locator(f"#architecture-{name} img").bounding_box()
                assert abs(diagram["width"] - panel["width"]) < 2, (width, name, diagram, panel)
                caption = page.locator(f"#architecture-{name} figcaption")
                assert caption.evaluate("""element => {
                    const style = getComputedStyle(element);
                    return style.textAlign === "left" && style.fontSize === "14px";
                }"""), (width, name)
                for paragraph in caption.locator("p").all():
                    bounds = paragraph.bounding_box()
                    assert abs(bounds["width"] - diagram["width"]) < 2, (width, name)
                    assert abs(bounds["x"] - diagram["x"]) < 2, (width, name)
                    assert paragraph.evaluate(
                        'element => getComputedStyle(element).textAlign === "left"'
                    ), (width, name)
            if width <= 560:
                heading = page.locator(".implementation-table tbody th").first.bounding_box()
                table = page.locator(".implementation-table").bounding_box()
                assert abs(heading["width"] - table["width"]) < 2, width
        viewer = page.locator(".home-diagram-viewer")
        enlarged = viewer.locator(".home-diagram-image")
        for width, names in ((1440, ("standalone", "hub", "gateway")),
                             (390, ("standalone",)), (320, ("gateway",))):
            page.set_viewport_size({"width": width, "height": 1000})
            for name in names:
                page.locator(f"#tab-{name}").click()
                trigger = page.locator(f"#architecture-{name} .home-diagram-trigger")
                if screenshots and name == "standalone":
                    page.locator(".architecture-workbench").screenshot(
                        path=str(screenshots / f"home-architecture-{width}.png"))
                trigger.focus()
                original_overflow = page.locator("html").evaluate("element => getComputedStyle(element).overflow")
                trigger.press("Enter")
                expect(viewer).to_be_visible()
                assert page.locator("html").evaluate("element => getComputedStyle(element).overflow") == "hidden"
                expect(viewer.get_by_role("button", name="Close", exact=True)).to_be_focused()
                page.wait_for_function("""() => {
                    const image = document.querySelector(".home-diagram-image");
                    return image.complete && image.naturalWidth === 6400;
                }""")
                assert enlarged.bounding_box()["width"] > trigger.bounding_box()["width"]
                expect(viewer.get_by_role("link", name="Open original")).to_have_attribute(
                    "href", page.locator(f"#architecture-{name} img").evaluate("image => image.currentSrc || image.src"))
                if screenshots and width == 1440 and name == "standalone":
                    page.screenshot(path=str(screenshots / "home-architecture-expanded.png"))
                page.keyboard.press("Tab")
                assert viewer.evaluate("element => element.contains(document.activeElement)")
                viewer.get_by_role("button", name="Fit diagram", exact=True).click()
                bounds = enlarged.bounding_box()
                stage = viewer.locator(".home-diagram-viewport")
                assert bounds["width"] <= stage.evaluate("element => element.clientWidth") + 1
                assert bounds["height"] <= stage.evaluate("element => element.clientHeight") + 1
                assert viewer.get_by_role("button", name="Zoom out", exact=True).is_disabled()
                viewer.get_by_role("button", name="Zoom in", exact=True).click()
                assert enlarged.bounding_box()["width"] > bounds["width"]
                viewer.get_by_role("button", name="Zoom out", exact=True).click()
                if width == 1440:
                    page.keyboard.press("Escape")
                else:
                    viewer.get_by_role("button", name="Close", exact=True).click()
                expect(viewer).to_be_hidden()
                expect(trigger).to_be_focused()
                assert page.locator("html").evaluate("element => getComputedStyle(element).overflow") == original_overflow
                assert page.evaluate("document.documentElement.scrollWidth <= document.documentElement.clientWidth")
        page.set_viewport_size({"width": 1440, "height": 1000})
        page.locator("#tab-standalone").click()
        page.locator("#architecture-standalone figcaption a").click()
        expect(viewer).to_be_visible()
        page.mouse.click(5, 5)
        expect(viewer).to_be_hidden()
        page.locator("#architecture-standalone .home-diagram-trigger").click()
        enlarged.evaluate("element => { element.src = '/missing-home-diagram.png'; }")
        expect(viewer.locator(".home-diagram-error")).to_be_visible()
        expect(enlarged).to_be_hidden()
        viewer.get_by_role("button", name="Close", exact=True).click()
        page.locator("#architecture-standalone .home-diagram-trigger").click()
        expect(viewer.locator(".home-diagram-error")).to_be_hidden()
        expect(enlarged).to_be_visible()
        page.keyboard.press("Escape")
        page.locator("#tab-standalone").focus()
        page.keyboard.press("End")
        expect(page.locator("#tab-gateway")).to_be_focused()
        page.locator(".supporting-diagrams > summary").click()
        page.locator("#tab-design").focus()
        page.keyboard.press("ArrowRight")
        expect(page.locator("#tab-caf")).to_be_focused()
        expect(page.locator("#diagram-caf")).to_be_visible()
        page.goto(base + "#with-platform-hub")
        expect(page.locator("#architecture-hub")).to_be_visible()
        expect(page.locator("#tab-hub")).to_have_attribute("aria-selected", "true")
        page.goto(base + "#contributing")
        expect(page.locator(".home-project-notes")).to_have_attribute("open", "")
        expect(page.locator("#contributing")).to_be_visible()
        page.goto(base)
        expect(page.locator(".md-sidebar--secondary")).to_be_hidden()
        expect(page.locator(".md-sidebar--primary")).to_be_visible()
        page.locator(".home-button--primary").click()
        page.wait_for_function("location.hash === '#implementations'")
        search = page.locator('input[data-md-component="search-query"]')
        search.fill("SharePoint")
        expect(page.locator('[data-md-component="search-result"]')).to_contain_text("SharePoint")
        page.keyboard.press("Escape")
        page.goto(base)
        for path in ("agent-landing-zone/application/", "agent-landing-zone/deploy-full-stack/",
                     "agent-landing-zone/sizing-cost-planner/"):
            page.goto(base + path)
            assert not page.locator(".alz-home").count()
            assert not page.locator('link[href*="stylesheets/home.css"]').count()
            assert not page.locator('script[src*="javascripts/home.js"]').count()
            if not path.endswith("sizing-cost-planner/"):
                expect(page.locator(".md-sidebar--secondary")).to_be_visible()
        check_application_navigation(page, base, screenshots)
        check_prose_wrapping(page, base, screenshots)
        page.set_viewport_size({"width": 1440, "height": 500})
        for path in ("", "agent-landing-zone/application/"):
            page.goto(base + path)
            sidebar = page.locator(".md-sidebar--primary .md-sidebar__scrollwrap")
            page.mouse.move(1400, 490)
            assert sidebar.evaluate("element => getComputedStyle(element).scrollbarWidth") == "auto"
            assert sidebar.evaluate("element => getComputedStyle(element).scrollbarColor") == "auto"
            thumb_style = sidebar.evaluate("""element => {
                const scrollbar = getComputedStyle(element, "::-webkit-scrollbar");
                const thumb = getComputedStyle(element, "::-webkit-scrollbar-thumb");
                return {
                    hitWidth: parseFloat(scrollbar.width),
                    paintWidth: parseFloat(scrollbar.width) - parseFloat(thumb.borderLeftWidth) - parseFloat(thumb.borderRightWidth),
                    clip: thumb.backgroundClip,
                    color: thumb.backgroundColor
                };
            }""")
            assert thumb_style == {"hitWidth": 8, "paintWidth": 2, "clip": "padding-box", "color": "rgb(230, 233, 238)"}, thumb_style
            sidebar.hover()
            assert sidebar.evaluate("element => getComputedStyle(element).scrollbarColor") == "auto"
            assert sidebar.evaluate('element => getComputedStyle(element, "::-webkit-scrollbar-thumb").backgroundColor') == "rgb(203, 210, 220)"
            nav_link = sidebar.locator("a.md-nav__link:visible").first
            nav_link.focus()
            expect(nav_link).to_be_focused()
            page.mouse.move(1400, 490)
            assert sidebar.evaluate('element => getComputedStyle(element, "::-webkit-scrollbar-thumb").backgroundColor') == "rgb(203, 210, 220)"
            if not path and not page.locator("#__nav_2").is_checked():
                sidebar.locator('label.md-nav__link[for="__nav_2"]').click()
            if not page.locator("#__nav_2_3").is_checked():
                sidebar.locator('label.md-nav__link[for="__nav_2_3"]').click()
            page.wait_for_function("""() => {
                const sidebar = document.querySelector(".md-sidebar--primary .md-sidebar__scrollwrap");
                return sidebar.scrollHeight > sidebar.clientHeight;
            }""")
            sidebar.hover()
            page.mouse.wheel(0, 300)
            page.wait_for_function("""() =>
                document.querySelector(".md-sidebar--primary .md-sidebar__scrollwrap").scrollTop > 0
            """)
            assert sidebar.evaluate("element => element.offsetWidth - element.clientWidth") in (0, 8)
            sidebar.evaluate("element => { element.scrollTop = 0; }")
            bounds = sidebar.bounding_box()
            drag_x = bounds["x"] + bounds["width"] - 4
            page.mouse.move(drag_x, bounds["y"] + 12)
            page.mouse.down()
            page.mouse.move(drag_x, bounds["y"] + 92, steps=5)
            page.mouse.up()
            page.wait_for_function("""() =>
                document.querySelector(".md-sidebar--primary .md-sidebar__scrollwrap").scrollTop > 0
            """)
            if screenshots and not path:
                page.screenshot(path=str(screenshots / "navigation-scrollbar-desktop.png"))
        page.set_viewport_size({"width": 390, "height": 700})
        page.goto(base)
        page.locator('.md-header label[for="__drawer"]').click()
        expect(page.locator(".md-sidebar--primary")).to_be_visible()
        page.wait_for_function("""() =>
            document.querySelector(".md-sidebar--primary").getBoundingClientRect().left >= -1
        """)
        expect(page.locator(".md-sidebar--primary a.md-nav__link:visible").first).to_be_visible()
        if screenshots:
            page.screenshot(path=str(screenshots / "navigation-scrollbar-mobile.png"))
        assert not errors, errors
        context = browser.new_context(java_script_enabled=False)
        fallback = context.new_page()
        fallback.goto(base)
        assert fallback.locator(".md-sidebar--secondary").is_hidden()
        assert fallback.locator(".home-mobile-contents").count() == 0
        for name in ("standalone", "hub", "gateway"):
            assert fallback.locator(f"#architecture-{name}").is_visible()
            assert fallback.locator(f"#architecture-{name} figcaption a").get_attribute("href")
        assert fallback.locator(".home-diagram-trigger").count() == 0
        assert fallback.locator(".architecture-workbench .home-tabs").is_hidden()
        context.close()
        browser.close()
    print("PASS: homepage layout, full-width diagrams, accessible zoom viewer, tabs, native navigation/search, legacy anchors, no-JS fallback and page isolation")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--site-dir", type=Path, default=ROOT / "site")
    parser.add_argument("--screenshots", type=Path)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Handler, directory=str(args.site_dir)))
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        run(f"http://127.0.0.1:{server.server_port}/", args.screenshots)
    finally:
        server.shutdown()
        server.server_close()
        worker.join()


if __name__ == "__main__":
    main()
