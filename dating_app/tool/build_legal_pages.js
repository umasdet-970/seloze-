// Generates public/privacy.html, public/terms.html and public/guidelines.html
// from lib/core/constants/legal_content.dart, so the website and the in-app
// text are always identical.
//
//   node tool/build_legal_pages.js
//
// Then deploy:  firebase deploy --only hosting --project connect-dating-app-e2ad4
//
// (public/delete-account.html is written by hand and is not generated.)

const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const source = fs.readFileSync(path.join(root, "lib/core/constants/legal_content.dart"), "utf8");

function extract(name) {
  const m = source.match(new RegExp(`const String ${name} = '''\\n([\\s\\S]*?)\\n''';`));
  if (!m) throw new Error(`Could not find ${name} in legal_content.dart`);
  return m[1];
}

const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function inline(text) {
  let out = esc(text);
  // Email addresses -> mailto links.
  out = out.replace(/([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})/g, '<a href="mailto:$1">$1</a>');
  // Cross-links to the hand-written deletion page and sibling documents.
  out = out
    .replace(/see our deletion page/g, 'see our <a href="delete-account.html">deletion page</a>')
    .replace(/through the deletion page on our website/g, 'through the <a href="delete-account.html">deletion page</a> on our website');
  return out;
}

function toHtml(body) {
  const lines = body.split("\n");
  const html = [];
  let inList = false;
  const closeList = () => {
    if (inList) {
      html.push("    </ul>");
      inList = false;
    }
  };
  for (const raw of lines) {
    const line = raw.trimEnd();
    if (line === "") {
      closeList();
    } else if (line.startsWith("Last updated:")) {
      html.push(`    <p class="updated">${inline(line)}</p>`);
    } else if (line.startsWith("## ")) {
      closeList();
      html.push(`    <h2>${inline(line.slice(3))}</h2>`);
    } else if (line.startsWith("- ")) {
      if (!inList) {
        html.push("    <ul>");
        inList = true;
      }
      html.push(`      <li>${inline(line.slice(2))}</li>`);
    } else {
      closeList();
      html.push(`    <p>${inline(line)}</p>`);
    }
  }
  closeList();
  return html.join("\n");
}

function page(title, heading, body) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — Seloze</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<div class="page">
  <div class="brand">
    <div class="brand-mark">S</div>
    <div class="brand-name">Seloze</div>
  </div>
  <div class="nav">
    <a href="privacy.html">Privacy Policy</a>
    <a href="terms.html">Terms &amp; Conditions</a>
    <a href="guidelines.html">Community Guidelines</a>
    <a href="delete-account.html">Delete account</a>
  </div>
  <div class="card">
    <h1>${heading}</h1>
${toHtml(body)}
  </div>
  <footer>© 2026 Seloze</footer>
</div>
</body>
</html>
`;
}

const outputs = [
  ["privacy.html", "Privacy Policy", "Privacy Policy", "kPrivacyPolicyText"],
  ["terms.html", "Terms & Conditions", "Terms &amp; Conditions", "kTermsText"],
  ["guidelines.html", "Community Guidelines", "Community Guidelines", "kGuidelinesText"],
];

for (const [file, title, heading, constant] of outputs) {
  const html = page(esc(title), heading, extract(constant));
  fs.writeFileSync(path.join(root, "public", file), html);
  console.log(`wrote public/${file} (${html.length} bytes)`);
}
