# One Hour One Life Statistics

[![Website](https://img.shields.io/website?url=https%3A%2F%2Fxiyuez1.github.io%2FOneHourOneLife-Statistics%2F&label=website)](https://xiyuez1.github.io/OneHourOneLife-Statistics/)
[![pages-build-deployment](https://github.com/XiyueZ1/OneHourOneLife-Statistics/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/XiyueZ1/OneHourOneLife-Statistics/actions/workflows/pages/pages-build-deployment)
[![Last commit](https://img.shields.io/github/last-commit/XiyueZ1/OneHourOneLife-Statistics)](https://github.com/XiyueZ1/OneHourOneLife-Statistics/commits/main)

[English](#english) | [中文](#中文)

---

## English

Charts of one player's [One Hour One Life](https://onehouronelife.com) history, built from the lives list on [OHOLCurse](https://oholcurse.com).

The tool comes in three forms: a web page, a Python script and an R script. The web page is the easiest. Nothing needs to be installed.

### What you get

* Hours played, number of lives, share of lives that reached 60, and average age
* Lives per hour of the day
* Lives per day of the week
* Lives per month
* Age at death
* Top 10 causes of death
* Character sex
* Top 10 first names (without EVE)
* Top 10 family names
* Hours played per day

### Web page

Open **https://xiyuez1.github.io/OneHourOneLife-Statistics/**

Everything runs in your browser. Your game data is never sent anywhere.

#### Read a player straight from OHOLCurse

1. On the web page, drag the **OHOL Stats** button to your browser's bookmarks bar. Drag it, do not click it.
2. Open any player on oholcurse.com. You can search by leaderboard name, curse name or character name.
3. Click the **OHOL Stats** bookmark. A new tab opens with that player's charts.

The bookmark has to run on oholcurse.com itself, because browsers do not let other websites read OHOLCurse directly.

If the new tab is blocked, allow pop ups for oholcurse.com and click the bookmark again. The page has step by step help for Chrome, Edge, Firefox, Safari, iPhone, iPad and Android. Click **How do I add the bookmark?** under the button.

#### Or load a file

Drop a CSV or Excel file onto the page. It works with the files from the Python or R script.

#### On the page

* **Time range:** last month, last 3 months, last 6 months, last year, or all time.
* **Donkey Town:** lives in Donkey Town are left out by default. Tick **Include Donkey Town** to count them.
* **Save chart image** saves all charts as one PNG. **Save CSV** saves every life as a table.
* **English / 中文** at the top right switches the language.
* The page remembers the last player you read from OHOLCurse.

### Python

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
python3 ohol_stats.py "<name>" --include-dt           # also count Donkey Town lives
```

### R

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
Rscript ohol_stats.R "Firstname Lastname" --include-dt   # also count Donkey Town lives
```

Or in RStudio: open `R/ohol_stats.R` and put a name or link into `PLAYER` at the top. Set the working directory to the R folder (Session, Set Working Directory, To Source File Location), then click **Source**. To count Donkey Town lives, set `INCLUDE_DT <- TRUE` at the top.

### Choosing a player in Python and R

Give the script any of these:

* a leaderboard name, for example `"Firstname Lastname"`
* a curse name
* a character name, for example `"EVE SMITH"`
* the player page address, `https://oholcurse.com/player/lives/<hash>`
* the 40 character player hash

Names are searched like the search box on oholcurse.com: leaderboard name first, then curse name, then character name. Put names with a space in quotes. If a name matches several players, the script lists them with their hashes and stops, so you can pick one.

### Output of Python and R

Files go into an `output` folder:

* `OHOL_lives_<name>.csv` and `OHOL_lives_<name>.xlsx`: one row per life, with a `Donkey Town` column. These files always keep every life.
* `OHOL_stats_<name>_<date>.jpg`: the chart image

### Notes

* No login is needed. OHOLCurse shows lives to everyone.
* OHOLCurse gives times in UTC. They are converted to your own time zone.
* One year of age in the game is one minute, so a life's birth time is its death time minus its age in minutes.
* Deaths by another player show as `killer`. All boar deaths are grouped as `Boar`.
* Most players never play in Donkey Town, so its lives are left out of the charts by default in all three versions.
* Each run sends only a few requests. Please be kind to OHOLCurse and do not run it in a loop.
* If OHOLCurse changes its page layout, the tool may stop working. Please open an issue.

---

## 中文

根据 [OHOLCurse](https://oholcurse.com) 上的生命记录，画出玩家的《[One Hour One Life](https://onehouronelife.com)》（一小时人生）游戏统计图。

这个工具有三种用法：网页版、Python 脚本和 R 脚本。网页版最简单，无需安装。

### 统计内容

* 游戏总时长、生命次数、活到 60 岁的比例、平均寿命
* 一天中每个小时开始的生命次数
* 星期几开始的生命次数
* 每月生命次数
* 死亡年龄的分布
* 死因前十名
* 角色性别
* 名字前十名（不含 EVE）
* 姓氏前十名
* 每天游戏时长

### 网页版

打开 **https://xiyuez1.github.io/OneHourOneLife-Statistics/**

所有计算都在你的浏览器里完成，游戏数据不会发送到任何地方。

#### 直接从 OHOLCurse 读取

1. 在网页上，把 **OHOL Stats** 按钮拖到浏览器的书签栏。注意是按住拖拽。
2. 在 oholcurse.com 上打开任意一个玩家的页面。可以按排行榜名、curse 名或角色名搜索。
3. 点书签栏上的 **OHOL Stats**，会打开一个新标签页，显示这个玩家的统计图。

书签必须在 oholcurse.com 的页面上点，因为浏览器不允许其他的网站直接读取 OHOLCurse 的数据。

如果新标签页被拦截，请允许 oholcurse.com 弹出窗口，然后再点一次书签。网页上有 Chrome、Edge、Firefox、Safari、iPhone、iPad 和安卓手机的详细步骤，点按钮下面的**怎么添加书签？**即可看到。

#### 或者上传文件

把 CSV 或 Excel 文件拖拽到网页上。可用 Python 或 R 脚本导出的文件。

#### 网页上的功能

* **时间范围**：近 1 个月、近 3 个月、近 6 个月、近 1 年、全部。
* **Donkey Town**：默认不统计 Donkey Town 里的生命，除非勾选**包含 Donkey Town** 。
* **保存统计图**会把所有图存成一张 PNG 图片。**保存 CSV** 会把全部生命记录存成csv表格。
* 右上角的 **English / 中文** 可以切换语言。
* 网页会记住你上次从 OHOLCurse 读取的数据。

### Python 版

先安装需要的包（只需一次）：

```bash
pip install requests beautifulsoup4 pandas matplotlib pillow scipy openpyxl
```

运行：

```bash
cd python
python3 ohol_stats.py "Firstname Lastname"
```

其他选项：

```bash
python3 ohol_stats.py "<名字>" MyName                # 文件名里用 MyName
python3 ohol_stats.py "<名字>" --tz America/Toronto   # 图表用的时区
python3 ohol_stats.py "<名字>" --out results          # 输出文件夹
python3 ohol_stats.py "<名字>" --include-dt           # 包含 Donkey Town 里的生命
```

### R 版

先安装需要的包（只需一次）：

```r
install.packages(c("httr2", "rvest", "xml2", "jsonlite", "lubridate",
                   "dplyr", "tidyr", "ggplot2", "gridExtra", "cowplot", "openxlsx"),
                 repos = "https://cloud.r-project.org")
```

在终端里运行：

```bash
cd R
Rscript ohol_stats.R "Firstname Lastname" [MyName]
Rscript ohol_stats.R "Firstname Lastname" --include-dt   # 包含 Donkey Town 里的生命
```

也可以用 RStudio：打开 `R/ohol_stats.R`，在开头的 `PLAYER` 里填玩家名字或网址。把工作目录设成 R 文件夹（Session，Set Working Directory，To Source File Location），然后点 **Source**。如需包含 Donkey Town 里的生命，把开头的 `INCLUDE_DT` 改成 `TRUE`。

### Python 和 R 版怎么指定玩家

以下任何一种都可：

* 排行榜名，比如 `"Firstname Lastname"`
* curse 名
* 角色名，比如 `"EVE SMITH"`
* 玩家页面的网址，`https://oholcurse.com/player/lives/<hash>`
* 40 位的玩家 hash

搜索顺序和 oholcurse.com 的搜索框一样：先按排行榜名，再按 curse 名，最后按角色名。名字里有空格的话要加引号。如果一个名字对应好几个玩家，脚本会列出他们的名字和 hash，让你选择一个。

### Python 和 R 版的输出

文件会保存在 `output` 文件夹里：

* `OHOL_lives_<名字>.csv` 和 `OHOL_lives_<名字>.xlsx`：每一行是一次生命。这两个文件保留全部生命，`Donkey Town` 列标出哪些是 Donkey Town 里的生命。
* `OHOL_stats_<名字>_<日期>.jpg`：统计图

### 说明

* 无需登录。OHOLCurse 上的生命记录是公开的。
* OHOLCurse 给的是 UTC 时间，会自动转换成你所在的时区。
* 游戏里 1 岁等于 1 分钟，所以出生时间等于死亡时间减去年龄对应的分钟数。
* 被其他玩家杀死统一记为 `killer`。各种野猪合并成 `Boar`。
* 默认不统计驴镇的生命。
* 每次运行只发送几个请求。请不要循环运行，以免给 OHOLCurse 增加负担。
* 如果 OHOLCurse 改了网页结构，这个工具可能会失效，欢迎提 issue。

---

## Licence

MIT
