# OHOL play statistics

Charts of your own [One Hour One Life](https://onehouronelife.com) history, built from the lives list on [OHOLCurse](https://oholcurse.com).

The script reads every life of one player straight from the website. No login and no manual copying are needed. It then saves the data as CSV and Excel, and draws one summary image with nine charts:

* lives per hour of the day
* lives per day of the week
* lives per month
* age at death
* top 10 causes of death
* character sex
* top 10 first names (without EVE)
* top 10 family names
* hours played per day

The same tool is here in three forms: a web page, a Python script and an R script.

## Web page

Open the page at **https://xiyuez1.github.io/OneHourOneLife-Statistics/**. Nothing is installed and nothing is uploaded. Everything runs in your browser.

There are two ways to load lives:

* **From OHOLCurse, with a bookmark.** Drag the **OHOL Stats** button on the page to your bookmarks bar. Open any player on oholcurse.com, then click the bookmark. A new tab opens with that player's charts. The bookmark has to run on oholcurse.com itself, because browsers do not let other websites read OHOLCurse directly.
* **From a file.** Drop in a CSV or Excel file from the Python or R script, or any sheet with Age and Died columns.

The page can save the charts as one PNG image and the lives as CSV. It is in English and Chinese. Use the switch at the top right.

To host your own copy, turn on GitHub Pages for the `docs` folder of this repository (Settings, Pages, Deploy from a branch, `main` and `/docs`). If your copy lives at a different address, the bookmark on that copy points to it automatically.

## Choose a player

Give the script any of these:

* a leaderboard name, for example `"Firstname Lastname"`
* a curse name
* a character name, for example `"EVE SMITH"`
* the player page address, `https://oholcurse.com/player/lives/<hash>`
* the 40 character player hash

Names are searched the same way as the search box on [oholcurse.com](https://oholcurse.com): leaderboard name first, then curse name, then character name. Put names with a space in quotes. If a name matches several players, the script lists them with their hashes and stops, so you can pick one.

## Python

Install once:

```bash
pip install requests beautifulsoup4 pandas matplotlib pillow scipy openpyxl
```

Run:

```bash
cd python
python3 ohol_stats.py "Firstname Lastname"
```

Options:

```bash
python3 ohol_stats.py "<name>" MyName                # use MyName in the file names
python3 ohol_stats.py "<name>" --tz America/Toronto   # time zone for the charts
python3 ohol_stats.py "<name>" --out results          # output folder
```

## R

Install once:

```r
install.packages(c("httr2", "rvest", "xml2", "jsonlite", "lubridate",
                   "dplyr", "tidyr", "ggplot2", "gridExtra", "cowplot", "openxlsx"),
                 repos = "https://cloud.r-project.org")
```

Run from a terminal:

```bash
cd R
Rscript ohol_stats.R "Firstname Lastname" [MyName]
```

Or in RStudio: open `R/ohol_stats.R`, put a name or link into `PLAYER` at the top, set the working directory to the R folder (Session, Set Working Directory, To Source File Location), then click **Source**.

## Output

Files go into an `output` folder:

* `OHOL_lives_<name>.csv` and `OHOL_lives_<name>.xlsx`: one row per life
* `OHOL_stats_<name>_<date>.jpg`: the chart image

## Notes

* Times are converted from UTC to your computer's time zone, unless you set one.
* A life's birth time is its death time minus its age in minutes, since one year in the game is one minute.
* Deaths by another player show as `killer`. All boar deaths are grouped as `Boar`.
* The script sends a few requests per run. Please be kind to the website and do not run it in a tight loop.
* If OHOLCurse changes its page layout, the script may stop working. Please open an issue.

## 中文说明

这个工具直接从 OHOLCurse 读取某个玩家的全部生命记录，不需要登录，然后导出 CSV 和 Excel，并画一张包含九个统计图的总图。也可以用网页版 https://xiyuez1.github.io/OneHourOneLife-Statistics/ ：在 oholcurse 的玩家页面上点书签，或者把 CSV、Excel 文件拖进网页，直接出图。网页右上角可以切换中文和英文。运行时直接写排行榜名、curse 名或角色名就行，比如 "Firstname Lastname"，也可以用玩家页面的网址或 hash。用法见上面的 Python 和 R 两部分。

## Licence

MIT
