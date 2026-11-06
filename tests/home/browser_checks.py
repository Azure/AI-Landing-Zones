"""Verify the approved homepage inside the built MkDocs site."""

import argparse
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import re
import threading

from playwright.sync_api import expect, sync_playwright

from application_guides import check_application_guides
from diagram_controls import check_diagram_controls


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


def check_get_started(page, base, screenshots):
    for width in (1440, 390, 320):
        page.set_viewport_size({"width": width, "height": 1000})
        response = page.goto(base + "agent-landing-zone/get-started/")
        assert response.status == 200
        content = page.locator(".md-content__inner")
        expect(content.locator("h1")).to_have_text("Deploy your first agent application")
        text = content.inner_text()
        assert "--8<--" not in text, "Unexpanded shared instructions"
        for required in (
            "Bastion", "jumpbox", "resource-groups.json", "RUN_FROM_JUMPBOX",
            "NETWORK_ISOLATION", "DEPLOY_ACR_TASK_AGENT_POOL",
            "HOSTED_AGENT_RESOURCE_SCOPE", "OAUTH_AZURE_AD_CLIENT_SECRET",
            "CHAINLIT_AUTH_SECRET", "agent-lz", "ALLOWED_USER_PRINCIPALS",
        ):
            assert required in text, (required, "Missing first-installation requirement")
        commands = "\n".join(content.locator("pre").all_text_contents())
        journey = (
            "azd init", "azd provision", "azd env refresh",
            "azd hooks run postprovision", "azd deploy",
        )
        positions = [commands.index(command) for command in journey]
        assert positions == sorted(positions), ("Incorrect lifecycle order", positions)
        assert "azd up" not in commands, "Do not bypass first-installation login setup"
        assert "NETWORK_ISOLATION false" not in commands, "Private profile cannot fall back to public"
        for paragraph in content.locator("p").all_text_contents():
            assert len(paragraph.split()) <= 70, ("Dense quickstart paragraph", paragraph)
        assert page.evaluate(
            "document.documentElement.scrollWidth <= document.documentElement.clientWidth"
        ), (width, "Quickstart overflows the viewport")
        if width == 1440:
            for href in content.locator("a[href]").evaluate_all(
                "links => links.map(link => link.href)"
            ):
                if not href.startswith(base):
                    continue
                linked = page.request.get(href.split("#", 1)[0])
                assert linked.status == 200, ("Broken quickstart link", href)
                if "#" in href:
                    fragment = href.split("#", 1)[1]
                    assert page.evaluate("""({html, fragment}) =>
                        Boolean(new DOMParser().parseFromString(html, "text/html")
                            .getElementById(decodeURIComponent(fragment)))""",
                        {"html": linked.text(), "fragment": fragment}
                    ), ("Broken quickstart anchor", href)
        if screenshots:
            page.screenshot(path=str(screenshots / f"get-started-{width}.png"))


def expand_navigation_group(page, nav, name):
    label = nav.locator("label.md-nav__link").filter(
        has_text=re.compile(r"^\s*" + re.escape(name) + r"\s*$")
    )
    toggle = page.locator("#" + label.get_attribute("for"))
    if not toggle.is_checked():
        label.click()
    return label.locator("..").locator(":scope > nav.md-nav")


def check_lifecycle_navigation(page, base, screenshots):
    page.set_viewport_size({"width": 1440, "height": 1000})
    page.goto(base + "agent-landing-zone/")
    primary = page.locator(".md-nav--primary")
    agent = expand_navigation_group(page, primary, "Agent Landing Zone")
    labels = agent.locator(":scope > ul > li").evaluate_all("""items => items.map(item =>
        item.querySelector(":scope > .md-nav__link > .md-ellipsis").textContent.trim()
    )""")
    assert labels == [
        "Overview", "Get started", "What's new", "Plan", "Deploy", "Operate", "Reference",
        "Agent Application",
    ], labels
    for name in ("Plan", "Deploy", "Operate", "Reference"):
        branch = expand_navigation_group(page, agent, name)
        if name in ("Plan", "Reference"):
            actual = branch.locator(":scope > ul > li > a .md-ellipsis").all_text_contents()
            expected = {
                "Plan": ["Deployment choices", "Design checklist", "Network design", "Sizing & cost planner"],
                "Reference": ["Deployment settings", "Resource naming"],
            }[name]
            assert [label.strip() for label in actual] == expected, (name, actual)
        if name == "Deploy":
            companions = expand_navigation_group(page, branch, "Companion guides")
            actual = companions.locator(":scope > ul > li > a .md-ellipsis").all_text_contents()
            assert [label.strip() for label in actual] == [
                "Application Gateway", "Private access (VPN)", "PostgreSQL",
            ], actual
    if screenshots:
        page.screenshot(path=str(screenshots / "lifecycle-navigation-desktop.png"), animations="disabled")
    for name in ("Plan", "Reference"):
        label = agent.locator("label.md-nav__link").filter(
            has_text=re.compile(r"^\s*" + name + r"\s*$")
        )
        toggle = page.locator("#" + label.get_attribute("for"))
        label.focus()
        page.keyboard.press("Enter")
        expect(toggle).not_to_be_checked()
        page.keyboard.press("Enter")
        expect(toggle).to_be_checked()

    routes = (
        ("agent-landing-zone/get-started/", ("Agent Landing Zone",)),
        ("agent-landing-zone/planning/", ("Agent Landing Zone", "Plan")),
        ("agent-landing-zone/network-isolation/", ("Agent Landing Zone", "Plan")),
        ("architecture/design-checklist/", ("Agent Landing Zone", "Plan")),
        ("agent-landing-zone/configuration/", ("Agent Landing Zone", "Reference")),
        ("agent-landing-zone/resource-naming/", ("Agent Landing Zone", "Reference")),
        ("agent-landing-zone/deploy-infra-only/", ("Agent Landing Zone", "Deploy", "Bicep")),
        ("agent-landing-zone/deploy-full-stack/", ("Agent Landing Zone", "Deploy", "Bicep")),
        ("agent-landing-zone/terraform/", ("Agent Landing Zone", "Deploy", "Terraform")),
        ("agent-landing-zone/deploy-terraform-infra-only/", ("Agent Landing Zone", "Deploy", "Terraform")),
        ("agent-landing-zone/deploy-terraform-full-stack/", ("Agent Landing Zone", "Deploy", "Terraform")),
        ("agent-landing-zone/application-gateway/", ("Agent Landing Zone", "Deploy", "Companion guides")),
        ("agent-landing-zone/private-access/", ("Agent Landing Zone", "Deploy", "Companion guides")),
        ("agent-landing-zone/postgresql/", ("Agent Landing Zone", "Deploy", "Companion guides")),
        ("agent-landing-zone/deployment-operations/", ("Agent Landing Zone", "Operate")),
        ("agent-landing-zone/troubleshooting/", ("Agent Landing Zone", "Operate")),
        ("agent-landing-zone/application/", ("Agent Landing Zone", "Agent Application")),
        ("agent-landing-zone/agent-app-mcp/", ("Agent Landing Zone", "Agent Application", "Agents")),
        ("agent-landing-zone/build-your-own-app/",
         ("Agent Landing Zone", "Agent Application", "Development & customization")),
        ("agent-landing-zone/agentops/", ("Agent Landing Zone", "Agent Application")),
        ("agent-landing-zone/operations/", ("Agent Landing Zone", "Agent Application", "Operations")),
        ("ai-gateway-landing-zone/deploy/bicep-quick-deployment/",
         ("AI Gateway Landing Zone", "Deploy", "Bicep")),
    )
    for width in (1440, 390, 320):
        page.set_viewport_size({"width": width, "height": 1000})
        for path, groups in routes:
            response = page.goto(base + path)
            assert response.status == 200, path
            branch = primary
            for name in groups:
                label = branch.locator("label.md-nav__link").filter(
                    has_text=re.compile(r"^\s*" + re.escape(name) + r"\s*$")
                )
                expect(page.locator("#" + label.get_attribute("for"))).to_be_checked()
                branch = label.locator("..").locator(":scope > nav.md-nav")
            active_item = branch.locator(":scope > ul > li.md-nav__item--active")
            active = active_item.locator(":scope > a.md-nav__link--active")
            expect(active).to_have_count(1)
            assert active.evaluate("element => new URL(element.href).pathname === location.pathname"), path
            if path in ("agent-landing-zone/deploy-full-stack/",
                        "agent-landing-zone/deploy-terraform-full-stack/"):
                content = page.locator(".md-content__inner")
                for paragraph in content.locator("p").all_text_contents():
                    assert len(paragraph.split()) <= 70, (path, paragraph)
                if path == "agent-landing-zone/deploy-full-stack/":
                    sections = content.locator(":scope > h2, :scope > h3").evaluate_all(
                        "headings => headings.map(heading => heading.id)"
                    )
                    journey = [
                        "step-1-initialize-the-project", "step-2-select-the-deployment-target",
                        "step-3-choose-the-application-and-network", "step-4-deploy",
                        "validation", "updates-and-recovery", "rollback",
                        "remove-an-environment",
                    ]
                    positions = [sections.index(section) for section in journey]
                    assert positions == sorted(positions), sections
                    expect(content.locator(
                        "#choose-optional-experiences-and-storage"
                    )).to_have_count(1)
                    for anchor in (
                        "full-stack-deploy", "deploy-the-full-stack", "deploy-full-stack",
                        "step-1-get-the-code", "step-2-sign-in-and-create-an-environment",
                        "step-3-choose-a-topology", "native-application-provisioning",
                        "what-happens-during-the-deployment", "verify", "lifecycle",
                        "clean-up", "next-steps", "related-runbooks",
                    ):
                        expect(content.locator("#" + anchor)).to_have_count(1)
            if width < 768:
                page.locator('.md-header label[for="__drawer"]').click()
                page.wait_for_function("""() =>
                    document.querySelector(".md-sidebar--primary").getBoundingClientRect().left >= -1
                """)
                expect(active_item.locator(":scope > .md-nav__link--active:visible")).to_have_count(1)
                if screenshots and width == 390 and path.endswith("deployment-operations/"):
                    page.screenshot(path=str(screenshots / "lifecycle-navigation-mobile.png"), animations="disabled")
            assert page.evaluate("document.documentElement.scrollWidth <= document.documentElement.clientWidth"), (
                width, path
            )


def check_documentation_roles(page, base):
    page.set_viewport_size({"width": 1440, "height": 1000})
    page.goto(base + "agent-landing-zone/")
    content = page.locator(".md-content__inner")
    expect(content.get_by_role("heading", name="How the template works", exact=True)).to_have_count(1)
    expect(content.locator('a[href*="how-it-works/"]')).to_have_count(0)

    page.goto(base + "agent-landing-zone/planning/")
    expect(content.locator("pre")).to_have_count(0)
    for application_setting in ("hosted-no-panel", "maf_lite", "RETRIEVAL_BACKEND"):
        assert application_setting not in content.inner_text(), application_setting

    page.goto(base + "agent-landing-zone/network-isolation/")
    expect(content.locator("h1")).to_have_text("Network design")
    expect(content.locator("pre, .subnet-address-plan")).to_have_count(0)
    expect(content.locator('a[href$="configuration/#default-subnets"]')).to_have_count(1)
    expect(content.locator('a[href$="configuration/#outbound-access"]')).to_have_count(1)
    assert "not private end to end" in content.inner_text()

    page.goto(base + "agent-landing-zone/configuration/")
    expect(content.locator(".subnet-address-plan tbody tr")).to_have_count(13)
    for heading in ("Deployment inputs", "Outbound access", "Generated values and script state"):
        expect(content.get_by_role("heading", name=heading, exact=True)).to_have_count(1)

    response = page.goto(base + "agent-landing-zone/how-it-works/")
    assert response.status == 200
    expect(page.locator('.md-nav--primary a[href*="how-it-works/"]')).to_have_count(0)
    for anchor in (
        "how-the-template-works", "how-it-works", "how-to-read-deployment-settings",
        "repository-boundaries", "the-manifest-records-a-validated-combination",
        "parameters-describe-the-environment", "azureyaml-connects-azd-to-the-lifecycle",
        "deployment-lifecycle", "app-configuration-carries-runtime-settings",
        "who-publishes-settings", "how-applications-load-settings",
        "secrets-and-environment-boundaries", "why-hosted-agents-need-image-preparation",
        "from-understanding-to-deployment",
    ):
        expect(content.locator(f'[id="{anchor}"]')).to_have_count(1)
    search = page.request.get(base + "search/search_index.json")
    assert search.ok
    entries = search.json()["docs"]
    assert not any(entry["location"].startswith("agent-landing-zone/how-it-works/") for entry in entries)
    for path in ("configuration/", "resource-naming/", "network-isolation/"):
        assert any(entry["location"] == "agent-landing-zone/" + path for entry in entries), path


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
            branch = nav
            for name in ("Agent Landing Zone", "Agent Application"):
                branch = expand_navigation_group(page, branch, name)
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


def check_application_mcp_documentation(page, base):
    """Check the operator path and rendered contracts, not live service readiness."""
    for width in (1440, 390, 320):
        page.set_viewport_size({"width": width, "height": 1000})
        for path, heading in (
            ("application/", "Agent Application"),
            ("agent-app-mcp/", "Agent App MCP Server"),
            ("nl2sql/", "Ask questions about SQL data"),
            ("application-settings/", "Application settings"),
            ("build-your-own-app/", "Bring your own app"),
        ):
            response = page.goto(base + "agent-landing-zone/" + path)
            assert response.status == 200, path
            content = page.locator(".md-content__inner")
            expect(content.locator("h1")).to_have_text(heading)
            for retired in (
                "NL2SQL_ENABLED", "NL2SQL_SOURCE_REGISTRY",
                "execute_sql_query(", "execute_dax_query(",
            ):
                assert retired not in content.inner_text(), (path, retired)
            assert page.evaluate(
                "document.documentElement.scrollWidth <= document.documentElement.clientWidth"
            ), (width, path)

    page.goto(base + "agent-landing-zone/application/")
    content = page.locator(".md-content__inner")
    expect(content.get_by_role("heading", name="What Cosmos means in this application")).to_have_count(1)
    expect(content.get_by_role("heading", name="First time using Agent Application?", exact=True)).to_have_count(1)
    expect(content.locator('a[href*="agent-app-mcp/"]')).not_to_have_count(0)
    diagram = page.request.get(base + "media/agent-application-overview.svg")
    assert diagram.ok
    assert 'width="1000" height="850" viewBox="0 0 1000 850"' in diagram.text()
    assert "Agent App MCP" in diagram.text()

    page.goto(base + "agent-landing-zone/agent-app-mcp/")
    content = page.locator(".md-content__inner")
    for heading in (
        "Deploy Agent App MCP Server", "Authentication and endpoint", "Select toolsets",
        "Operate the server", "Configure NL2SQL", "Custom applications",
        "Fresh application", "Add to an existing installation", "Onboard sources",
    ):
        expect(content.get_by_role("heading", name=heading, exact=True)).to_have_count(1)
    sections = [
        "Deploy Agent App MCP Server", "Authentication and endpoint", "Select toolsets",
        "Operate the server", "Configure NL2SQL", "Custom applications",
    ]
    headings = content.locator(":scope > h2").all_text_contents()
    positions = [headings.index(section) for section in sections]
    assert positions == sorted(positions), headings
    blocks = content.locator("pre").all_text_contents()
    expect(content.locator('a[href*="deploy-full-stack/"]')).not_to_have_count(0)
    assert not any(
        "git clone https://github.com/Azure/agent-landing-zone.git" in block
        for block in blocks
    )
    assert not any("--branch develop" in block for block in blocks)
    assert any("azd env set DEPLOY_AGENT_APP_MCP true" in block and "azd provision" in block for block in blocks)
    assert any("""azd env set MCP_TOOLSETS '[]'""" in block for block in blocks)
    assert any(
        block.index("azd provision") < block.index("azd deploy")
        for block in blocks if "azd provision" in block and "azd deploy" in block
    )
    expect(content.locator("#start-here-from-deployment-to-the-first-question")).to_have_count(1)
    assert "MCP.Invoke" in content.inner_text()
    assert "rather than automatically destroyed" in content.inner_text()
    assert "restarts every active MCP revision" in content.inner_text()
    assert "startup-only" in content.inner_text()
    text = content.inner_text()
    for value in (
        "zero tools", "optional server compute", "no hot reload",
        "Unknown names, duplicates", "previously granted roles",
        "tenant's v2 issuer", "MCP_TOOLSETS",
        "exposes application tools over Model Context Protocol",
        "official Python MCP SDK",
    ):
        assert value in text, value
    assert "explicitly selected NL2SQL toolset" in diagram.text()
    assert "An empty server still requires authentication" in diagram.text()

    page.goto(base + "agent-landing-zone/application-settings/")
    content = page.locator(".md-content__inner")
    mcp_table = content.locator("#agent-app-mcp-contract").locator("xpath=following::table[1]")
    for key in (
        "MCP_AUTH_TENANT_ID", "MCP_AUTH_AUDIENCE", "MCP_AUTH_RESOURCE_SCOPE",
        "MCP_ALLOWED_CLIENT_IDS", "MCP_COSMOS_ENDPOINT", "MCP_COSMOS_DATABASE",
        "MCP_SOURCES_CONTAINER", "MCP_METADATA_CONTAINER", "MCP_EMBEDDING_DIMENSIONS",
        "MCP_QUERY_TIMEOUT_SECONDS", "MCP_CLIENT_TIMEOUT", "MCP_METADATA_TOP_K",
        "AI_FOUNDRY_OPENAI_ENDPOINT", "CHAT_DEPLOYMENT_NAME", "EMBEDDING_DEPLOYMENT_NAME",
        "KEY_VAULT_ENDPOINT", "MCP_SQL_SECRET_NAMES", "MCP_TOOLSETS",
    ):
        assert key in mcp_table.inner_text(), key
    assert "1..75" in mcp_table.inner_text()
    assert "when NL2SQL is selected" in mcp_table.inner_text()
    assert "does not validate NL2SQL settings" in content.inner_text()

    page.goto(base + "agent-landing-zone/nl2sql/")
    text = content.inner_text()
    for value in (
        "nl2sql.list_sources()", "nl2sql.query(source_id, question)",
        "metadata_version", "row_count", "1,000", "262144", "3072",
        "MCP_QUERY_TIMEOUT_SECONDS=75", "MCP_CLIENT_TIMEOUT=90",
    ):
        assert value in text, value
    expect(content.get_by_role(
        "heading", name=re.compile(r"Import the approved file", re.IGNORECASE)
    )).to_have_count(1)
    imports = content.locator("pre").all_text_contents()
    assert any(
        'PYTHONPATH=src uv run --frozen python -m tools.nl2sql.importer --file' in block
        for block in imports
    )
    assert any(
        "$env:PYTHONPATH = 'src'" in block
        and "--file C:\\approved\\approved-products.json" in block
        and "$env:APP_CONFIG_ENDPOINT" in block
        for block in imports
    )
    assert any("--file /path/to/approved-products.json" in block and "APP_CONFIG_ENDPOINT" in block for block in imports)
    expect(content.get_by_role("heading", name="Example approved source file", exact=True)).to_have_count(1)
    expect(content.get_by_role(
        "heading", name=re.compile(r"Ask(?: and verify)? the first question", re.IGNORECASE)
    )).to_have_count(1)
    expect(content.get_by_role("heading", name="How an NL2SQL request is answered", exact=True)).to_have_count(1)
    expect(content.get_by_role("heading", name="How an MCP question is answered", exact=True)).to_have_count(0)
    assert "Azure CLI login is not an importer credential fallback" in text
    assert "manifest-pinned MCP component" in text
    assert "manifest.json" in text

    selection = """azd env set MCP_TOOLSETS '["nl2sql"]'"""
    for path in ("agent-app-mcp/", "nl2sql/", "deploy-full-stack/",
                 "deploy-terraform-full-stack/"):
        page.goto(base + "agent-landing-zone/" + path)
        assert selection in "\n".join(content.locator("pre").all_text_contents()), path

    page.goto(base + "agent-landing-zone/")
    expect(content.locator('a[href$="build-your-own-app/#application-binding-and-selection"]')).to_have_count(1)
    text = content.inner_text()
    for value in ("azd provision", "azd deploy", "Reprovisioning preserves", "generic compute"):
        assert value in text, value

    page.goto(base + "agent-landing-zone/build-your-own-app/")
    text = " ".join(content.inner_text().split())
    for value in (
        "above the reusable", "AGENTLZ_APP_DEFINITION",
        "only its declared components", "before Azure calls",
        "COSMOS_VECTOR_SEARCH_ENABLED", "own explicit component",
        "A custom app can explicitly pass MCP_TOOLSETS",
    ):
        assert value in text, value
    assert "definition is additive" not in text
    assert "retrieval is independently selected and defaults to off" in text

    page.goto(base + "agent-landing-zone/configuration/")
    assert "Application-layer vector capability/retention state" in content.inner_text()
    assert "not a new foundation output" in content.inner_text()
    assert "DEPLOY_AGENT_APP_MCP is rejected for custom definitions" in content.inner_text()
    assert "Custom applications may explicitly supply MCP_TOOLSETS" in content.inner_text()
    assert "no NL2SQL catalog, model or secret grants" in content.inner_text()


def check_agent_page_inventory(page, base):
    """Every central Agent page must build, including linked compatibility pages."""
    sources = sorted((ROOT / "docs" / "agent-landing-zone").glob("*.md"))
    assert sources
    for source in sources:
        route = "" if source.stem == "index" else source.stem + "/"
        response = page.request.get(base + "agent-landing-zone/" + route)
        assert response.status == 200, source.name
        html = response.text()
        assert "<h1" in html and 'class="md-content' in html, source.name
        for misleading_name in ("MCP / NL2SQL", "NL2SQL MCP component"):
            assert misleading_name not in html, (source.name, misleading_name)
    print(f"PASS: all {len(sources)} Agent Landing Zone pages render, including compatibility routes")


def check_postgresql_private_guidance(page, base, screenshots):
    for width in (1440, 390, 320):
        page.set_viewport_size({"width": width, "height": 1000})
        page.goto(base + "agent-landing-zone/postgresql/")
        content = page.locator(".md-content__inner")
        primary_commands = content.locator("pre").first.inner_text()
        assert "NETWORK_ISOLATION true" in primary_commands
        assert "NETWORK_ISOLATION false" not in primary_commands
        expect(content.get_by_role("cell", name=(
            "false; explicitly set true for the recommended private design"
        ), exact=True)).to_have_count(1)
        diagram = content.locator(".alz-diagram img")
        expect(diagram).to_have_attribute("alt", re.compile(
            r"^Recommended private PostgreSQL connectivity:"
        ))
        image = page.request.get(base + "media/runbooks/postgresql.svg")
        assert image.ok
        for required in ("Private Endpoint", "Private DNS", "NETWORK_ISOLATION=true",
                         "Public PostgreSQL access is disabled"):
            assert required in image.text(), required
        for public_emphasis in ("NAT Gateway", "Public endpoint", "NETWORK_ISOLATION=false"):
            assert public_emphasis not in image.text(), public_emphasis
        alternative = content.locator("details").filter(has=page.locator(
            "summary", has_text="Optional configuration: restricted public access (Basic)"
        ))
        expect(alternative).to_have_count(1)
        assert alternative.get_attribute("open") is None
        public_setting = alternative.locator("code", has_text="NETWORK_ISOLATION=false")
        expect(public_setting).not_to_be_visible()
        alternative.locator("summary").click()
        expect(public_setting).to_be_visible()
        expect(alternative).to_contain_text("not the recommended enterprise path")
        expect(alternative).to_contain_text("networking resource group")
        alternative.locator("summary").click()
        expect(public_setting).not_to_be_visible()
        assert page.evaluate(
            "document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1"
        ), (width, "PostgreSQL guide overflow")
        if screenshots:
            page.screenshot(path=str(screenshots / f"postgresql-private-{width}.png"))
    print("PASS: private-first PostgreSQL example/diagram, unchanged defaults and collapsed Basic option")


def run_agent_docs(base, screenshots):
    """Focused documentation check; no service, Azure or deployment calls."""
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(ignore_default_args=["--hide-scrollbars"])
        try:
            page = browser.new_page(viewport={"width": 1440, "height": 1000})
            check_application_guides(page, base, screenshots)
            check_lifecycle_navigation(page, base, screenshots)
            check_get_started(page, base, screenshots)
            check_application_mcp_documentation(page, base)
            check_agent_page_inventory(page, base)
            check_postgresql_private_guidance(page, base, screenshots)
            check_application_navigation(page, base, screenshots)
            check_prose_wrapping(page, base, screenshots)
        finally:
            browser.close()
    print("PASS: MCP server/toolset separation, explicit install, importer, custom-app journey and navigation")


def run_application_docs(base, screenshots):
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(ignore_default_args=["--hide-scrollbars"])
        try:
            page = browser.new_page(viewport={"width": 1440, "height": 1000})
            check_application_guides(page, base, screenshots)
        finally:
            browser.close()


def run_diagram_docs(base, screenshots):
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(ignore_default_args=["--hide-scrollbars"])
        try:
            page = browser.new_page(viewport={"width": 1440, "height": 1000})
            check_diagram_controls(page, base, screenshots)
        finally:
            browser.close()


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
            assert len(targets) == 8
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

    # Keep the reported state/metadata wall of text split by its distinct owners
    # and lifecycle topics, regardless of viewport or font-dependent line breaks.
    page.goto(base + "agent-landing-zone/conversations/#state-and-metadata-dependencies")
    paragraphs = page.locator("#state-and-metadata-dependencies").evaluate("""heading => {
        const paragraphs = [];
        for (let next = heading.nextElementSibling; next && next.tagName !== "H2";
             next = next.nextElementSibling) {
            if (next.tagName === "P") paragraphs.push(next.textContent.trim());
        }
        return paragraphs;
    }""")
    assert len(paragraphs) >= 5, paragraphs
    for paragraph in paragraphs:
        assert len(paragraph.split()) <= 70, paragraph


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
        architecture = page.locator(".architecture-workbench")
        expect(architecture.get_by_role("tab")).to_have_text(["Platform Hub", "AI Gateway", "Standalone"])
        expect(page.locator("#tab-hub")).to_have_attribute("aria-selected", "true")
        expect(page.locator("#architecture-hub")).to_be_visible()
        expect(page.locator("#architecture-standalone > p")).to_have_text(
            "Deploy an independent environment where your team manages the network, without a shared platform hub."
        )
        assert "not a blank page" not in page.locator(".hero").inner_text()
        assert not page.locator(".alz-home a[href$='.md']").count()
        assert page.locator(".alz-home img:not(.home-diagram-image)").count() == 7
        assert page.locator(".implementation-table tbody a").count() == 9
        card_links = (
            (
                ("Get started", "agent-landing-zone/get-started/"),
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
        page.locator("#tab-hub").focus()
        page.keyboard.press("End")
        expect(page.locator("#tab-standalone")).to_be_focused()
        page.keyboard.press("Home")
        expect(page.locator("#tab-hub")).to_be_focused()
        page.keyboard.press("ArrowRight")
        expect(page.locator("#tab-gateway")).to_be_focused()
        page.keyboard.press("ArrowRight")
        expect(page.locator("#tab-standalone")).to_be_focused()
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
        check_lifecycle_navigation(page, base, screenshots)
        check_get_started(page, base, screenshots)
        check_documentation_roles(page, base)
        check_application_navigation(page, base, screenshots)
        check_application_mcp_documentation(page, base)
        check_agent_page_inventory(page, base)
        check_postgresql_private_guidance(page, base, screenshots)
        check_application_guides(page, base, screenshots)
        check_diagram_controls(page, base, screenshots)
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
            agent = expand_navigation_group(page, sidebar, "Agent Landing Zone")
            expand_navigation_group(page, agent, "Plan")
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
        assert fallback.locator(".architecture-panel").evaluate_all(
            "panels => panels.map(panel => panel.id)"
        ) == ["architecture-hub", "architecture-gateway", "architecture-standalone"]
        for name in ("standalone", "hub", "gateway"):
            assert fallback.locator(f"#architecture-{name}").is_visible()
            assert fallback.locator(f"#architecture-{name} figcaption a").get_attribute("href")
        assert fallback.locator(".home-diagram-trigger").count() == 0
        assert fallback.locator(".architecture-workbench .home-tabs").is_hidden()
        context.close()
        browser.close()
    print("PASS: homepage layout, full-width diagrams, accessible zoom viewer, tabs, lifecycle navigation, native navigation/search, MCP operator path and rendered contracts, legacy anchors, no-JS fallback and page isolation")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--site-dir", type=Path, default=ROOT / "site")
    parser.add_argument("--screenshots", type=Path)
    parser.add_argument("--agent-docs-only", action="store_true",
                        help="Check Agent documentation/navigation without the unrelated homepage suite")
    parser.add_argument("--application-guides-only", action="store_true",
                        help="Check application procedures and contextual diagrams only")
    parser.add_argument("--diagram-controls-only", action="store_true",
                        help="Check Agent diagram expansion, zoom, accessibility and page isolation")
    args = parser.parse_args()
    if args.screenshots:
        args.screenshots.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Handler, directory=str(args.site_dir)))
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        runner = (
            run_diagram_docs if args.diagram_controls_only else
            run_application_docs if args.application_guides_only else
            run_agent_docs if args.agent_docs_only else run
        )
        runner(f"http://127.0.0.1:{server.server_port}/", args.screenshots)
    finally:
        server.shutdown()
        server.server_close()
        worker.join()


if __name__ == "__main__":
    main()
