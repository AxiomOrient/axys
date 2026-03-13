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
        const matches = [...text.matchAll(/--([^:]+):\s*([^;]+);/g)];
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
