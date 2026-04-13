#!/usr/bin/env node
// Sync version from package.json to all scripts before publish
const fs = require('fs');
const path = require('path');

const pkg = require('./package.json');
const v = `v${pkg.version}`;

const files = [
  ['statusline.sh', /v\d+\.\d+\.\d+/g],
  ['statusline.ps1', /v\d+\.\d+\.\d+/g],
  ['config-ui.js', /v\d+\.\d+\.\d+/g],
];

for (const [file, pattern] of files) {
  const p = path.join(__dirname, file);
  if (!fs.existsSync(p)) continue;
  const content = fs.readFileSync(p, 'utf8');
  const updated = content.replace(pattern, v);
  if (content !== updated) {
    fs.writeFileSync(p, updated);
    console.log(`Updated ${file} to ${v}`);
  }
}
