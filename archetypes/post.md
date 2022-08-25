---
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
description: "Description placeholder"
summary: "Summary placeholder"
tags:
# - kubernetes
# - cncf
draft: true
#comments: false
cover:
    image: /img/featured.png # image path/url
    alt: "" # alt text
# check config.toml for some of the default options / toggles
---

{{< notice note >}}
This is a note.
{{< /notice >}}

{{< notice warning >}}
This is a warning notice. Be warned!
{{< /notice >}}

{{< notice tip >}}
This is a very good tip.
{{< /notice >}}

{{< notice info >}}
General info
{{< /notice >}}

### Task lists

```markdown
- [x] Task 1
- [ ] Task 2
- [ ] Task 3
```

Result:

- [x] Task 1
- [ ] Task 2
- [ ] Task 3