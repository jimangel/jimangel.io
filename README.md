# new post

```
export URL="actual-title-of-article"
hugo new --kind post posts/00-DRAFT-$URL.md
hugo new --kind post posts/$(date '+%Y-%m-%d')-$URL.md
```

# local preview

```
hugo serve --cleanDestinationDir --gc --ignoreCache --buildDrafts --logLevel debug
```

# Update theme

I was mixing up hugo modules and git submodules and ran into problems, let's just use git submodules...

```
# DON'T: git submodule update --remote --merge
# ensure to check https://github.com/martignoni/hugo-notice (installed as a hugo module)
# https://github.com/martignoni/hugo-notice#hugo-module

# to "force reset" them
git submodule deinit -f .
git submodule update --init --remote --merge

# should work:
git submodule update --remote --merge
```

## most recent update Jan/7/2024

caused me to delete:

```
layouts/partials/index_profile.html

cp themes/PaperMod/layouts/partials/index_profile.html layouts/partials/index_profile.html
```

Also had to redo highlighting:

```
# diff head
diff layouts/partials/head.html themes/PaperMod/layouts/partials/head.html

# copy and update
cp themes/PaperMod/layouts/partials/head.html layouts/partials/head.html

# example edit
<title>{{ if .IsHome }}Jim Angel | {{ else }}{{ if .Title }}{{ .Title }} | {{ end }}{{ end }}{{ ( replace site.Title "Jim Angel | " "") }}</title>
```

Had to fix chroma (https://github.com/adityatelange/hugo-PaperMod/pull/1364):

```
# clean up old way:
git rm layouts/partials/css/syntax-dark.css layouts/partials/css/syntax-light.css

# manually removed a chunk from custom.css (for dark mode code).. might add back.
# borland  monokai
hugo gen chromastyles --style=monokai > assets/css/includes/chroma-styles.css

# https://xyproto.github.io/splash/docs/all.html
# adding lightmode / dark mode markdown (more info in layouts/partials/extend_head.html)
# shout out https://bwiggs.com/posts/2021-08-03-hugo-syntax-highlight-dark-light/
mkdir -p layouts/partials/css/
# light others: monokailight / manni / colorful / github / lovelace / tango / xcode / vs / friendly
hugo gen chromastyles --style=monokailight > layouts/partials/css/syntax-light.css 
# dark others: monokai / dracula / native / paraiso-dark / solarized-dark / solarized-dark256 / fruity
hugo gen chromastyles --style=dracula | sed -n 's/.*\//body.dark/p' > layouts/partials/css/syntax-dark.css

# DON'T FORGET TO UPDATE custom.css with the bghljs color (to match theme of choice)
# light (/* Background */ .bg { color: #272822; background-color: #fafafa; }
cat layouts/partials/css/syntax-light.css | grep bg
# dark (body.dark .bg { color: #f8f8f2; background-color: #272822; }
cat layouts/partials/css/syntax-dark.css | grep bg

# lastly, check that the colors are set (if they exist, or unset if they dont with important! in the custom CSS). This is the final override for the custom theme. I don't think it will cause many issues.
```

# Original setup

```
# install (use --branch v5.0 to end of above command if you want to stick to specific release.)
git submodule add --depth=1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod

# install notice
git submodule add https://github.com/martignoni/hugo-notice.git themes/hugo-notice
```

# NOTE: added buy me a coffee JS

```
both in the content security stuff and in the footer (footer-blurb.md partial - called in single.html)
```

# NOTE: updated footer to cut the title (alternately could have genreated the copywrite dynamically...)

```
# Created:
<span>&copy; {{ now.Year }} <a href="{{ "" | absLangURL }}">{{ ( replace site.Title "Jim Angel | " "") }}</a></span>

# auto generates year and looks cleaner..

# Had to do this in the singles partial as well as the header partial

# INn partials/head
{{- /* Title */}}
<title>{{ if .IsHome }}{{ else }}{{ if .Title }}{{ .Title }} | {{ end }}{{ end }}{{ site.Title }}</title>

# BECOMES
# the IsHome "Jim Angel" gives me the title bar of "Jim Angel | jimangel.io" but leaves pages with their title + site. I should look at fixing this with a custom logo class vs. the title patches...
<title>{{ if .IsHome }}Jim Angel | {{ else }}{{ if .Title }}{{ .Title }} | {{ end }}{{ end }}{{ ( replace site.Title "Jim Angel | " "") }}</title>

```

# NOTE: created ads... (and reverted later after making 29 cents)

```
#adsense-inarticle.html
#https://www.godo.dev/tutorials/hugo-in-article-ad/

partial adsense in article, uses html comment, function to convert....

# RESULTS IN NEW LAYOUT SINGLE.HTML... (where I add the shortcode function to convert...)
x2!!
```

EX:

```
  {{- if .Content }}
  <div class="post-content">
    {{- if not (.Param "disableAnchoredHeadings") }}
    {{- partial "anchored_headings.html" ( replace .Content "<!--adsense-->" (partial "adsense-inarticle.html" . ) | safeHTML ) -}}
    {{- else }}{{ replace .Content "<!--adsense-->" (partial "adsense-inarticle.html" . ) | safeHTML }}{{ end }}
  </div>
  {{- end }}
```

# Note: I updated terms.html (layouts/default) to noindex my tags pages


```
# Edited the base of: https://www.datascienceblog.net/post/other/hugo_noindex_taxonomies/
# via copying the layouts baseof.html to my overlay...


# <head>
#    {{- partial "head.html" . }}
#   {{ if .Data.Singular }}
#    <meta name="robots" content="noindex, nofollow">
#    {{ end }}
# </head>

# I believe, or read, that the most restrictive wins (so head.html says index, and this says don't for tags / taxonomies)

# https://developers.google.com/search/docs/advanced/crawling/block-indexing
```

> Also had to override the site map?

```
# https://gohugo.io/templates/sitemap-template/
# https://github.com/gohugoio/hugo/blob/master/tpl/tplimpl/embedded/templates/_default/sitemap.xml

# I created:
# layouts/_default/sitemap.xml

# And added the reverse short code
# {{- if not .Data.Singular -}}
# {{- end - }}
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

# update modified images from lazy loading
```
# https://github.com/adityatelange/hugo-PaperMod/commit/c353447d8e6dbbec9e21c8ef57b1da1e177f2a16
mkdir -p layouts/_default/_markup/
cp themes/PaperMod/layouts/_default/_markup/render-image.html layouts/_default/_markup/render-image.html
mkdir -p layouts/shortcodes/
cp themes/PaperMod/layouts/shortcodes/figure.html layouts/shortcodes/figure.html
cp themes/PaperMod/layouts/partials/cover.html layouts/partials/cover.html

sed 's/loading="lazy"//g'

# reverted on 12/23/22
rm -rf layouts/partials/cover.html
rm -rf layouts/shortcodes/figure.html
rm -rf layouts/_default/_markup/render-image.html

```

# update code syntax CSS:

```
# https://xyproto.github.io/splash/docs/all.html
# adding lightmode / dark mode markdown (more info in layouts/partials/extend_head.html)
# shout out https://bwiggs.com/posts/2021-08-03-hugo-syntax-highlight-dark-light/
mkdir -p layouts/partials/css/
# light others: monokailight / manni / colorful / github / lovelace / tango / xcode / vs / friendly
hugo gen chromastyles --style=monokailight > layouts/partials/css/syntax-light.css 
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
# reverted on 12/23/22 with the same but reverse...
# ex: 
# find content/posts -type f -name '*.md' -exec sed -i '' 's/.png#center/.png/g' {} +
# find content/posts -type f -name '*.md' -exec sed -i '' 's/.gif#center/.gif/g' {} +
# find content/posts -type f -name '*.md' -exec sed -i '' 's/.jpg#center/.jpg/g' {} +

# find content/posts -type f -name '*.md' -exec sed -i '' 's/.png/.png#center/g' {} +

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

# Also added icons for apple via photoshop (icon saved on toaster)

```
# messing with svg icon
Delete the contents of the following folder:

~/Library/Safari/Template Icons
And then restart Safari.

rm -r ~/Library/SafariTechnologyPreview/Template\ Icons/

```

## added a custom schema json in layouts/partials/templates/schema_json.html to help with SEO
```
layouts/partials/templates/schema_json.html

# most of this is in the config under Params.schema
```

## I realized netlify was caching jpgs but not pngs to cloudfront? Attempted to convert one post to all jpgs

```
brew install imagemagick

cd /static/img/

# Convert PNG to JPEG
magick ubuntu-usb-install-22-04-cover.png ubuntu-usb-install-22-04-cover.jpg

```

Automated:

```
# generate pngs
for i in $(grep -rnw content/posts -e "png" | awk -F".png" '{print $1}' | sed -n 's~^.*/img/~~p' | uniq); do magick "static/img/${i}.png" "static/img/${i}.jpg"; done

# replace pngs in posts
find content/posts -type f -name '*.md' -exec sed -i '' 's/.png/.jpg/g' {} +

# rm post pngs (had to change grep to key off of jpg)
for i in $(grep -rnw content/posts -e "jpg" | awk -F".jpg" '{print $1}' | sed -n 's~^.*/img/~~p' | uniq); do rm -f "static/img/${i}.png"; done

# validate no other files use png:
grep -rnw content/posts -e "png"

# see if there's any png's left over:
ls -a static/img | grep "png"

# not used:
# clean up: static/img/featured.png
```

## modified

archives.html in layouts/_default/archives.html so the posts are grouped by year, not month..:

```
# line 23 (not to be confused with the earlier line)
  {{- range .Pages.GroupByDate "2022" }}
```

## cdn

Found out that relative images are moved to cloudfront and absURL (https://gohugobrasil.netlify.app/functions/absurl/) are local. On my browser, cloudfront out performs netlify's CDN so all assets should be relative...

```
# maybe skip on cover?
# cp themes/PaperMod/layouts/partials/cover.html layouts/partials/cover.html

cp themes/PaperMod/layouts/partials/index_profile.html layouts/partials/index_profile.html

# all uses of absURL can be replaced (~4 in cover and 1 in index)
# sed s/absURL/relURL/g
```

## Fixed some responsive images

Fixed the cover image generation by moving to page bundle resources. The code as it existed didn't appear to work with Global resources and I just want the thing to work. Look for the PR of restructuring the repo to page bundles. Not much but the cover image moved to the bundle.

```
for i in $(ls -1 content/posts | grep -v "_index.md" | sed -e 's/\.md$//'); do mkdir content/posts/$i; done

for i in $(ls -1 content/posts | grep -v "_index.md" | sed -e 's/\.md$//'); do mv "content/posts/${i}.md" "content/posts/$i/index.md"; done
```