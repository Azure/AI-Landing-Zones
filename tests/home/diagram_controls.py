"""Interaction and scope contracts for the approved Agent diagram controls."""

import re
from urllib.parse import urljoin

from playwright.sync_api import expect


DIAGRAM_PAGES = (
    "", "application", "agent-app-mcp", "agent-strategies", "agent-tools",
    "application-auth", "application-gateway", "azure-devops",
    "connect-copilot-studio", "conversations", "deploy-full-stack",
    "fabric-iq", "foundry-iq", "hosted-agents", "ingestion", "nl2sql",
    "postgresql", "private-access", "publish-to-teams", "sharepoint",
    "user-feedback", "work-iq", "workflows", "inline-visuals",
)


def check_diagram_controls(page, base, screenshots=None):
    errors = []
    page.on("pageerror", lambda error: errors.append(error))
    for width in (1440, 390, 320):
        page.set_viewport_size({"width": width, "height": 1000})
        for guide in DIAGRAM_PAGES:
            path = "agent-landing-zone/" + (guide + "/" if guide else "")
            page.goto(base + path, wait_until="domcontentloaded")
            control = page.get_by_role("link", name="Expand diagram", exact=True)
            expect(control).to_have_count(1)
            expect(control).to_be_visible()
            control.scroll_into_view_if_needed()
            expect(control).to_be_enabled(timeout=30000)
            figure = page.locator(".alz-diagram")
            diagram = figure.locator("img").first
            summary = figure.locator(".runbook-diagram__summary")
            content = summary if summary.is_visible() else diagram
            expect(content).to_be_visible(timeout=15000)
            if content == diagram:
                expect(diagram).to_have_js_property("complete", True, timeout=15000)
                assert diagram.evaluate("image => image.naturalWidth > 0"), (guide, width)
            control.scroll_into_view_if_needed()
            bounds = control.bounding_box()
            assert bounds["width"] >= 44 and bounds["height"] >= 44, (guide, width)
            assert bounds["x"] >= 0 and bounds["x"] + bounds["width"] <= width, (guide, width)
            content_bounds = content.bounding_box()
            figure_bounds = figure.bounding_box()
            assert bounds["y"] >= content_bounds["y"] + content_bounds["height"] - 1, (
                guide, width, "Expand control must be below the diagram or mobile summary"
            )
            assert abs(bounds["x"] + bounds["width"] - figure_bounds["x"] - figure_bounds["width"]) <= 1, (
                guide, width, "Expand control must align with the diagram's right edge"
            )
            assert figure.evaluate("""figure =>
                Boolean(figure.querySelector('img').compareDocumentPosition(
                    figure.querySelector('.alz-diagram__expand')
                ) & Node.DOCUMENT_POSITION_FOLLOWING)
            """), (guide, width, "Expand control must follow the image in DOM order")
            assert page.locator("a.runbook-diagram__open").count() == 0, (guide, width)
            assert not page.locator("article a").filter(
                has_text=re.compile(r"^Open (the )?full-size diagram$")
            ).count(), (guide, width, "Visible footer link was not replaced")
            assert page.evaluate(
                "document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1"
            ), (guide, width, "Page overflow")
            if screenshots and guide in ("fabric-iq", "application", "hosted-agents") and width != 320:
                page.mouse.move(0, 0)
                page.locator(".alz-diagram").screenshot(
                    path=str(screenshots / f"{guide}-control-{width}.png")
                )
            control.scroll_into_view_if_needed()
            scroll = page.evaluate("window.scrollY")
            control.focus()
            control.press("Enter")
            viewer = page.locator("dialog.alz-diagram-viewer")
            expect(viewer).to_be_visible()
            image = viewer.locator("img")
            expect(image).to_be_visible(timeout=15000)
            assert image.evaluate("image => image.naturalWidth > 0"), (guide, width)
            assert viewer.bounding_box()["width"] <= width, (guide, width, "Viewer overflow")
            fitted_width = image.bounding_box()["width"]
            viewer.get_by_role("button", name="Zoom in", exact=True).click()
            assert image.bounding_box()["width"] > fitted_width, (guide, width, "Zoom did not enlarge")
            if screenshots and guide in ("fabric-iq", "application") and width != 320:
                viewer.screenshot(path=str(screenshots / f"{guide}-viewer-{width}.png"))
            viewer.get_by_role("button", name="Fit diagram", exact=True).click()
            assert abs(image.bounding_box()["width"] - fitted_width) <= 1, (guide, width)
            for _ in range(8):
                page.keyboard.press("Tab")
                assert viewer.evaluate("dialog => dialog.contains(document.activeElement)"), (
                    guide, width, "Focus escaped the modal"
                )
            page.keyboard.press("Escape")
            expect(viewer).not_to_be_visible()
            expect(control).to_be_focused()
            assert abs(page.evaluate("window.scrollY") - scroll) <= 2, (
                guide, width, "Closing moved the reading position"
            )
    assert not errors, [str(error) for error in errors]

    page.set_viewport_size({"width": 1440, "height": 1000})
    page.goto(base + "agent-landing-zone/fabric-iq/")
    page.locator(".runbook-diagram__image").click()
    viewer = page.locator("dialog.alz-diagram-viewer")
    expect(viewer.locator("img")).to_be_visible()
    viewer.get_by_role("button", name="Zoom in", exact=True).click()
    viewport = viewer.locator(".alz-diagram-viewer__viewport")
    region = viewport.bounding_box()
    page.mouse.move(region["x"] + region["width"] / 2, region["y"] + region["height"] / 2)
    page.mouse.down()
    page.mouse.move(region["x"] + region["width"] / 2 - 80, region["y"] + region["height"] / 2 - 80)
    page.mouse.up()
    assert viewport.evaluate("element => element.scrollLeft > 0 || element.scrollTop > 0")
    viewer.get_by_role("button", name="Close diagram", exact=True).click()
    expect(viewer).not_to_be_visible()
    page.get_by_role("link", name="Expand diagram", exact=True).click()
    expect(viewer).to_be_visible()
    page.mouse.click(1, 1)
    expect(viewer).not_to_be_visible()

    error_page = page.context.browser.new_page()
    try:
        error_page.route("**/media/runbooks/fabric-iq.svg*", lambda route: route.abort())
        error_page.goto(base + "agent-landing-zone/fabric-iq/")
        error_page.get_by_role("link", name="Expand diagram", exact=True).click()
        expect(error_page.locator(".alz-diagram-viewer__status[role='alert']")).to_contain_text(
            "The diagram could not load"
        )
        expect(error_page.get_by_role("button", name="Zoom in", exact=True)).to_be_disabled()
        expect(error_page.get_by_role("link", name="Open image in new tab")).to_have_attribute(
            "href", re.compile(r"/media/runbooks/fabric-iq.svg(?:\?.*)?$")
        )
    finally:
        error_page.close()

    for path in ("", "ai-gateway-landing-zone/", "agent-landing-zone/terraform/"):
        page.goto(base + path)
        assert page.locator(".alz-diagram, .alz-diagram-viewer").count() == 0, path
    assert page.request.get(base + "architecture/media/AI-Landing-Zone-without-platform.png").ok
    fallback = page.context.browser.new_context(java_script_enabled=False)
    try:
        no_js = fallback.new_page()
        no_js.goto(base + "agent-landing-zone/fabric-iq/")
        link = no_js.locator("a.runbook-diagram__open")
        expect(link).to_be_visible()
        assert no_js.request.get(urljoin(no_js.url, link.get_attribute("href"))).ok
        assert no_js.locator(".alz-diagram__expand").count() == 0
    finally:
        fallback.close()
    print(
        f"PASS: {len(DIAGRAM_PAGES)} lower-right diagram controls at three viewports, keyboard/focus, "
        "zoom/pan, errors, no-JS fallback and Home/Gateway isolation"
    )
