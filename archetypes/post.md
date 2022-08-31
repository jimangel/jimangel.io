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

slug: ""  # make your URL pretty!
---

- Include 'how' or 'why' in the permalink / title (for SEO)
- Strip out prepositions (to, of, with, at, from, into, for, on by) for permalink
  - short = better
- Write question based headers with answer based content that follows a story from a -> z.
- Keyword research for words / phrases ideal readers would search for / google trends
- H tag optimization

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