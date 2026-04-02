---
scope: "{{CI_DIR}}/**"
priority: 7
source: scaffold
---

CI config at {{CI_DIR}}/.
Changes to workflow files affect build/deploy.
Check which paths trigger which workflows before modifying.
