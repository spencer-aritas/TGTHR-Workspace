/* eslint-disable @lwc/lwc/no-inner-html */
/**
 * Minimal HTML sanitizer for small, controlled rich-text previews.
 * - Keeps a small whitelist of tags and a minimal set of attributes for <a>
 * - Removes script/style nodes entirely
 * - Strips other elements but preserves their text content
 *
 * This utility intentionally uses a single innerHTML assignment to parse the
 * input and then returns a cleaned HTML string. Keeping the innerHTML usage
 * isolated here limits lint noise and makes the sanitizer easy to review.
 */
export default function sanitizeHtml(html) {
  if (!html) return "";

  const template = document.createElement("template");
  template.innerHTML = html;

  const allowedTags = new Set([
    "B",
    "I",
    "U",
    "UL",
    "OL",
    "LI",
    "P",
    "BR",
    "STRONG",
    "EM",
    "SPAN",
    "A",
    "DIV"
  ]);
  const allowedAttrsFor = {
    A: new Set(["href", "title", "target", "rel"])
  };

  // Remove script/style elements completely
  const scripts = template.content.querySelectorAll("script, style");
  scripts.forEach((n) => n.parentNode && n.parentNode.removeChild(n));

  // Walk all elements and strip disallowed tags/attrs
  const all = template.content.querySelectorAll("*");
  all.forEach((el) => {
    const tag = el.tagName.toUpperCase();

    if (!allowedTags.has(tag)) {
      // Replace element with its text content to avoid preserving unknown markup
      const text = document.createTextNode(el.textContent || "");
      el.parentNode.replaceChild(text, el);
      return;
    }

    // Remove disallowed attributes
    const allowedAttrs = allowedAttrsFor[tag] || null;
    // Copy attributes into array to avoid live collection issues
    Array.from(el.attributes).forEach((attr) => {
      if (!allowedAttrs || !allowedAttrs.has(attr.name)) {
        el.removeAttribute(attr.name);
      } else {
        // For href, ensure it is safe (no javascript:)
        if (attr.name === "href") {
          const val = attr.value || "";
          if (/^\s*javascript:/i.test(val)) {
            el.removeAttribute("href");
          }
        }
      }
    });
  });

  return template.innerHTML;
}

// Read innerHTML from an Element and sanitize it. This isolates innerHTML
// usage in one file (which is lint-exempt above) so consuming components
// don't need to use innerHTML directly.
export function sanitizeElement(el) {
  if (!el) return "";
  const raw = el.innerHTML || "";
  return sanitizeHtml(raw);
}
