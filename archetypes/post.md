---
# not too long or too short (think G-search)
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
# description is usually what's used in a google snippet
# informs and interests users with a short, relevant summary of what a particular page is about.
# They are like a pitch that convince the user that the page is exactly what they're looking for.
description: "Description placeholder"
summary: "Summary placeholder"
tags:
# - kubernetes
# - cncf
keywords:
# - kubeadm upgrade
# - kubernetes
# - cncf
# - dockershim


# !! DON'T FORGET: https://medium.com/p/import
# !! DON'T FORGET: https://medium.com/p/import
draft: true
# !! DON'T FORGET: https://medium.com/p/import
# !! DON'T FORGET: https://medium.com/p/import


#comments: false
cover:
    image: /img/featured.png # image path/url
    alt: "" # alt text
# check config.toml for some of the default options / toggles

# contain keywords relevant to the page's topic, and contain no spaces, underscores or other characters. You should avoid the use of parameters when possible, as they make URLs less inviting for users to click or share. Google's suggestions for URL structure specify using hyphens or dashes (-) rather than underscores (_). Unlike underscores, Google treats hyphens as separators between words in a URL.
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