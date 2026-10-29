"""Verify the approved homepage inside the built MkDocs site."""

import argparse
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
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


def run(base, screenshots):
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
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
        assert page.locator(".alz-home img").count() == 7
        assert page.locator(".implementation-table tbody a").count() == 8
        assert page.locator(".paths .text-link").count() == 2
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
            for name in ("standalone", "hub", "gateway"):
                page.locator(f"#tab-{name}").click()
                expect(page.locator(f"#architecture-{name}")).to_be_visible()
                assert page.locator(".architecture-panel:visible").count() == 1
                assert not page.locator(f"#architecture-{name} details").count()
                assert page.locator(f"#architecture-{name} img").is_visible()
            if width <= 560:
                heading = page.locator(".implementation-table tbody th").first.bounding_box()
                table = page.locator(".implementation-table").bounding_box()
                assert abs(heading["width"] - table["width"]) < 2, width
        page.set_viewport_size({"width": 1440, "height": 1000})
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
        assert not errors, errors
        context = browser.new_context(java_script_enabled=False)
        fallback = context.new_page()
        fallback.goto(base)
        assert fallback.locator(".md-sidebar--secondary").is_hidden()
        assert fallback.locator(".home-mobile-contents").count() == 0
        for name in ("standalone", "hub", "gateway"):
            assert fallback.locator(f"#architecture-{name}").is_visible()
        assert fallback.locator(".architecture-workbench .home-tabs").is_hidden()
        context.close()
        browser.close()
    print("PASS: homepage responsive layout, tabs, original diagrams, native navigation/search, legacy anchors, no-JS fallback and page isolation")


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
