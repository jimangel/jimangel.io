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

H1 = # = Main keywords and subject matter, what the overall post is about
H2 = ## = Sections to break up content, using similar keywords to the H1 tag
H3 = ### = Subcategories to further break up the content, making it easily scannable

- Include 'how' or 'why' in the permalink / title (for SEO)
- Strip out prepositions (to, of, with, at, from, into, for, on by) for permalink
  - short = better
- Write question based headers with answer based content that follows a story from a -> z.
- Keyword research for words / phrases ideal readers would search for / google trends
- H tag optimization
- `<!--adsense-->`

{{< notice note >}}
This is a note.
{{< /notice >}}

```
Check to make sure each page has:
A clear title tag.
H1 tags that define the page’s main topic.
Alt tags and descriptions on all of your images.
Internal links to help guide visitors and search engines to your most important pages.
Breadcrumbs across the site especially if there are multiple lessons and chapters in your courses.
```

- ending posts with 2 to 3 questions

{{< notice warning >}}
This is a warning notice. Be warned!
{{< /notice >}}

{{< notice tip >}}
This is a very good tip.
{{< /notice >}}

{{< notice info >}}
General info
{{< /notice >}}