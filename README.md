# new post

```
export URL="actual-title-of-article"
hugo new --kind post posts/00-DRAFT-$URL.md
hugo new --kind post posts/$(date '+%Y-%m-%d')-$URL.md
```

# local preview

```
hugo serve --buildDrafts --buildFuture --ignoreCache
```

# Update theme

```
git submodule update --remote --merge

# ensure to check https://github.com/martignoni/hugo-notice
```

# Original setup

```
# install (use --branch v5.0 to end of above command if you want to stick to specific release.)
git submodule add --depth=1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod

# install notice
git submodule add https://github.com/martignoni/hugo-notice.git themes/hugo-notice
```

# Note: I added robots.txt

see https://gohugo.io/templates/robots/

# Update modified theme content

```
# To remove the super script on Archives, I did the following (layouts/_default/archives.html):
# 1) removed: `<sup class="archive-count">&nbsp;&nbsp;{{ len .Pages }}</sup>`
# 2) removed `<h3 class="archive-month-header">{{- .Key }}<sup class="archive-count">&nbsp;&nbsp;{{ len .Pages }}</sup></h3>`

# https://al3xis.xyz/posts/setting-up-disqus-comments-in-hugo/
https://github.com/gohugoio/hugo/blob/master/tpl/tplimpl/embedded/templates/disqus.html -> layouts/partials/comments.html
```

# update modified iamges from lazy loading
```
# https://github.com/adityatelange/hugo-PaperMod/commit/c353447d8e6dbbec9e21c8ef57b1da1e177f2a16
mkdir -p layouts/_default/_markup/
cp themes/PaperMod/layouts/_default/_markup/render-image.html layouts/_default/_markup/render-image.html
mkdir -p layouts/shortcodes/
cp themes/PaperMod/layouts/shortcodes/figure.html layouts/shortcodes/figure.html
cp themes/PaperMod/layouts/partials/cover.html layouts/partials/cover.html

sed 's/loading="lazy"//g'
```

# update code syntax CSS:

```
# https://xyproto.github.io/splash/docs/all.html
# adding lightmode / dark mode markdown (more info in layouts/partials/extend_head.html)
# shout out https://bwiggs.com/posts/2021-08-03-hugo-syntax-highlight-dark-light/
mkdir -p layouts/partials/css/
# light others: monokailight / manni / colorful / github / lovelace / tango / xcode / vs / friendly
hugo gen chromastyles --style=manni > layouts/partials/css/syntax-light.css 
# dark others: monokai / dracula / native / paraiso-dark / solarized-dark / solarized-dark256 / fruity
hugo gen chromastyles --style=dracula | sed -n 's/.*\//body.dark/p' > layouts/partials/css/syntax-dark.css

# DON'T FORGET TO UPDATE custom.css with the bghljs color (to match theme of choice)
# light (/* Background */ .bg { color: #272822; background-color: #fafafa; }
cat layouts/partials/css/syntax-light.css | grep bg
# dark (body.dark .bg { color: #f8f8f2; background-color: #272822; }
cat layouts/partials/css/syntax-dark.css | grep bg

# lastly, check that the colors are set (if they exist, or unset if they dont with important! in the custom CSS). This is the final override for the custom theme. I don't think it will cause many issues.
```

# seeing if I can stop phone from forcing dark mode...

```
cp themes/hugo-notice/layouts/shortcodes/notice.html layouts/shortcodes/notice.html

# removed:
@media (prefers-color-scheme:dark){
    .notice{
        --root-color:#ddd;
        --root-background:#eff;
        --title-color:#fff;
        --title-background:#7bd;
        --warning-title:#800;
        --warning-content:#400;
        --info-title:#a50;
        --info-content:#420;
        --note-title:#069;
        --note-content:#023;
        --tip-title:#363;
        --tip-content:#121
    }
}

should leave the other opereational
```

# hard reset submodules

```
git submodule foreach git reset --hard
```

# Other

```
# sweeping replacements on posts for mac / zsh
find content/posts -type f -name '*.md' -exec sed -i '' s/this/that/g {} +

# example (removing an unused shortcode):
find content/posts -type f -name '*.md' -exec sed -i '' 's/{{% callout note %}}//g' {} +

# example center images:
find content/posts -type f -name '*.md' -exec sed -i '' 's/.png/.png#center/g' {} +

# example, moving all images to a new folder (from static/media to static/img):
find content/posts -type f -name '*.md' -exec sed -i '' 's/media\//img\//g' {} +

# created kaytex support
# https://github.com/adityatelange/hugo-PaperMod/issues/236#issuecomment-778936434
```

# update social share on root site:

```
# https://www.adobe.com/express/discover/sizes/twitter
# https://github.com/rizinorg/website/blob/6facbbdcf983536c46b79b36e6a4055a7999aa64/config.yml#L32-L33

# config.toml
params:
  images:
    - /images/rizin_preview.png
```

soellchecj: https://github.com/crate-ci/typos/releases/download/v1.11.4/typos-v1.11.4-x86_64-apple-darwin.tar.gz