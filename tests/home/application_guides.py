"""Rendered contracts for the Agent Application newcomer guides and diagrams."""

import re
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET


APPLICATION_GUIDES = (
    "application", "hosted-agents", "agent-strategies", "workflows",
    "agent-tools", "agent-app-mcp", "application-auth", "conversations",
    "embed-chat", "user-feedback", "publish-to-teams", "connect-copilot-studio",
    "foundry-iq", "work-iq", "fabric-iq", "sharepoint", "nl2sql",
    "ingestion", "multimodality", "ingestion-jobs", "application-settings",
    "operations", "application-monitoring", "agentops", "local-development",
    "customize-components", "application-api", "application-testing",
    "build-your-own-app",
)
DIAGRAM_GUIDES = (
    "workflows", "hosted-agents", "agent-strategies", "agent-tools",
    "agent-app-mcp", "application-auth", "conversations", "user-feedback",
    "foundry-iq", "work-iq", "fabric-iq", "sharepoint", "nl2sql", "ingestion",
)
SVG = "{http://www.w3.org/2000/svg}"
PROCEDURE = re.compile(
    r"how to|configur|setup|set up|procedure|first|run|deploy|install|"
    r"prepare|enable|create|start|step|connect|evaluat|publish|use the",
    re.IGNORECASE,
)


def check_application_guides(page, base, screenshots=None):
    """Every application page is instructional and every requested diagram opens."""
    page.goto(base + "agent-landing-zone/application/", wait_until="domcontentloaded")
    branch = (
        page.locator(".md-nav--primary label.md-nav__link")
        .filter(has_text=re.compile(r"^\s*Agent Application\s*$"))
        .locator("..").locator(":scope > nav.md-nav")
    )
    routes = branch.locator("a[href]").evaluate_all("links => links.map(link => link.href)")
    actual = {
        urlsplit(url).path.rstrip("/").rsplit("/", 1)[-1]
        for url in routes if "/agent-landing-zone/" in urlsplit(url).path
    }
    assert actual == set(APPLICATION_GUIDES), (
        "Application navigation changed; review every guide", actual
    )
    target_ids = {}
    for guide in APPLICATION_GUIDES:
        for width in (1440, 390, 320):
            page.set_viewport_size({"width": width, "height": 1000})
            response = page.goto(
                base + "agent-landing-zone/" + guide + "/",
                wait_until="domcontentloaded",
            )
            assert response.status == 200, (guide, width)
            content = page.locator(".md-content__inner")
            headings = content.locator("h2, h3").all_text_contents()
            assert any(PROCEDURE.search(heading) for heading in headings), (guide, headings)
            if guide == "agent-tools":
                tools = content.locator("#tools-available-to-the-agent").locator(
                    "xpath=following::table[1]"
                ).inner_text()
                for tool in (
                    "Azure AI Search", "Foundry IQ", "multimodal_retrieve",
                    "nl2sql.list_sources", "nl2sql.query",
                ):
                    assert tool in tools, (guide, "Missing registered tool description", tool)
            assert content.locator("ol > li").count() >= 2, (
                guide, "Expected concrete ordered instructions"
            )
            paragraphs = content.locator("p").evaluate_all("""paragraphs => paragraphs
                .filter(p => !p.closest('table, li, pre, .admonition'))
                .map(p => p.textContent.trim()).filter(Boolean)""")
            assert all(len(paragraph.split()) <= 70 for paragraph in paragraphs), (
                guide, [paragraph for paragraph in paragraphs if len(paragraph.split()) > 70]
            )
            assert "Do not invent a native feedback-list endpoint from the old panel API" not in content.inner_text()
            assert page.evaluate(
                "document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1"
            ), (guide, width, "Document overflow")
            if width == 1440:
                hrefs = content.locator("a[href]").evaluate_all(
                    "links => links.map(link => link.href)"
                )
                for href in hrefs:
                    parts = urlsplit(href)
                    if not href.startswith(base) or not parts.fragment:
                        continue
                    target = parts._replace(fragment="").geturl()
                    if target not in target_ids:
                        linked = page.request.get(target)
                        assert linked.status == 200, (guide, href, "Broken local page")
                        target_ids[target] = page.evaluate("""html => Array.from(
                            new DOMParser().parseFromString(html, 'text/html')
                                .querySelectorAll('[id]')
                        ).map(element => element.id)""", linked.text())
                    assert unquote(parts.fragment) in target_ids[target], (
                        guide, href, "Broken configuration or procedure anchor"
                    )
            if guide in DIAGRAM_GUIDES:
                asset = "media/runbooks/" + guide + ".svg"
                image = content.locator(f"img[src*='{asset}']")
                assert image.count() == 1, (guide, "Missing or duplicate contextual diagram")
                assert len((image.get_attribute("alt") or "").split()) >= 5, (
                    guide, "Missing diagram description"
                )
                links = content.locator(f"a[href*='{asset}']").filter(
                    has_text=re.compile(r"open.*diagram", re.IGNORECASE)
                )
                assert links.count() >= 1, (guide, "Missing full-size diagram link")
                assert any(link.is_visible() for link in links.all()), (guide, width)
            if screenshots and width == 1440 and guide in DIAGRAM_GUIDES:
                content.screenshot(path=str(screenshots / f"{guide}-article.png"))

    page.set_viewport_size({"width": 1200, "height": 1100})
    for guide in DIAGRAM_GUIDES:
        url = base + "media/runbooks/" + guide + ".svg"
        response = page.request.get(url)
        assert response.status == 200, guide
        text = response.text()
        root = ET.fromstring(text)
        assert root.tag == SVG + "svg" and root.get("viewBox"), guide
        assert root.find(SVG + "title") is not None, (guide, "Missing SVG title")
        description = root.find(SVG + "desc")
        assert description is not None and description.text, (guide, "Missing SVG description")
        if guide == "agent-tools":
            labels = " ".join(
                "".join(element.itertext()) for element in root.findall(".//" + SVG + "text")
            )
            for label in (
                "Foundry tool integrations", "Azure AI Search", "Foundry IQ",
                "Application tool integrations", "multimodal_retrieve",
                "nl2sql.list_sources", "nl2sql.query",
            ):
                assert label in labels, (guide, "Missing tool integration", label)
            assert "Application registration" not in labels
        assert root.find(".//" + SVG + "script") is None, (guide, "Executable SVG")
        assert root.find(".//" + SVG + "foreignObject") is None, (guide, "Embedded HTML")
        assert not re.search(
            r"@import|url\(\s*['\"]?(?:https?:|//|file:)", text, re.IGNORECASE
        ), (guide, "External diagram stylesheet or resource")
        for element in root.iter():
            for name, value in element.attrib.items():
                if name.rsplit("}", 1)[-1] == "href":
                    assert not value.startswith(("http:", "https:", "//", "file:")), (
                        guide, "External diagram resource", value
                    )
        page.goto(url, wait_until="domcontentloaded")
        measurements = page.locator("svg").first.evaluate("""svg => {
            const art = svg.getBoundingClientRect();
            return Array.from(svg.querySelectorAll('text')).filter(text =>
                !text.closest('defs') && text.getBoundingClientRect().width
            ).map(text => {
                const bounds = text.getBoundingClientRect();
                return {
                    text: text.textContent.trim(),
                    inside: bounds.left >= art.left - 1 &&
                        bounds.right <= art.right + 1 &&
                        bounds.top >= art.top - 1 && bounds.bottom <= art.bottom + 1
                };
            });
        }""")
        assert measurements, (guide, "SVG has no accessible text labels")
        assert all(item["inside"] for item in measurements), (
            guide, [item for item in measurements if not item["inside"]]
        )
        if screenshots:
            page.locator("svg").first.screenshot(
                path=str(screenshots / f"{guide}-diagram.png")
            )
    print(
        f"PASS: {len(APPLICATION_GUIDES)} instructional Agent Application guides, "
        f"{len(DIAGRAM_GUIDES)} accessible self-contained diagrams and three viewports"
    )
