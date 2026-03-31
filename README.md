# koreader-patches

## Use case:

I use a [Kobo Clara BW](https://us.kobobooks.com/products/kobo-clara-bw) eReader running KOReader (basically exclusively, I almost never use the built-in Nickel reader at all).

Because I don't use the built-in Kobo reader software at all, I have the "Kobo Reader Device Interface" and "KoboTouch Calibre plugins disabled (these plugins will mutate the epub a bit on upload and I don't want that). Instead, I use the "User Defined USB driver" Calibre plugin.

90% of ebooks I read are downloaded with the [FanFicFare](https://github.com/JimmXinu/FanFicFare) Calibre plugin, from a variety of online fanfic and fiction websites. Notably, many stories I am reading are in-progress/incomplete, and I later re-download/update the epub and replace the existing `.epub` file on my ereader. This causes various minor issues with KOReader.

I use the [KOReader calibre plugin](https://github.com/kyxap/koreader-calibre-plugin) to download KOReader metadata back to my computer, mostly reading status (completed and abandoned books). In theory, this also acts as a backup of all my sidecar data (untested).

Below is the list of customizations I have applied to tweak KOReader to my needs and preferences, plus a bit of context as to why I use each of them.

## Userpatches by other users

### [Project: Title](https://github.com/joshuacant/ProjectTitle)

A complete redesign of the KOReader file browser/coverbrowser.

###  [`2-projecttitle-page-count-override.lua`](https://github.com/igarizio/KOReader.patches/blob/main/2-projecttitle-page-count-override.lua) by @igarizio

Project:Title requires your ebooks to have a metadata field containing the page count (usually generated from a Calibre plugin).

This userpatch exclusively uses the automatic KOReader-generated `doc_pages` page count instead. Note: this page count is only available/generated when the book is opened at least once (unopened books will have no page count).

> **Why?** 
> 1. I did not want to regenerate this metadata for all my existing epubs
> 2. I download (and redownload) books with FanFicFare and didn't want additional friction in this process
> 3. This seems simpler to me anyway.

## Userpatches

### [`2-100-percent-finished.lua`](patches/2-100-percent-finished.lua)

Set/unset reading status to "complete" (finshed) automatically if `percent_finished` is 100%

* Will also _remove_ complete status from books if they are not at 100% `percent_finished`
* Abandoned/on-hold status should be ignored and not modified.
* This status _probably_ won't persist to the sidecar (but might, no promises).

Implemented as a patch to `DocSettings.readSetting()` for the key `summary`.

> **Why?** I want books marked finished automatically. Also this feeds into  `2-projecttitle-progressbar-visiblity.lua` which is conditional on reading status.

### [`2-auto-collection-from-path.lua`](patches/2-auto-collection-from-path.lua)

Automatically fake-add books to collections based on first path component (folder name)

e.g. put `/mnt/onboard/foo/bar/baz.epub` into collection "foo" if home_dir is `/mnt/onboard/`

_This is a complete hack_ and may have/cause bugs. It doesn't _actually_ add books to collections, but patches `ReadCollection:isFileInCollection()` to lie and says they're in one.

> **Why?** This is good enough for History filtering by category (folder name). I mostly don't want to manage these collections manually.

TODO: I think https://github.com/koreader/koreader/pull/13336 can replace this, but I haven't tested it.

### [`2-minimal-progressbar.lua`](patches/2-minimal-progressbar.lua)

Minimal progress bar. I think there are better userpatches online, I'll probably switch to one of them instead.

### [`2-projecttitle-progressbar-visiblity.lua`](patches/2-projecttitle-progressbar-visiblity.lua)

Patch for Project:Title to show progress bars how I want:
* Show progress bar always, even if `hide_file_info == false` (when showing file dates or sizes)
* Except, hide the progress bar if new/finished/abandoned (only show if reading)

Works well with [`2-projecttitle-page-count-override.lua`](https://github.com/igarizio/KOReader.patches/blob/main/2-projecttitle-page-count-override.lua)

> **Why?** Mostly personal preference, but:
> * This makes in-progress books very distinct from other books (only these books have progress bars)
> * I often switch to a date modified sort after uploading new books from Calibre, and want to see file info dates... and progress bars at the same time.
> * `2-reset-bookinfo-if-book-mtime-newer.lua` clears the reading status for (FanFicFare) updated books, and this makes those books more distinct visually.
> * Less visual noise for completed and on-hold books, hide the progress bar entirely for these.

### [`2-random-sort.lua`](patches/2-random-sort.lua)

Sort books in random order.

BUG: I think this gets really slow on large folders, but I haven't noticed any issues in a while.

BUG/FEATURE?: The sort is not stable. Every time you reopen the file browser, the books will re-randomize.

### [`2-reset-bookinfo-if-book-mtime-newer.lua`](patches/2-reset-bookinfo-if-book-mtime-newer.lua)

If a book file is newer than it's sidecar, the book was updated and may have new chapters. Reset a book's status to new and no percent read if detected.

Implemented as a patch to `BookList.getBookInfo()` which is in-memory only (does not modify sidecar) and is cached.

> **Why?** When I re-download books with FanFicFare, this makes all the updated books show as unread. Otherwise they may incorrectly show as finished or with previous reading progress.

### [`2-search-by-author.lua`](patches/2-search-by-author.lua)

Adds "Search by author" to the long-press file dialog.

When tapped, triggers a file search from the KOReader home directory using the book's (first) author name as the search string. (This only works because I include author name in filename, and it still has false positives.)

TODO: maybe search by Calibre metadata instead, but it has a less pretty the KOReader search results UI.

### [`2-styletweak-sample-css.lua`](patches/2-styletweak-sample-css.lua)

Replace the inserted placeholder CSS when editing book-specific style tweaks.

(Other users could customize this as desired.)

### [`2-title-in-toc.lua`](patches/2-title-in-toc.lua)

Show title and author in TOC instead of "Table of Contents" header.

TODO: There are better userpatches from other users to do this, I will switch to one of them instead.

## styletweaks

### [`blockquote-paragraph-spacing.css`](styletweaks/)blockquote-paragraph-spacing.css

I normally set KOReader to have no gap between paragraphs and use a text indent. This styletweak does the opposite for blockquotes though: don't indent and skip lines between paragraphs instead.

> *Why?* Many FanFicFare-downloaded books include author notes using blockquotes, and this reads clearer. And many author notes are a single paragraph anyway

### [`dinkus-all.css`](styletweaks/dinkus-all.css)

Many books use a centered line of symbols like `* * *` as a section break between paragraphs (technically known as a ["dinkus"](https://en.wikipedia.org/wiki/Dinkus)).

However, many books downloaded with FanFicFare do not style these symbols to be centered. (Often they are not centered at all on the original website, this is not a bug in FanFicFare.)

This styletweak includes many common patterns, but if I need an additional one, I configure it on the fly with the template from `2-styletweak-sample-css.lua`.
