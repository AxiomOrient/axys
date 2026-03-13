enum HTMLShellFallbackAssets {
    static let layout = """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>__SCREEN_ID__ review shell</title>
      <link rel="stylesheet" href="shell/review.css" />
    </head>
    <body
      data-screen-id="__SCREEN_ID__"
      data-screen-html="__SCREEN_HTML__"
      data-review-report="__REVIEW_JSON__"
      data-tokens-css="__TOKENS_CSS__"
      data-review-payload="__REVIEW_DATA_B64__"
    >
      <main class="shell-app">
        <header class="shell-hero">
          <p class="shell-kicker">Fallback Review Shell</p>
          <h1 class="shell-title" data-title>Loading review metadata…</h1>
          <p class="shell-copy">Built-in fallback shell is active because source shell assets were not found.</p>
          <div class="shell-meta" data-meta-chips></div>
        </header>
        <section class="shell-grid">
          <section class="shell-stage">
            <div class="shell-toolbar">
              <button class="shell-toggle" type="button" data-reduced-motion-toggle>Reduced motion: off</button>
              <p class="shell-toolbar-copy">Fallback shell mounted the canonical HTML review output below.</p>
            </div>
            <iframe class="shell-frame" data-screen-frame title="__SCREEN_ID__ review shell" loading="lazy"></iframe>
          </section>
          <aside class="shell-sidebar">
            <section class="shell-card">
              <p class="shell-card-title">Intent</p>
              <p class="shell-copy" data-intent>No explicit intent.</p>
            </section>
            <section class="shell-card">
              <p class="shell-card-title">Preview States</p>
              <div class="shell-chip-list" data-preview-states></div>
            </section>
            <section class="shell-card">
              <p class="shell-card-title">Review Checklist</p>
              <ul class="shell-list" data-review-checklist></ul>
            </section>
            <section class="shell-card">
              <p class="shell-card-title">Motion</p>
              <ul class="shell-list" data-motion-patterns></ul>
            </section>
            <section class="shell-card">
              <p class="shell-card-title">Token Inspector</p>
              <ul class="shell-token-list" data-token-list></ul>
            </section>
            <section class="shell-card">
              <p class="shell-card-title">Source Paths</p>
              <dl class="shell-path-list" data-source-paths></dl>
            </section>
          </aside>
        </section>
      </main>
      <script src="shell/review.js" defer></script>
    </body>
    </html>
    """

    static let css = """
    :root {
      color-scheme: light;
      --shell-bg: #f6f3ee;
      --shell-panel: #ffffff;
      --shell-border: rgba(27, 31, 35, 0.12);
      --shell-ink: #1f2328;
      --shell-muted: #59636e;
      --shell-accent: #0f6cbd;
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      min-height: 100vh;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: var(--shell-bg);
      color: var(--shell-ink);
    }

    .shell-app {
      width: min(1280px, calc(100vw - 32px));
      margin: 0 auto;
      padding: 24px 0 32px;
    }

    .shell-hero {
      display: flex;
      flex-direction: column;
      gap: 12px;
      margin-bottom: 20px;
    }

    .shell-kicker,
    .shell-card-title {
      margin: 0;
      font-size: 12px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--shell-muted);
    }

    .shell-title {
      margin: 0;
      font-size: clamp(1.75rem, 3vw, 2.8rem);
      line-height: 1;
    }

    .shell-meta,
    .shell-chip-list {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }

    .shell-grid {
      display: grid;
      grid-template-columns: minmax(0, 1.6fr) minmax(280px, 0.9fr);
      gap: 16px;
      align-items: start;
    }

    .shell-stage,
    .shell-card {
      border: 1px solid var(--shell-border);
      border-radius: 20px;
      background: var(--shell-panel);
    }

    .shell-stage {
      padding: 16px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    .shell-sidebar {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    .shell-card {
      padding: 16px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    .shell-toolbar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 12px;
      flex-wrap: wrap;
    }

    .shell-toggle,
    .shell-chip {
      border: 1px solid rgba(15, 108, 189, 0.18);
      border-radius: 999px;
      min-height: 34px;
      padding: 0 12px;
      background: #ffffff;
      color: var(--shell-ink);
      font: inherit;
      cursor: pointer;
    }

    .shell-toggle.is-active,
    .shell-chip.is-active {
      background: var(--shell-accent);
      color: #ffffff;
      border-color: transparent;
    }

    .shell-copy,
    .shell-toolbar-copy {
      margin: 0;
      font-size: 14px;
      color: var(--shell-muted);
    }

    .shell-frame {
      width: 100%;
      min-height: 840px;
      border: 0;
      border-radius: 14px;
      background: #ffffff;
    }

    .shell-list,
    .shell-token-list {
      margin: 0;
      padding-left: 18px;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }

    .shell-token-list {
      max-height: 220px;
      overflow: auto;
      font-family: "SFMono-Regular", "Menlo", monospace;
      font-size: 12px;
    }

    .shell-path-list {
      margin: 0;
      display: grid;
      grid-template-columns: max-content 1fr;
      gap: 6px 10px;
      font-size: 13px;
    }

    .shell-path-list dt {
      color: var(--shell-muted);
    }

    .shell-path-list dd {
      margin: 0;
      word-break: break-all;
    }

    body[data-reduced-motion="true"] .shell-frame {
      filter: saturate(0.94);
    }

    @media (max-width: 1024px) {
      .shell-grid {
        grid-template-columns: 1fr;
      }

      .shell-frame {
        min-height: 720px;
      }
    }
    """

    static let script = """
    (function () {
      const root = document.body;
      const frame = document.querySelector("[data-screen-frame]");
      const title = document.querySelector("[data-title]");
      const metaChips = document.querySelector("[data-meta-chips]");
      const intent = document.querySelector("[data-intent]");
      const stateContainer = document.querySelector("[data-preview-states]");
      const checklist = document.querySelector("[data-review-checklist]");
      const motion = document.querySelector("[data-motion-patterns]");
      const tokenList = document.querySelector("[data-token-list]");
      const sourcePaths = document.querySelector("[data-source-paths]");
      const toggle = document.querySelector("[data-reduced-motion-toggle]");
      const screenHTML = root.dataset.screenHtml || "";
      const tokensCSS = root.dataset.tokensCss || "";
      const review = parseReviewPayload(root.dataset.reviewPayload || "");

      function parseReviewPayload(payload) {
        if (!payload) return {};

        try {
          return JSON.parse(atob(payload));
        } catch {
          return {};
        }
      }

      function resetChildren(node) {
        if (!node) return;
        node.replaceChildren();
      }

      function appendTextElement(parent, tagName, text, className) {
        if (!parent) return null;
        const element = document.createElement(tagName);
        if (className) {
          element.className = className;
        }
        element.textContent = text;
        parent.appendChild(element);
        return element;
      }

      if (frame) {
        frame.src = screenHTML;
      }

      if (title) {
        title.textContent = review.title ? `${review.title}` : `${root.dataset.screenId || "review"} shell`;
      }

      if (intent) {
        intent.textContent = review.intent || "No explicit intent.";
      }

      if (metaChips && review) {
        resetChildren(metaChips);
        const chips = [
          ["app", review.appId],
          ["flow", review.flowId],
          ["screen", review.screenId],
          ["route", review.route],
        ].filter(([, value]) => value);

        chips.forEach(([label, value]) => {
          appendTextElement(metaChips, "span", `${label} ${value}`, "shell-chip");
        });
      }

      if (stateContainer) {
        resetChildren(stateContainer);
        const states = Array.isArray(review.previewStates) ? review.previewStates : [];
        states.forEach((state, index) => {
          const button = document.createElement("button");
          button.className = index === 0 ? "shell-chip is-active" : "shell-chip";
          button.type = "button";
          button.dataset.previewStateJump = state;
          button.textContent = state;
          button.addEventListener("click", () => {
            stateContainer.querySelectorAll(".shell-chip").forEach((chip) => chip.classList.remove("is-active"));
            button.classList.add("is-active");
            if (frame) {
              frame.src = `${screenHTML}#state-${state}`;
            }
          });
          stateContainer.appendChild(button);
        });
      }

      const fillList = (node, values, fallback) => {
        if (!node) return;
        resetChildren(node);
        const entries = Array.isArray(values) && values.length ? values : [fallback];
        entries.forEach((value) => {
          appendTextElement(node, "li", value);
        });
      };

      fillList(checklist, review.reviewChecklist, "No checklist items.");
      fillList(motion, review.motionPatterns, "No motion patterns.");

      if (sourcePaths && review.sourcePaths) {
        resetChildren(sourcePaths);
        Object.entries(review.sourcePaths).forEach(([key, value]) => {
          appendTextElement(sourcePaths, "dt", key);
          appendTextElement(sourcePaths, "dd", value);
        });
      }

      if (tokenList && tokensCSS) {
        fetch(tokensCSS)
          .then((response) => response.text())
          .then((text) => {
            const matches = [...text.matchAll(/--([^:]+):\\s*([^;]+);/g)];
            resetChildren(tokenList);
            if (!matches.length) {
              appendTextElement(tokenList, "li", "No tokens found.");
              return;
            }
            matches.forEach((match) => {
              appendTextElement(tokenList, "li", `${match[1]}: ${match[2].trim()}`);
            });
          })
          .catch(() => {
            resetChildren(tokenList);
            appendTextElement(tokenList, "li", "Token CSS unavailable.");
          });
      }

      if (toggle) {
        toggle.addEventListener("click", () => {
          const next = root.dataset.reducedMotion !== "true";
          root.dataset.reducedMotion = next ? "true" : "false";
          toggle.classList.toggle("is-active", next);
          toggle.textContent = `Reduced motion: ${next ? "on" : "off"}`;
        });
      }
    })();
    """
}
